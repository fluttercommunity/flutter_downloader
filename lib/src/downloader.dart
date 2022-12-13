import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_downloader/src/download_status.dart';

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

/// Provides access to all functions of the plugin in a single place.
/// The change notifier should just inform about changes of the
/// [DownloadProgress].
class FlutterDownloader extends ChangeNotifier with FlutterDownloaderLegacy implements DownloadProgress {
  /// Get the flutter downloader.
  factory FlutterDownloader() {
    return FlutterDownloaderLegacy._singleton;
  }
  FlutterDownloader._internal();
  // For simplicity moved to FlutterDownloaderLegacy
  // static final FlutterDownloader _singleton = FlutterDownloader._internal();
  static const _channel = MethodChannel('fluttercommunity/flutter_downloader');

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
    final download = await Download.create(
      url: url,
      headers: headers,
      target: target,
      methodChannel: _channel,
    );
    unawaited(download.resume());
    return download;
  }

  /// Returns all known downloads.
  Future<List<Download>> getDownloads() async {
    // todo look for .meta files
    return [];
  }

  /// Continue all paused downloads.
  Future<void> continueAllDownloads() async {
    for (final download in await getDownloads()) {
      if (download.status != DownloadStatus.complete ||
          download.status != DownloadStatus.canceled) {
        await download.resume();
      }
    }
  }
}
