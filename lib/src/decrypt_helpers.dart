import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// ─────────────────────────────────────────────────────────────
/// Public API (UNCHANGED)
/// ─────────────────────────────────────────────────────────────
abstract class DecryptHelpers {
  /// Stream AES-CTR decryption helper (seekable).
  ///
  /// [start] and [end] are offsets into the *plaintext* payload and both are
  /// inclusive; the 16 byte IV prefix is not addressable.
  ///
  /// The returned stream is lazy, honours pause/resume, and aborts the work in
  /// the isolate when cancelled. Serving video over HTTP depends on all three:
  /// a player asks for `bytes=0-`, reads a few hundred KB, then drops the
  /// connection to seek elsewhere.
  static Stream<List<int>> openDecryptRead(
    File encryptedFile,
    String base64Key, [
    int? start,
    int? end,
  ]) {
    return _DecryptWorker.instance.decrypt(
      encryptedFile,
      base64Key,
      start ?? 0,
      end,
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// Internal persistent worker (PRIVATE)
/// ─────────────────────────────────────────────────────────────
class _DecryptWorker {
  _DecryptWorker._();
  static final instance = _DecryptWorker._();

  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _handshakePort;

  /// Shared by concurrent callers so only one isolate is ever spawned.
  Future<void>? _initFuture;

  Future<void> _init() => _initFuture ??= _spawn();

  Future<void> _spawn() async {
    try {
      final handshakePort = ReceivePort();
      _handshakePort = handshakePort;

      _isolate = await Isolate.spawn(
        _decryptIsolateMain,
        handshakePort.sendPort,
        errorsAreFatal: false,
      );

      _sendPort = await handshakePort.first as SendPort;
    } catch (error) {
      _teardown();
      rethrow;
    }
  }

  /// Drops the isolate so the next call spawns a fresh one.
  ///
  /// Without this a single failure - an unreadable file, a bad key - would
  /// leave `_isolate` non-null forever and every later read would hang waiting
  /// on a port nobody is listening to.
  void _teardown() {
    _handshakePort?.close();
    _handshakePort = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
    _initFuture = null;
  }

  Stream<List<int>> decrypt(File file, String base64Key, int start, int? end) {
    late final StreamController<List<int>> controller;

    ReceivePort? replyPort;
    SendPort? creditPort;
    var cancelled = false;

    // One chunk is granted at a time. The isolate does no work until it holds
    // a credit, so memory is bounded by a single chunk no matter how large the
    // range is - previously a `bytes=0-` on a multi-GB title decrypted the
    // whole file into this queue while the socket drained at playback speed.
    void grant() {
      if (cancelled || controller.isPaused) {
        return;
      }
      creditPort?.send(const _More());
    }

    Future<void> run() async {
      try {
        await _init();

        final port = ReceivePort();
        replyPort = port;

        _sendPort!.send(
          _DecryptCmd(file.path, base64Key, start, end, port.sendPort),
        );

        await for (final msg in port) {
          if (cancelled) {
            break;
          }

          if (msg is SendPort) {
            // The isolate's control channel; the first credit starts the flow.
            creditPort = msg;
            grant();
            continue;
          }

          if (msg is _Failure) {
            throw StateError(msg.message);
          }

          // End of range.
          if (msg == null) {
            break;
          }

          controller.add(msg as List<int>);
          grant();
        }
      } catch (error, stackTrace) {
        // The isolate may be wedged; drop it so the next read starts clean.
        _teardown();
        if (!cancelled && !controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      } finally {
        replyPort?.close();
        if (!controller.isClosed) {
          await controller.close();
        }
      }
    }

    controller = StreamController<List<int>>(
      onListen: run,
      onPause: () {
        // Nothing to do: `grant` checks `isPaused`, so the isolate simply stops
        // being asked for more.
      },
      onResume: grant,
      onCancel: () {
        // The consumer went away - a seek, or a dropped HTTP connection. Tell
        // the isolate to abandon this range so it is free for the next command
        // instead of grinding to the end of the file.
        cancelled = true;
        creditPort?.send(const _Abort());
        replyPort?.close();
      },
    );

    return controller.stream;
  }
}

/// ─────────────────────────────────────────────────────────────
/// Isolate main
/// ─────────────────────────────────────────────────────────────
Future<void> _decryptIsolateMain(SendPort mainPort) async {
  final commandPort = ReceivePort();
  mainPort.send(commandPort.sendPort);

  await for (final cmd in commandPort) {
    if (cmd is! _DecryptCmd) {
      continue;
    }

    // Every command is self-contained and independently guarded. A throw here
    // used to escape the `await for`, killing the isolate and closing
    // `commandPort` permanently - every later read then hung forever.
    RandomAccessFile? raf;
    try {
      final key = base64.decode(cmd.base64Key);
      if (key.length != 16 && key.length != 32) {
        throw ArgumentError('Invalid AES key length: ${key.length}');
      }

      raf = await File(cmd.path).open();

      final fileLength = await raf.length();
      if (fileLength < _ivLength) {
        throw StateError('File too short to contain an IV');
      }

      final iv = await raf.read(_ivLength);
      final payloadLength = fileLength - _ivLength;

      await _decryptRange(
        raf: raf,
        key: Uint8List.fromList(key),
        iv: Uint8List.fromList(iv),
        start: cmd.start,
        end: cmd.end ?? (payloadLength - 1),
        reply: cmd.reply,
      );
    } catch (error) {
      cmd.reply.send(_Failure('$error'));
    } finally {
      await raf?.close();
    }
  }
}

const int _ivLength = 16;

/// ─────────────────────────────────────────────────────────────
/// Decryption logic
/// ─────────────────────────────────────────────────────────────
Future<void> _decryptRange({
  required RandomAccessFile raf,
  required Uint8List key,
  required Uint8List iv,
  required int start,
  required int end,
  required SendPort reply,
}) async {
  // Control channel back from the consumer: one message per chunk it wants,
  // or an abort.
  final controlPort = ReceivePort();
  reply.send(controlPort.sendPort);

  // A tiny hand-rolled queue rather than package:async's StreamQueue - this
  // package depends only on pointycastle, and pulling in a dependency for one
  // await is not worth it. Signals that arrive before we ask are buffered, so
  // a credit is never lost.
  final buffered = <Object?>[];
  Completer<Object?>? waiting;
  var aborted = false;

  final subscription = controlPort.listen((message) {
    if (message is _Abort) {
      aborted = true;
    }

    final pending = waiting;
    if (pending != null && !pending.isCompleted) {
      waiting = null;
      pending.complete(message);
    } else {
      buffered.add(message);
    }
  });

  Future<Object?> nextSignal() {
    if (buffered.isNotEmpty) {
      return Future<Object?>.value(buffered.removeAt(0));
    }
    final completer = Completer<Object?>();
    waiting = completer;
    return completer.future;
  }

  try {
    if (start > end) {
      reply.send(null);
      return;
    }

    const blockSize = 16;
    final blockIndex = start ~/ blockSize;
    final blockOffset = start % blockSize;

    final counter = Uint8List.fromList(iv);
    _incrementCounter(counter, blockIndex);

    final cipher = StreamCipher('AES/CTR')
      ..init(false, ParametersWithIV(KeyParameter(key), counter));

    await raf.setPosition(_ivLength + start);

    if (blockOffset > 0) {
      // Encrypting zeros generates the keystream. The result is discarded, but
      // the cipher state advances to the requested byte.
      cipher.process(Uint8List(blockOffset));
    }

    final buffer = Uint8List(64 * 1024);
    var pos = start;

    while (pos <= end) {
      // Wait to be asked. This is the backpressure.
      if (aborted) {
        return;
      }
      final signal = await nextSignal();
      if (signal is _Abort || aborted) {
        return;
      }

      final remaining = end - pos + 1;
      final read = await raf.readInto(
        buffer,
        0,
        remaining > buffer.length ? buffer.length : remaining,
      );

      if (read == 0) {
        break;
      }

      reply.send(cipher.process(buffer.sublist(0, read)));
      pos += read;
    }

    reply.send(null);
  } finally {
    await subscription.cancel();
    controlPort.close();
  }
}

/// CTR counter increment (big-endian)
void _incrementCounter(Uint8List counter, int blocks) {
  if (blocks == 0) {
    return;
  }

  var carry = blocks;
  for (var i = counter.length - 1; i >= 0; i--) {
    final sum = counter[i] + (carry & 0xff);
    counter[i] = sum & 0xff;
    carry = (carry >> 8) + (sum >> 8);
    if (carry == 0) {
      break;
    }
  }
}

/// ─────────────────────────────────────────────────────────────
/// Messages (PRIVATE)
/// ─────────────────────────────────────────────────────────────

/// Consumer -> isolate: send one more chunk.
class _More {
  const _More();
}

/// Consumer -> isolate: abandon this range.
class _Abort {
  const _Abort();
}

/// Isolate -> consumer: the range failed.
class _Failure {
  const _Failure(this.message);
  final String message;
}

/// Consumer -> isolate: decrypt [start]..[end] of [path], inclusive.
///
/// The file and key travel with every command so the isolate holds no state
/// between ranges - two players reading different titles cannot interleave on
/// a shared handle.
class _DecryptCmd {
  _DecryptCmd(this.path, this.base64Key, this.start, this.end, this.reply);
  final String path;
  final String base64Key;
  final int start;
  final int? end;
  final SendPort reply;
}
