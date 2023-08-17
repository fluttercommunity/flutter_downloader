/// Defines a set of possible states which a [DownloadTask] can be in.
@pragma('vm:entry-point')
enum DownloadTaskStatus {
  /// Status of the task is either unknown or corrupted.
  undefined,

  /// The task is scheduled, but is not running yet.
  enqueued,

  /// The task is in progress.
  running,

  /// The task has completed successfully.
  complete,

  /// The task has failed.
  failed,

  /// The task was canceled and cannot be resumed.
  canceled,

  /// The task was paused and can be resumed
  paused;

  /// Creates a new [DownloadTaskStatus] from an [int].
  factory DownloadTaskStatus.fromInt(int value) {
    switch (value) {
      case 0:
        return DownloadTaskStatus.undefined;
      case 1:
        return DownloadTaskStatus.enqueued;
      case 2:
        return DownloadTaskStatus.running;
      case 3:
        return DownloadTaskStatus.complete;
      case 4:
        return DownloadTaskStatus.failed;
      case 5:
        return DownloadTaskStatus.canceled;
      case 6:
        return DownloadTaskStatus.paused;
      default:
        throw ArgumentError('Invalid value: $value');
    }
  }
}

/// Encapsulates all information of a single download task.
///
/// This is also the structure of the record saved in the SQLite database.
class DownloadTask {
  /// Creates a new [DownloadTask].
  DownloadTask({
    required this.taskId,
    required this.status,
    required this.progress,
    required this.url,
    required this.filename,
    required this.savedDir,
    required this.timeCreated,
    required this.allowCellular,
  });

  /// Unique identifier of this task.
  final String taskId;

  /// Status of this task.
  final DownloadTaskStatus status;

  /// Progress between 0 (inclusive) and 100 (inclusive).
  final int progress;

  /// URL from which the file is downloaded.
  final String url;

  /// Local file name of the downloaded file.
  final String? filename;

  /// Absolute path to the directory where the downloaded file will saved.
  final String savedDir;

  /// Timestamp when the task was created.
  final int timeCreated;

  /// Whether downloads can use cellular data
  final bool allowCellular;

  @override
  String toString() =>
      'DownloadTask(taskId: $taskId, status: $status, progress: $progress, url: $url, filename: $filename, savedDir: $savedDir, timeCreated: $timeCreated, allowCellular: $allowCellular)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is DownloadTask &&
        other.taskId == taskId &&
        other.status == status &&
        other.progress == progress &&
        other.url == url &&
        other.filename == filename &&
        other.savedDir == savedDir &&
        other.timeCreated == timeCreated &&
        other.allowCellular == allowCellular;
  }

  @override
  int get hashCode {
    return Object.hash(
      taskId,
      status,
      progress,
      url,
      filename,
      savedDir,
      timeCreated,
      allowCellular,
    );
  }
}
