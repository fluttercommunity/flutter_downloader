import 'dart:io';
import 'dart:ui';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'callback_dispatcher.dart';
import 'models.dart';

///
/// A signature function for download progress updating callback
///
/// * `id`: unique identifier of a download task
/// * `status`: current status of a download task
/// * `progress`: current progress value of a download task, the value is in
/// range of 0 and 100
///
typedef void DownloadCallback(
    String id, DownloadTaskStatus status, int progress);

///
/// A convenient class wraps all api functions of **FlutterDownloader** plugin
///
class FlutterDownloader {
  static const _channel = const MethodChannel('vn.hunghd/downloader');
  static bool _initialized = false;

  static Future<Null> initialize() async {
    assert(!_initialized,
        'FlutterDownloader.initialize() must be called only once!');

    WidgetsFlutterBinding.ensureInitialized();

    final callback = PluginUtilities.getCallbackHandle(callbackDispatcher);
    await _channel
        .invokeMethod('initialize', <dynamic>[callback.toRawHandle()]);
    _initialized = true;
    return null;
  }

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
      bool openFileFromNotification = true,
      bool requiresStorageNotLow = true}) async {
    assert(_initialized, 'FlutterDownloader.initialize() must be called first');
    assert(Directory(savedDir).existsSync());

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
      String taskId = await _channel.invokeMethod('enqueue', {
        'url': url,
        'saved_dir': savedDir,
        'file_name': fileName,
        'headers': headerBuilder.toString(),
        'show_notification': showNotification,
        'open_file_from_notification': openFileFromNotification,
        'requires_storage_not_low': requiresStorageNotLow,
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
    assert(_initialized, 'FlutterDownloader.initialize() must be called first');

    try {
      List<dynamic> result = await _channel.invokeMethod('loadTasks');
      return result
          .map((item) => new DownloadTask(
              taskId: item['task_id'],
              status: DownloadTaskStatus(item['status']),
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
    assert(_initialized, 'FlutterDownloader.initialize() must be called first');

    try {
      List<dynamic> result = await _channel
          .invokeMethod('loadTasksWithRawQuery', {'query': query});
      print('Loaded tasks: $result');
      return result
          .map((item) => new DownloadTask(
              taskId: item['task_id'],
              status: DownloadTaskStatus(item['status']),
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
    assert(_initialized, 'FlutterDownloader.initialize() must be called first');

    try {
      return await _channel.invokeMethod('cancel', {'task_id': taskId});
    } on PlatformException catch (e) {
      print(e.message);
      return null;
    }
  }

  ///
  /// Cancel all enqueued and running download tasks
  ///
  static Future<Null> cancelAll() async {
    assert(_initialized, 'FlutterDownloader.initialize() must be called first');

    try {
      return await _channel.invokeMethod('cancelAll');
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
    assert(_initialized, 'FlutterDownloader.initialize() must be called first');

    try {
      return await _channel.invokeMethod('pause', {'task_id': taskId});
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
  static Future<String> resume({
    @required String taskId,
    bool requiresStorageNotLow = true,
  }) async {
    assert(_initialized, 'FlutterDownloader.initialize() must be called first');

    try {
      return await _channel.invokeMethod('resume', {
        'task_id': taskId,
        'requires_storage_not_low': requiresStorageNotLow,
      });
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
  static Future<String> retry({
    @required String taskId,
    bool requiresStorageNotLow = true,
  }) async {
    assert(_initialized, 'FlutterDownloader.initialize() must be called first');

    try {
      return await _channel.invokeMethod('retry', {
        'task_id': taskId,
        'requires_storage_not_low': requiresStorageNotLow,
      });
    } on PlatformException catch (e) {
      print(e.message);
      return null;
    }
  }

  ///
  /// Delete a download task from DB. If the given task is running, it is canceled
  /// as well. If the task is completed and `shouldDeleteContent` is `true`,
  /// the downloaded file will be deleted.
  ///
  /// **parameters:**
  ///
  /// * `taskId`: unique identifier of a download task
  /// * `shouldDeleteContent`: if the task is completed, set `true` to let the
  /// plugin remove the downloaded file. The default value is `false`.
  ///
  static Future<Null> remove(
      {@required String taskId, bool shouldDeleteContent = false}) async {
    assert(_initialized, 'FlutterDownloader.initialize() must be called first');

    try {
      return await _channel.invokeMethod('remove',
          {'task_id': taskId, 'should_delete_content': shouldDeleteContent});
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
    assert(_initialized, 'FlutterDownloader.initialize() must be called first');

    try {
      return await _channel.invokeMethod('open', {'task_id': taskId});
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
  /// * `callback`: a top-level or static function of [DownloadCallback] type
  /// which is called whenever the status or progress value of a download task
  /// has been changed.
  ///
  /// **Note:**
  ///
  /// Your UI is rendered in the main isolate, while download events come from a
  /// background isolate (in other words, codes in `callback` are run in the
  /// background isolate), so you have to handle the communication between two
  /// isolates.
  ///
  /// **Example:**
  ///
  /// {@tool sample}
  ///
  /// ```dart
  ///
  /// ReceivePort _port = ReceivePort();
  ///
  /// @override
  /// void initState() {
  ///   super.initState();
  ///
  ///   IsolateNameServer.registerPortWithName(_port.sendPort, 'downloader_send_port');
  ///   _port.listen((dynamic data) {
  ///      String id = data[0];
  ///      DownloadTaskStatus status = data[1];
  ///      int progress = data[2];
  ///      setState((){ });
  ///   });
  ///
  ///   FlutterDownloader.registerCallback(downloadCallback);
  ///
  /// }
  ///
  /// static void downloadCallback(String id, DownloadTaskStatus status, int progress) {
  ///   final SendPort send = IsolateNameServer.lookupPortByName('downloader_send_port');
  ///   send.send([id, status, progress]);
  /// }
  ///
  /// ```
  ///
  /// {@end-tool}
  ///
  static registerCallback(DownloadCallback callback) {
    assert(_initialized, 'FlutterDownloader.initialize() must be called first');

    final callbackHandle = PluginUtilities.getCallbackHandle(callback);
    assert(callbackHandle != null,
        'callback must be a top-level or a static function');
    _channel.invokeMethod(
        'registerCallback', <dynamic>[callbackHandle.toRawHandle()]);
  }
}
