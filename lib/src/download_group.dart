import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_downloader/src/download_controller.dart';

/// A group of [Download]s with a common progress, you can also control the
/// status of each [Download] at once.
class DownloadGroup extends ChangeNotifier
    implements DownloadProgress, DownloadController {
  /// Create a new [DownloadGroup].
  DownloadGroup(this.downloads);

  /// The list of downloads which are considered for the progress.
  final List<Download> downloads;

  @override
  void addListener(VoidCallback listener) {
    for (final download in downloads) {
      download.addListener(notifyListeners);
    }
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      for (final download in downloads) {
        download.removeListener(notifyListeners);
      }
    }
  }

  @override
  int get progress =>
      downloads.fold<int>(
        0,
        (previousValue, element) => previousValue + element.progress,
      ) ~/
      downloads.length;

  @override
  DownloadStatus get status {
    var hasAnyRunning = false;
    var hasAnyFailed = false;
    var allCompleted = true;
    var allPaused = false;
    var allCanceled = false;

    for (final download in downloads) {
      hasAnyRunning |= download.status == DownloadStatus.running;
      hasAnyFailed |= download.status == DownloadStatus.failed;
      allCompleted &= download.status == DownloadStatus.completed;
      allPaused &= download.status == DownloadStatus.paused;
      allCanceled &= download.status == DownloadStatus.canceled;
    }
    if (hasAnyFailed) {
      return DownloadStatus.failed;
    } else if (allCompleted) {
      return DownloadStatus.completed;
    } else if (allPaused) {
      return DownloadStatus.paused;
    } else if (allCanceled) {
      return DownloadStatus.canceled;
    } else if (hasAnyRunning) {
      return DownloadStatus.running;
    } else {
      final debug = downloads.map((e) => e.status).join(', ');
      print(
        'This case should never happen except you found a bug. Just to avoid '
        'a crash we assume the state "running", which might be wrong.\n\n'
        'Please file a bug here: https://github.com/fluttercommunity/'
        'flutter_downloader/issues/new?labels=bug&template=bug_report.md'
        '&title=ProgressGroup%20bug with this details:\n$debug',
      );
      return DownloadStatus.running;
    }
  }

  @override
  Future<void> cancel() async {
    for (final download in downloads) {
      await download.cancel();
    }
  }

  @override
  Future<bool> delete() async {
    var allDeleted = true;
    for (final download in downloads) {
      allDeleted &= await download.delete();
    }
    return allDeleted;
  }

  @override
  Future<void> pause() async {
    for (final download in downloads) {
      await download.pause();
    }
  }

  @override
  Future<void> resume() async {
    for (final download in downloads) {
      await download.resume();
    }
  }
}
