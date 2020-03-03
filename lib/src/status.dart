part of 'downloader.dart';

/// Possible statuses of a [DownloadTask].
enum DownloadTaskStatus {
  undefined,
  enqueued,
  running,
  paused,
  completed,
  failed,
  canceled,
}

extension _StatusByValue on DownloadTaskStatus {
  static const _byIndex = [
    DownloadTaskStatus.undefined, // Index 0
    DownloadTaskStatus.enqueued, // Index 1
    DownloadTaskStatus.running, // Index 2
    DownloadTaskStatus.completed, // Index 3
    DownloadTaskStatus.failed, // Index 4
    DownloadTaskStatus.canceled, // Index 5
    DownloadTaskStatus.paused, // Index 6
  ];

  static create(int value) => _byIndex[value];
  int get value => _byIndex.indexOf(this);
}

extension StringableStatus on DownloadTaskStatus {
  String toShortString() {
    switch (this) {
      case DownloadTaskStatus.undefined:
        return 'undefined';
      case DownloadTaskStatus.enqueued:
        return 'enqueued';
      case DownloadTaskStatus.running:
        return 'running';
      case DownloadTaskStatus.paused:
        return 'paused';
      case DownloadTaskStatus.completed:
        return 'completed';
      case DownloadTaskStatus.failed:
        return 'failed';
      case DownloadTaskStatus.canceled:
        return 'canceled';
      default:
        throw UnimplementedError();
    }
  }
}
