// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_task.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DownloadTaskHiveObjectAdapter
    extends TypeAdapter<DownloadTaskHiveObject> {
  @override
  final int typeId = 0;

  @override
  DownloadTaskHiveObject read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DownloadTaskHiveObject(
      taskId: fields[0] as String,
      status: fields[1] as DownloadTaskStatus,
      progress: fields[2] as int,
      url: fields[3] as String,
      filename: fields[4] as String?,
      headers: fields[5] as String?,
      savedDir: fields[6] as String,
      timeCreated: fields[7] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, DownloadTaskHiveObject obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.taskId)
      ..writeByte(1)
      ..write(obj.status)
      ..writeByte(2)
      ..write(obj.progress)
      ..writeByte(3)
      ..write(obj.url)
      ..writeByte(4)
      ..write(obj.filename)
      ..writeByte(5)
      ..write(obj.headers)
      ..writeByte(6)
      ..write(obj.savedDir)
      ..writeByte(7)
      ..write(obj.timeCreated);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadTaskHiveObjectAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
