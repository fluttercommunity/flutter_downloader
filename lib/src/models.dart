/// Defines a set of possible states which a [DownloadTask] can be in.
@pragma('vm:entry-point')
class DownloadTaskStatus {
  /// Creates a new [DownloadTaskStatus].
  const DownloadTaskStatus(int value) : _value = value;

  final int _value;

  /// The underlying index of this status.
  int get value => _value;

  /// Status of the task is either unknown or corrupted.
  static const undefined = DownloadTaskStatus(0);

  /// The task is scheduled, but is not running yet.
  static const enqueued = DownloadTaskStatus(1);

  /// The task is in progress.
  static const running = DownloadTaskStatus(2);

  /// The task has completed successfully.
  static const complete = DownloadTaskStatus(3);

  /// The task has failed.
  static const failed = DownloadTaskStatus(4);

  /// The task was canceled and cannot be resumed.
  static const canceled = DownloadTaskStatus(5);

  /// The task was paused and can be resumed.
  static const paused = DownloadTaskStatus(6);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is DownloadTaskStatus && other._value == _value;
  }

  @override
  int get hashCode => _value.hashCode;

  @override
  String toString() => 'DownloadTaskStatus($_value)';
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

  @override
  String toString() =>
      'DownloadTask(taskId: $taskId, status: $status, progress: $progress, url: $url, filename: $filename, savedDir: $savedDir, timeCreated: $timeCreated)';
}
