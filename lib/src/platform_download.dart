import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_downloader/src/desktop_platform_download.dart';
import 'package:flutter_downloader/src/download_metadata.dart';

/// A platform specific [Download] which invokes the method channel and make the
/// download native if the platform has this requirement.
class PlatformDownload extends DesktopPlatformDownload {
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

  /// Return the local cache directory.
  static Future<Directory> getLocalDir() async {
    if (Platform.isAndroid || Platform.isIOS) {
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
      print('Reading ${download.metadataFile}');
      final data = await download.metadataFile.readAsString();
      final json = jsonDecode(data) as Map<String, dynamic>;
      final metadata = DownloadMetadata.fromJson(json);
      download
        ..headers.addAll(metadata.headers)
        ..filename = metadata.filename
        ..etag = metadata.etag
        ..finalSize = metadata.size;
      //..resumable = metadata
      if (download.finalSize != null) {
        if (download.cacheFile.existsSync()) {
          final cacheFileSize = await download.cacheFile.length();
          download.progress = (cacheFileSize * 1000) ~/ download.finalSize!;
          if (cacheFileSize == download.finalSize) {
            download.status = DownloadStatus.completed;
          }
        }
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
        await updateMetaData();
        break;
      case 'updateStatus':
        status = DownloadStatus.values
            .firstWhere((element) => element.name == call.arguments);
        break;
    }
  }

  @override
  Future<void> pause() async {
    print('paused called on PlatformDownload');
    if (Platform.isAndroid || Platform.isIOS) {
      await _methodChannel.invokeMethod<void>('pause', urlHash);
    } else {
      await super.pause();
    }
  }

  @override
  Future<void> resume() async {
    print('should resume on dart side...');
    if (Platform.isAndroid || Platform.isIOS) {
      await _methodChannel.invokeMethod<void>('resume', urlHash);
    } else {
      await super.resume();
    }
  }
}
