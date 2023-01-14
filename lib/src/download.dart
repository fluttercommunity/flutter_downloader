import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart';

/// The current download status/progress
abstract class Download extends ChangeNotifier implements DownloadProgress {
  /// The url of the download
  String get url;

  /// Continue the download, does nothing when status is running.
  Future<void> resume();

  /// Pauses the download when running.
  Future<void> pause();

  /// Cancel the download when running or paused
  Future<void> cancel();

  /// Delete the download
  Future<bool> delete();
}
