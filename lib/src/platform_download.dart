import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_downloader/src/dart_download.dart';

/// A platform specific [Download] which invokes the method channel and make the
/// download native if the platform has this requirement.
class PlatformDownload extends DartDownload {
  /// Create a platform specific [Download].
  PlatformDownload({
    required super.baseDir,
    required super.headers,
    required super.url,
    required super.target,
  }) {
    if (Platform.isAndroid || Platform.isIOS) {
      _backChannel = MethodChannel('$_channelId/$urlHash');
      _backChannel!.setMethodCallHandler(_handlePlatformEvent);
    }
  }

  static const _channelId = 'fluttercommunity/flutter_downloader';
  late final MethodChannel? _backChannel;
  static const _methodChannel = MethodChannel(_channelId);

  static Future<Directory> getLocalDir() async {
    if (Platform.isAndroid) {
      final path = await _methodChannel.invokeMethod<String>('getCacheDir');
      return Directory(path!);
    } else {
      return Directory('.');
    }
  }

  /// Create a new download and load all metadata for paused downloads.
  static Future<Download> create({
    required String url,
    Map<String, String> headers = const {},
    DownloadTarget target = DownloadTarget.internal,
  }) async {
    final baseDir = await PlatformDownload.getLocalDir();
    final download = PlatformDownload(
      baseDir: baseDir.absolute.path,
      headers: Map<String, String>.from(headers),
      url: url,
      target: target,
    );
    if (download.metadataFile.existsSync()) {
      var parseHeaders = false;
      for (final row in await download.metadataFile.readAsLines()) {
        if (row == 'headers:') {
          parseHeaders = true;
        } else {
          final delimiter = row.indexOf('=');
          final key = row.substring(0, delimiter);
          final value = row.substring(delimiter + 1);
          if (parseHeaders) {
            download.headers[key] = value;
          } else if (key == 'filename' && value.isNotEmpty) {
            download.filename = value;
          } else if (key == 'etag' && value.isNotEmpty) {
            download.etag = value;
          } else if (key == 'resumable' && value.isNotEmpty) {
            download.resumable = value == 'true';
          } else if (key == 'size' && value.isNotEmpty) {
            download.finalSize = int.parse(value);
          }
        }
      }
      if (download.finalSize != null) {
        download.progress =
            (await download.cacheFile.length() * 1000) ~/ download.finalSize!;
      }
    } else {
      await download.updateMetaData();
    }
    return download;
  }

  Future<void> _handlePlatformEvent(MethodCall call) async {
    switch (call.method) {
      case 'updateProgress':
        progress = call.arguments as int;
        break;
      case 'updateSize':
        finalSize = call.arguments as int;
        break;
      case 'updateStatus':
        status = DownloadStatus.values
            .firstWhere((element) => element.name == call.arguments);
        break;
    }
  }

  @override
  Future<void> cancel() async {
    if (Platform.isAndroid || Platform.isIOS) {
      await _methodChannel.invokeMethod<void>('cancel', urlHash);
    } else {
      await super.cancel();
    }
  }

  @override
  Future<void> pause() async {
    if (Platform.isAndroid || Platform.isIOS) {
      await _methodChannel.invokeMethod<void>('pause', urlHash);
    } else {
      await super.pause();
    }
  }

  @override
  Future<void> resume() async {
    if (Platform.isAndroid || Platform.isIOS) {
      await _methodChannel.invokeMethod<void>('resume', urlHash);
    } else {
      await super.resume();
    }
  }
}
