///
/// * author: hunghd
/// * email: hunghd.yb@gmail.com
///
/// A plugin provides capability of creating and managing background download
/// tasks. This plugin depends on native api to run background tasks, so these
/// tasks aren't restricted by the limitation of Dart codes (in term of running
/// background tasks out of scope of a Flutter application). Using native api
/// also take benefit of memory and battery management.
///
/// All task information is saved in a Sqlite database, it gives a Flutter
/// application benefit of either getting rid of managing task information
/// manually or querying task data with SQL statements easily.
///

library flutter_downloader;

import 'dart:async';
import 'package:meta/meta.dart';
import 'package:flutter/services.dart';

///
/// A signature function for download progress updating callback
///
/// * `id`: unique identifier of a download task
/// * `status`: current status of a download task
/// * `progress`: current progress value of a download task, the value is in
/// range of 0 and 100
///
typedef void DownloadCallback(String id, DownloadTaskStatus status, int progress);

///
/// A class defines a set of possible statuses of a download task
///
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

///
/// A model class encapsulates all task information according to data in Sqlite
/// database.
///
/// * [taskId] the unique identifier of a download task
/// * [status] the latest status of a download task
/// * [progress] the latest progress value of a download task
/// * [url] the download link
/// * [filename] the local file name of a downloaded file
/// * [savedDir] the absolute path of the directory where the downloaded file is saved
///
class DownloadTask {
  final String taskId;
  final DownloadTaskStatus status;
  final int progress;
  final String url;
  final String filename;
  final String savedDir;

  DownloadTask(
      {this.taskId,
      this.status,
      this.progress,
      this.url,
      this.filename,
      this.savedDir});

  @override
  String toString() =>
      "DownloadTask(taskId: $taskId, status: $status, progress: $progress, url: $url, filename: $filename, savedDir: $savedDir)";
}

///
/// A convenient class wraps all api functions of **FlutterDownloader** plugin
///
class FlutterDownloader {
  static const platform = const MethodChannel('vn.hunghd/downloader');

