import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_downloader/src/dart_download.dart';
import 'package:flutter_downloader/src/platform_download.dart';

part 'legacy_api.dart';

/// The target where the download should be visible for the user.
enum DownloadTarget {
  /// Put the download in the download folder. If the target platform does
  /// support download folders internal will be used.
  downloadsFolder,

  /// Put the download in the desktop folder. If the target platform does
  /// support download folders internal will be used.
  desktopFolder,

  /// Put the download into the internal storage of the app.
  internal,
}

/// Abstraction to observe download status updates
abstract class DownloadProgress extends ChangeNotifier {
  /// The state of the download
  DownloadStatus get status;

  /// The current progress in per mille [0...1000]
  // If you need percent simply device it by ten. Per mille is used here for
  // big downloads where you would see big jumps between progress steps.
  int get progress;
}

/// Factory interface
typedef CustomHttpClientFactory = HttpClient Function();

/// Provides access to all functions of the plugin in a single place.
/// The change notifier should just inform about changes of the
/// [DownloadProgress].
class FlutterDownloader extends ChangeNotifier
    with FlutterDownloaderLegacy
    implements DownloadProgress {
  /// Get the flutter downloader.
  factory FlutterDownloader() {
    // Singleton is in Legacy part since it is required there too
    return FlutterDownloaderLegacy._singleton;
  }

  FlutterDownloader._internal();

  /// Add a custom http factory for platforms without platform specific
  /// implementations like Android and iOS.
  static CustomHttpClientFactory? customHttpClientFactory;

  @override
  int get progress => throw UnimplementedError();

  @override
  DownloadStatus get status => throw UnimplementedError();

  // TODO check if that is required in the future
  static bool _debug = false;

  /// If true, more logs are printed.
  static bool get debug => _debug;

  /// Start a new download. The [Download] instance encapsulates the download
  /// status and controls like cancel, pause and resume.
  Future<Download> startDownload(
    String url, {
    String userAgent = 'flutter_downloader',
    String? fileName,
    Map<String, String> additionalHeaders = const {},
    DownloadTarget target = DownloadTarget.internal,
  }) async {
    final headers = Map<String, String>.from(additionalHeaders);
    headers['User-Agent'] = userAgent;
    final download = await PlatformDownload.create(
      url: url,
      headers: headers,
      target: target,
    );
    unawaited(download.resume());
    return download;
  }

  Future<Download?> _loadMetaData(String url) async {
    final baseDir = await PlatformDownload.getLocalDir();
    final urlHash = sha1.convert(utf8.encode(url)).toString();
    final file = File('${baseDir.path}/$urlHash.meta');
    if (file.existsSync()) {
      return PlatformDownload.create(
        url: url,
      );
    }
    return null;
  }

  /// Returns all known downloads.
  Future<List<Download>> getDownloads() async {
    final baseDir = await PlatformDownload.getLocalDir();
    final files = await baseDir.list().toList();
    final downloads = <Download>[];
    for (final file in files) {
      //print('checking File: ${file.path}');
      if (file.path.endsWith('.meta')) {
        print('Found meta file ${file.path}');
        final lines = await File(file.path).readAsLines();
        for (final line in lines) {
          if (line.startsWith('url=')) {
            final download = await _loadMetaData(line.substring(4));
            if (download != null) {
              downloads.add(download);
            }
          }
        }
      }
    }
    //print('Found ${downloads.length} downloads');
    return downloads;
  }

  /// Continues all paused downloads.
  Future<void> continueAllDownloads() async {
    for (final download in await getDownloads()) {
      if (download.status != DownloadStatus.completed ||
          download.status != DownloadStatus.canceled) {
        unawaited(download.resume());
      }
    }
  }
}
