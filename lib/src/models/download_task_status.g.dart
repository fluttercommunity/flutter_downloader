// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_task_status.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DownloadTaskStatusAdapter extends TypeAdapter<DownloadTaskStatus> {
  @override
  final int typeId = 1;

  @override
  DownloadTaskStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
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
        return DownloadTaskStatus.undefined;
    }
  }

  @override
  void write(BinaryWriter writer, DownloadTaskStatus obj) {
    switch (obj) {
      case DownloadTaskStatus.undefined:
        writer.writeByte(0);
        break;
      case DownloadTaskStatus.enqueued:
        writer.writeByte(1);
        break;
      case DownloadTaskStatus.running:
        writer.writeByte(2);
        break;
      case DownloadTaskStatus.complete:
        writer.writeByte(3);
        break;
      case DownloadTaskStatus.failed:
        writer.writeByte(4);
        break;
      case DownloadTaskStatus.canceled:
        writer.writeByte(5);
        break;
      case DownloadTaskStatus.paused:
        writer.writeByte(6);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadTaskStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
