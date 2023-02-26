import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
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
    required super.metadata,
    required super.id,
    required int cacheFileSize,
  }) {
    if (Platform.isAndroid || Platform.isIOS) {
      _backChannel = MethodChannel('$_channelId/$id');
      _backChannel!.setMethodCallHandler(_handlePlatformEvent);
    }
    if (metadata.contentLength != null) {
      progress = (cacheFileSize * 1000) ~/ metadata.contentLength!;
      if (progress == 1000) {
        status = DownloadStatus.completed;
      }
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
      return Directory.current;
    }
  }

  /// Create a new PlatformDownload from its saved metadata.
  static Future<PlatformDownload> fromDirectory(
    String baseDir,
    String id,
  ) async =>
      PlatformDownload(
        baseDir: baseDir,
        id: id,
        metadata: await DownloadMetadata.fromFile(File('$baseDir/$id.meta')),
        cacheFileSize: File('$baseDir/$id.cache').lengthSync(),
      );

  /// Create a new PlatformDownload from its saved metadata.
  static Future<PlatformDownload?> fromFile(File metadataFile) async {
    if (metadataFile.existsSync()) {
      final metadata = await DownloadMetadata.fromFile(metadataFile);
      final id = sha1.convert(utf8.encode(metadata.url)).toString();
      final cacheFile = File('${metadataFile.parent.path}/$id.part');
      return PlatformDownload(
        baseDir: metadataFile.parent.path,
        id: id,
        metadata: metadata,
        cacheFileSize: cacheFile.existsSync() ? cacheFile.lengthSync() : 0,
      );
    } else {
      return null;
    }
  }

  /// Create a new download and load all metadata for paused downloads.
  static Future<Download> create({
    required String url,
    Map<String, String> headers = const {},
    DownloadTarget target = DownloadTarget.internal,
  }) async {
    final baseDir = (await PlatformDownload.getLocalDir()).path;
    final id = sha1.convert(utf8.encode(url)).toString();
    final metadataFile = File('$baseDir/$id.meta');
    final cacheFile = File('$baseDir/$id.part');
    final DownloadMetadata metadata;

    if (metadataFile.existsSync()) {
      metadata = await DownloadMetadata.fromFile(metadataFile);
    } else {
      metadata = DownloadMetadata(url: url, target: target, headers: headers);
      await metadata.writeTo(metadataFile);
    }

    return PlatformDownload(
      baseDir: baseDir,
      id: id,
      metadata: metadata,
      cacheFileSize: cacheFile.existsSync() ? cacheFile.lengthSync() : 0,
    );
  }

  Future<void> _handlePlatformEvent(MethodCall call) async {
    switch (call.method) {
      case 'updateProgress':
        progress = call.arguments as int;
        break;
      case 'updateSize':
        metadata.contentLength = call.arguments as int;
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
      await _methodChannel.invokeMethod<void>('pause', id);
    } else {
      await super.pause();
    }
  }

  @override
  Future<void> resume() async {
    print('should resume on dart side...');
    if (Platform.isAndroid || Platform.isIOS) {
      await _methodChannel.invokeMethod<void>('resume', id);
    } else {
      await super.resume();
    }
  }
}
