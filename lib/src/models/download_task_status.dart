import 'package:hive/hive.dart';

part 'download_task_status.g.dart';

@HiveType(typeId: 1)
enum DownloadTaskStatus {
  @HiveField(0)
  undefined,
  @HiveField(1)
  enqueued,
  @HiveField(2)
  running,
  @HiveField(3)
  complete,
  @HiveField(4)
  failed,
  @HiveField(5)
  canceled,
  @HiveField(6)
  paused,
}
