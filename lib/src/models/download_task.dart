import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:hive/hive.dart';

part 'download_task.g.dart';

abstract class DownloadTask {
  DownloadTask({
    required this.taskId,
    required this.status,
    required this.progress,
    required this.url,
    this.filename,
    this.headers,
    required this.savedDir,
    this.timeCreated,
  });

  /// Unique identifier of this task.
  String taskId;

  /// Status of this task.
  DownloadTaskStatus status;

  /// Progress between 0 (inclusive) and 100 (inclusive).
  int progress;

  /// URL from which the file is downloaded.
  String url;

  /// Local file name of the downloaded file.
  String? filename;

  String? headers;

  /// Absolute path to the directory where the downloaded file will saved.
  String savedDir;

  /// Timestamp when the task was created.
  int? timeCreated;

  @override
  String toString() =>
      "DownloadTask(taskId: $taskId, status: $status, progress: $progress, url: $url, filename: $filename, savedDir: $savedDir, timeCreated: $timeCreated)";
}

/// Encapsulates all information of a single download task.
@HiveType(typeId: 0)
class DownloadTaskHiveObject extends HiveObject implements DownloadTask {
  /// Unique identifier of this task.
  @override
  @HiveField(0)
  String taskId;

  /// Status of this task.
  @override
  @HiveField(1)
  DownloadTaskStatus status;

  /// Progress between 0 (inclusive) and 100 (inclusive).
  @override
  @HiveField(2)
  int progress;

  /// URL from which the file is downloaded.
  @override
  @HiveField(3)
  String url;

  /// Local file name of the downloaded file.
  @override
  @HiveField(4)
  String? filename;

  @override
  @HiveField(5)
  String? headers;

  /// Absolute path to the directory where the downloaded file will saved.
  @override
  @HiveField(6)
  String savedDir;

  /// Timestamp when the task was created.
  @override
  @HiveField(7)
  int? timeCreated;

  DownloadTaskHiveObject({
    required this.taskId,
    required this.status,
    required this.progress,
    required this.url,
    this.filename,
    this.headers,
    required this.savedDir,
    this.timeCreated,
  });
}
