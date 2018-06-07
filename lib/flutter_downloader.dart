library flutter_downloader;

import 'package:flutter/services.dart';
import 'dart:async';

import 'package:meta/meta.dart';

typedef void DownloadCallback(String id, int state, int progress);

class DownloadTask {
  final String taskId;
  final int status;
  final int progress;

  DownloadTask({this.taskId, this.status, this.progress});
}

class FlutterDownloader {
  static const platform = const MethodChannel('vn.hunghd/downloader');

  static Future<String> enqueue({
    @required String url,
    @required String savedDir,
    String fileName,
    bool showNotification = false,
  }) async {
    try {
      String taskId = await platform.invokeMethod('enqueue', {
        'url': url,
        'saved_dir': savedDir,
        'file_name': fileName,
        'show_notification': showNotification
      });
      print('Download task is enqueued with id($taskId)');
      return taskId;
    } on PlatformException catch (e) {
      print('Download task is failed with reason(${e.message})');
      return null;
    }
  }

  static Future<List<DownloadTask>> loadTasks({@required List<String> ids}) async {
    try {
      List<dynamic> result = await platform.invokeMethod("loadTasks", {'ids': ids});
      print('Loaded tasks: $result');
      return result.map((item) =>
      new DownloadTask(
          taskId: item['task_id'],
          status: item['status'],
          progress: item['progress'])
      ).toList();
    } on PlatformException catch (e) {
      return null;
    }
  }

  static void cancel({@required String downloadId}) {

  }

  static void cancelAll() {

  }

//// TODO: implement to pause and resume a download process

//  static void pause({@required downloadId}) {
//
//  }
//
//  static void resume({@required downloadId}) {
//
//  }

  static registerCallback(DownloadCallback callback) {
    platform.setMethodCallHandler((MethodCall call) {
      if (call.method == 'updateProgress') {
        String id = call.arguments['task_id'];
        int state = call.arguments['status'];
        int process = call.arguments['progress'];
        callback(id, state, process);
      }
    });
  }
}
