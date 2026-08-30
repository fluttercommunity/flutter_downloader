import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/export.dart';
import 'package:secure_flutter_downloader/src/decrypt_helpers.dart';

/// Builds an `IV || AES-CTR(plaintext)` file, the layout the downloader writes.
File _writeEncrypted(Directory dir, Uint8List plaintext, Uint8List key) {
  final iv = Uint8List.fromList(List<int>.generate(16, (i) => i * 7 + 1));

  final cipher = StreamCipher('AES/CTR')
    ..init(true, ParametersWithIV(KeyParameter(key), iv));

  final file = File('${dir.path}/video.enc')
    ..writeAsBytesSync(<int>[...iv, ...cipher.process(plaintext)]);

  return file;
}

void main() {
  late Directory dir;
  late Uint8List plaintext;
  late Uint8List key;
  late File encrypted;
  late String base64Key;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('decrypt_helpers_test');

    // Larger than the 64 KB chunk so the pull protocol runs many rounds.
    final random = Random(1234);
    plaintext = Uint8List.fromList(
      List<int>.generate(300 * 1024, (_) => random.nextInt(256)),
    );

    key = Uint8List.fromList(List<int>.generate(32, (i) => (i * 13) & 0xff));
    base64Key = base64.encode(key);
    encrypted = _writeEncrypted(dir, plaintext, key);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<List<int>> read({int? start, int? end}) async {
    final chunks = await DecryptHelpers.openDecryptRead(
      encrypted,
      base64Key,
      start,
      end,
    ).toList();

    return chunks.expand((chunk) => chunk).toList();
  }

  test('decrypts the whole payload', () async {
    expect(await read(), equals(plaintext));
  });

  test('a range is byte-identical to the same slice of the plaintext',
      () async {
    // Deliberately not block aligned, to exercise the keystream skip.
    expect(
      await read(start: 1000, end: 200000),
      equals(plaintext.sublist(1000, 200001)),
    );
  });

  test('an open-ended range runs to the end', () async {
    expect(await read(start: 250000), equals(plaintext.sublist(250000)));
  });

  test('every block offset decodes correctly', () async {
    for (var offset = 0; offset < 16; offset++) {
      expect(
        await read(start: offset, end: offset + 999),
        equals(plaintext.sublist(offset, offset + 1000)),
        reason: 'offset $offset',
      );
    }
  });

  test('an inverted range yields nothing', () async {
    expect(await read(start: 500, end: 100), isEmpty);
  });

  test('cancelling part way frees the worker for the next read', () async {
    // The regression: a player drops a connection to seek, and the isolate
    // used to keep grinding the abandoned range, leaving the next request
    // with headers and no body.
    //
    // Cancel on the first chunk rather than after a delay: the whole payload
    // decrypts in well under any sleep we could pick, and then there would be
    // nothing left to cancel.
    final first = <int>[];
    final gotFirstChunk = Completer<void>();
    late final StreamSubscription<List<int>> subscription;

    subscription = DecryptHelpers.openDecryptRead(encrypted, base64Key).listen((
      chunk,
    ) {
      first.addAll(chunk);
      if (!gotFirstChunk.isCompleted) {
        gotFirstChunk.complete();
        subscription.cancel();
      }
    });

    await gotFirstChunk.future.timeout(const Duration(seconds: 10));

    expect(first.length, lessThan(plaintext.length));

    // The next read must complete promptly and correctly.
    await expectLater(
      read(start: 0, end: 4095).timeout(const Duration(seconds: 10)),
      completion(equals(plaintext.sublist(0, 4096))),
    );
  });

  test('pausing stops the producer and resuming finishes the range', () async {
    final received = <int>[];
    final done = Completer<void>();

    final subscription = DecryptHelpers.openDecryptRead(
      encrypted,
      base64Key,
    ).listen(received.addAll, onDone: done.complete)
      ..pause();

    await Future<void>.delayed(const Duration(milliseconds: 100));
    final whilePaused = received.length;
    subscription.resume();

    await done.future.timeout(const Duration(seconds: 20));

    expect(whilePaused, lessThan(plaintext.length));
    expect(received, equals(plaintext));

    await subscription.cancel();
  });

  test('a bad key surfaces an error and the worker still recovers', () async {
    await expectLater(
      DecryptHelpers.openDecryptRead(
        encrypted,
        base64.encode([1, 2, 3]),
      ).toList(),
      throwsA(isA<Object>()),
    );

    // The isolate used to die here, wedging every later read forever.
    await expectLater(
      read(start: 0, end: 1023).timeout(const Duration(seconds: 10)),
      completion(equals(plaintext.sublist(0, 1024))),
    );
  });

  test('a missing file surfaces an error and the worker still recovers',
      () async {
    await expectLater(
      DecryptHelpers.openDecryptRead(
        File('${dir.path}/does-not-exist.enc'),
        base64Key,
      ).toList(),
      throwsA(isA<Object>()),
    );

    await expectLater(
      read(start: 0, end: 1023).timeout(const Duration(seconds: 10)),
      completion(equals(plaintext.sublist(0, 1024))),
    );
  });

  test('concurrent reads of different ranges both return correct bytes',
      () async {
    final results = await Future.wait<List<int>>([
      read(start: 0, end: 99999),
      read(start: 100000, end: 199999),
    ]).timeout(const Duration(seconds: 30));

    expect(results[0], equals(plaintext.sublist(0, 100000)));
    expect(results[1], equals(plaintext.sublist(100000, 200000)));
  });
}