  ///
  /// Create a new download task
  ///
  /// **parameters:**
  ///
  /// * `url`: download link
  /// * `savedDir`: absolute path of the directory where downloaded file is saved
  /// * `fileName`: name of downloaded file. If this parameter is not set, the
  /// plugin will try to extract a file name from HTTP headers response or `url`
  /// * `headers`: HTTP headers
  /// * `showNotification`: sets `true` to show a notification displaying the
  /// download progress (only Android), otherwise, `false` value will disable
  /// this feature. The default value is `true`
  /// * `openFileFromNotification`: if `showNotification` is `true`, this flag
  /// controls the way to response to user's click action on the notification
  /// (only Android). If it is `true`, user can click on the notification to
  /// open and preview the downloaded file, otherwise, nothing happens. The
  /// default value is `true`
  ///
  /// **return:**
  ///
  /// an unique identifier of the new download task
  ///
  static Future<String> enqueue(
      {@required String url,
      @required String savedDir,
      String fileName,
      Map<String, String> headers,
      bool showNotification = true,
      bool openFileFromNotification = true}) async {
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
        'open_file_from_notification': openFileFromNotification,
      });
      print('Download task is enqueued with id($taskId)');
      return taskId;
    } on PlatformException catch (e) {
      print('Download task is failed with reason(${e.message})');
      return null;
    }
  }

  ///
  /// Load all tasks from Sqlite database
  ///
  /// **return:**
  ///
  /// A list of [DownloadTask] objects
  ///
  static Future<List<DownloadTask>> loadTasks() async {
    try {
      List<dynamic> result = await platform.invokeMethod('loadTasks');
      return result
          .map((item) => new DownloadTask(
              taskId: item['task_id'],
              status: DownloadTaskStatus._internal(item['status']),
              progress: item['progress'],
              url: item['url'],
              filename: item['file_name'],
              savedDir: item['saved_dir']))
          .toList();
    } on PlatformException catch (e) {
      print(e.message);
      return null;
    }
  }

  ///
  /// Load tasks from Sqlite database with SQL statements
  ///
  /// **parameters:**
  ///
  /// * `query`: SQL statement. Note that the plugin will parse loaded data from
  /// database into [DownloadTask] object, in order to make it work, you should
  /// load tasks with all fields from database. In other words, using `SELECT *`
  /// statement.
  ///
  /// **return:**
  ///
  /// A list of [DownloadTask] objects
  ///
  /// **example:**
  ///
  /// ```dart
  /// FlutterDownloader.loadTasksWithRawQuery(query: 'SELECT * FROM task WHERE status=3');
  /// ```
  ///
  static Future<List<DownloadTask>> loadTasksWithRawQuery(
      {@required String query}) async {
    try {
      List<dynamic> result = await platform.invokeMethod('loadTasksWithRawQuery', {'query': query});
      print('Loaded tasks: $result');
      return result
          .map((item) => new DownloadTask(
              taskId: item['task_id'],
              status: DownloadTaskStatus._internal(item['status']),
              progress: item['progress'],
              url: item['url'],
              filename: item['file_name'],
              savedDir: item['saved_dir']))
          .toList();
    } on PlatformException catch (e) {
      print(e.message);
      return null;
    }
  }

  ///
  /// Cancel a given download task
  ///
  /// **parameters:**
  ///
  /// * `taskId`: unique identifier of the download task
  ///
  static Future<Null> cancel({@required String taskId}) async {
    try {
      return await platform.invokeMethod('cancel', {'task_id': taskId});
    } on PlatformException catch (e) {
      print(e.message);
      return null;
    }
  }

  ///
  /// Cancel all enqueued and running download tasks
  ///
  static Future<Null> cancelAll() async {
    try {
      return await platform.invokeMethod('cancelAll');
    } on PlatformException catch (e) {
      print(e.message);
      return null;
    }
  }

  ///
  /// Pause a running download task
  ///
  /// **parameters:**
  ///
  /// * `taskId`: unique identifier of a running download task
  ///
  static Future<Null> pause({@required String taskId}) async {
    try {
      return await platform.invokeMethod('pause', {'task_id': taskId});
    } on PlatformException catch (e) {
      print(e.message);
      return null;
    }
  }

  ///
  /// Resume a paused download task
  ///
  /// **parameters:**
  ///
  /// * `taskId`: unique identifier of a paused download task
  ///
  /// **return:**
  ///
  /// An unique identifier of a new download task that is created to continue
  /// the partial download progress
  ///
  static Future<String> resume({@required String taskId}) async {
    try {
      return await platform.invokeMethod('resume', {'task_id': taskId});
    } on PlatformException catch (e) {
      print(e.message);
      return null;
    }
  }

  ///
  /// Retry a failed download task
  ///
  /// **parameters:**
  ///
  /// * `taskId`: unique identifier of a failed download task
  ///
  /// **return:**
  ///
  /// An unique identifier of a new download task that is created to start the
  /// failed download progress from the beginning
  ///
  static Future<String> retry({@required String taskId}) async {
    try {
      return await platform.invokeMethod('retry', {'task_id': taskId});
    } on PlatformException catch (e) {
      print(e.message);
      return null;
    }
  }

  ///
  /// Open and preview a downloaded file
  ///
  /// **parameters:**
  ///
  /// * `taskId`: An unique identifier of a completed download task
  ///
  /// **return:**
  ///
  /// Returns `true` if the downloaded file can be open on the current device,
  /// `false` in otherwise.
  ///
  /// **Note:**
  ///
  /// In Android case, there're two requirements in order to be able to open
  /// a file:
  /// - The file have to be saved in external storage where other applications
  /// have permission to read this file
  /// - The current device has at least an application that can read the file
  /// type of the file
  ///
  static Future<bool> open({@required String taskId}) async {
    try {
      return await platform.invokeMethod('open', {'task_id': taskId});
    } on PlatformException catch (e) {
      print(e.message);
      return false;
    }
  }

  ///
  /// Register a callback to track status and progress of download task
  ///
  /// **parameters:**
  ///
  /// * `callback`: a function of [DownloadCallback] type which is called whenever
  /// the status or progress value of a download task has been changed.
  ///
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
