library flutter_downloader;

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

typedef void DownloadCallback(String id, DownloadTaskStatus status,
    int progress);

class DownloadTaskStatus {
  final int _value;

  const DownloadTaskStatus._internal(this._value);

  int get value => _value;

  get hashCode => _value;

  operator ==(status) => status._value == this._value;

  toString() => 'DownloadTaskStatus($_value)';

  static DownloadTaskStatus from(int value) =>
      DownloadTaskStatus._internal(value);

  static const undefined = const DownloadTaskStatus._internal(0);
  static const enqueued = const DownloadTaskStatus._internal(1);
  static const running = const DownloadTaskStatus._internal(2);
  static const complete = const DownloadTaskStatus._internal(3);
  static const failed = const DownloadTaskStatus._internal(4);
  static const canceled = const DownloadTaskStatus._internal(5);
  static const paused = const DownloadTaskStatus._internal(6);
}

class DownloadTask {
  final String taskId;
  final DownloadTaskStatus status;
  final int progress;
  final String url;
  final String filename;
  final String savedDir;

  DownloadTask(
      {this.taskId, this.status, this.progress, this.url, this.filename, this.savedDir});

  @override
  String toString() =>
      "DownloadTask(taskId: $taskId, status: $status, progress: $progress, url: $url, filename: $filename, savedDir: $savedDir)";
}

enum DownloadMessage {
  started,
  in_progress,
  canceled,
  failed,
  complete,
  paused
}

class FlutterDownloader {
  static const platform = const MethodChannel('vn.hunghd/downloader');

  static Future<Null> initialize({int maxConcurrentTasks = 2, Map<DownloadMessage, String> messages = const {}}) async {
    if (maxConcurrentTasks < 1) {
      throw ArgumentError('\'maxConcurrentTasks\' must be greater than or equal to 1');
    }
    Map<String, String> dict = {};
    dict['started'] = messages[DownloadMessage.started] ?? 'Download started';
    dict['in_progress'] = messages[DownloadMessage.in_progress] ?? 'Download in progress';
    dict['canceled'] = messages[DownloadMessage.canceled] ?? 'Download canceled';
    dict['failed'] = messages[DownloadMessage.failed] ?? 'Download failed';
    dict['complete'] = messages[DownloadMessage.complete] ?? 'Download complete';
    dict['paused'] = messages[DownloadMessage.paused] ?? 'Download paused';
    return await platform.invokeMethod('initialize', {'max_concurrent_tasks': maxConcurrentTasks, 'messages': dict});
  }

  static Future<String> enqueue({
    @required String url,
    @required String savedDir,
    String fileName,
    Map<String, String> headers,
    bool showNotification = true,
    bool clickToOpenDownloadedFile = true
  }) async {
    StringBuffer headerBuilder = StringBuffer();
    if (headers != null) {
      headerBuilder.write('{');
      headerBuilder.writeAll(
          headers.entries
              .map((entry) => '\"${entry.key}\": \"${entry.value}\"'),
          ',');
      headerBuilder.write('}');
    }
    try {
      String taskId = await platform.invokeMethod('enqueue', {
        'url': url,
        'saved_dir': savedDir,
        'file_name': fileName,
        'headers': headerBuilder.toString(),
        'show_notification': showNotification,
        'click_to_open_downloaded_file': clickToOpenDownloadedFile,
      });
      print('Download task is enqueued with id($taskId)');
      return taskId;
    } on PlatformException catch (e) {
      print('Download task is failed with reason(${e.message})');
      return null;
    }
  }

  static Future<List<DownloadTask>> loadTasks() async {
    try {
      List<dynamic> result = await platform.invokeMethod('loadTasks');
      print('Loaded tasks: $result');
      return result
          .map((item) =>
      new DownloadTask(
          taskId: item['task_id'],
          status: DownloadTaskStatus._internal(item['status']),
          progress: item['progress'],
          url: item['url'],
          filename: item['file_name'],
          savedDir: item['saved_dir']))
          .toList();
    } on PlatformException catch (e) {
      return null;
    }
  }

  static Future<Null> cancel({@required String taskId}) async {
    return await platform.invokeMethod('cancel', {'task_id': taskId});
  }

  static Future<Null> cancelAll() async {
    return await platform.invokeMethod('cancelAll');
  }

  static Future<Null> pause({@required taskId}) async {
    return await platform.invokeMethod('pause', {'task_id': taskId});
  }

  static Future<String> resume({@required taskId}) async {
    return await platform.invokeMethod('resume', {'task_id': taskId});
  }

  static Future<String> retry({@required taskId}) async {
    return await platform.invokeMethod('retry', {'task_id': taskId});
  }

  static registerCallback(DownloadCallback callback) {
    platform.setMethodCallHandler((MethodCall call) {
      if (call.method == 'updateProgress') {
        String id = call.arguments['task_id'];
        int status = call.arguments['status'];
        int process = call.arguments['progress'];
        callback(id, DownloadTaskStatus._internal(status), process);
      }
    });
  }
}
