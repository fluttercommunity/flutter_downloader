import 'dart:async';

import 'package:flutter_downloader/flutter_downloader.dart';

/// Controller to change the status of the [Download].
abstract class DownloadController {
  /// Continue the download, does nothing when status is running.
  Future<void> resume();

  /// Pauses the download when running.
  Future<void> pause();

  /// Cancel the download when running or paused
  Future<void> cancel();

  /// Delete the download
  Future<bool> delete();
}
