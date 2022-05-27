import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'callback_dispatcher.dart';
import 'models.dart';

/// Singature for a function which is called when the download state of a task
/// with [id] changes.
typedef DownloadCallback = void Function(
  String id,
  DownloadTaskStatus status,
  int progress,
);

/// Provides access to all functions of the plugin in a single place.
class FlutterDownloader {
  static const _channel = MethodChannel('vn.hunghd/downloader');
  static bool _initialized = false;
  static bool _debug = false;

  /// Initializes the plugin. This must be called before any other method.
  ///
  /// If [debug] is true, then verbose logging is printed to the console.
  ///
  /// To ignore SSL-related errors on Android, set [ignoreSsl] to true. This may
  /// be useful when connecting to a test server which is not using SSL, but
  /// should be never used in production.
  static Future<void> initialize({
    bool debug = false,
    bool ignoreSsl = false,
  }) async {
    assert(
      !_initialized,
      'plugin flutter_downloader has already been initialized',
    );

    _debug = debug;

    WidgetsFlutterBinding.ensureInitialized();

    final callback = PluginUtilities.getCallbackHandle(callbackDispatcher)!;
    await _channel.invokeMethod('initialize', <dynamic>[
      callback.toRawHandle(),
      debug ? 1 : 0,
      ignoreSsl ? 1 : 0,
    ]);

    _initialized = true;
  }

  /// Creates a new task which downloads a file from [url] to [savedDir] and
  /// returns a unique identifier of that new download task.
  ///
  /// Name of the downloaded file is determined from the HTTP response and from
  /// the [url]. Set [fileName] if you want a custom filename.
  ///
  /// [savedDir] must be an absolute path.
  ///
  /// [headers] are HTTP headers that will be sent with the request.
  ///
  /// ### Android-only
  ///
  /// If [showNotification] is true, a notification with the current download
  /// progress will be shown.
  ///
  /// If [requiresStorageNotLow] is true, the download won't run unless the
  /// device's available storage is at an acceptable level.
  ///
  /// If [openFileFromNotification] is true, the user can tap on the
  /// notification to open the downloaded file. If it is false, nothing happens
  /// when the tapping the notification.
  ///
  /// Android Q (API 29) changed the APIs for accessing external storage. This
  /// means that apps must store their data in an app-specific directory on
  /// external storage. If you want to save the file in the public Downloads
  /// directory instead, set [saveInPublicStorage] to true. In that case,
  /// [savedDir] will be ignored.
  static Future<String?> enqueue({
    required String url,
    required String savedDir,
    String? fileName,
    Map<String, String>? headers,
    bool showNotification = true,
    bool openFileFromNotification = true,
    bool requiresStorageNotLow = true,
    bool saveInPublicStorage = false,
  }) async {
    assert(_initialized, 'plugin flutter_downloader is not initialized');
    assert(Directory(savedDir).existsSync(), "savedDir does not exist");

    StringBuffer headerBuilder = StringBuffer();
    if (headers != null) {
      headerBuilder.write('{');
      headerBuilder.writeAll(
        headers.entries.map((entry) => '"${entry.key}": "${entry.value}"'),
        ',',
      );
      headerBuilder.write('}');
    }
    try {
      String? taskId = await _channel.invokeMethod('enqueue', {
        'url': url,
        'saved_dir': savedDir,
        'file_name': fileName,
        'headers': headerBuilder.toString(),
        'show_notification': showNotification,
        'open_file_from_notification': openFileFromNotification,
        'requires_storage_not_low': requiresStorageNotLow,
        'save_in_public_storage': saveInPublicStorage,
      });
      return taskId;
    } on PlatformException catch (e) {
      _log('Download task is failed with reason(${e.message})');
      return null;
    }
  }

  /// Loads all tasks from SQLite database.
  static Future<List<DownloadTask>?> loadTasks() async {
    assert(_initialized, 'plugin flutter_downloader is not initialized');

    try {
      List<dynamic> result = await _channel.invokeMethod('loadTasks');
      return result
          .map((item) => DownloadTask(
              taskId: item['task_id'],
              status: DownloadTaskStatus(item['status']),
              progress: item['progress'],
              url: item['url'],
              filename: item['file_name'],
              savedDir: item['saved_dir'],
              timeCreated: item['time_created']))
          .toList();
    } on PlatformException catch (e) {
      _log(e.message);
      return null;
    }
  }

  /// Loads tasks from SQLite database using raw [query].
  ///
  /// **parameters:**
  ///
  /// * `query`: SQL statement. Note that the plugin will parse loaded data from
  ///   database into [DownloadTask] object, in order to make it work, you
  ///   should load tasks with all fields from database. In other words, using
  ///   `SELECT *` statement.
  ///
  /// Example:
  ///
  /// ```dart
  /// FlutterDownloader.loadTasksWithRawQuery(
  ///   query: 'SELECT * FROM task WHERE status=3',
  /// );
  /// ```
  static Future<List<DownloadTask>?> loadTasksWithRawQuery({
    required String query,
  }) async {
    assert(_initialized, 'plugin flutter_downloader is not initialized');

    try {
      List<dynamic> result = await _channel
          .invokeMethod('loadTasksWithRawQuery', {'query': query});
      return result
          .map((item) => DownloadTask(
              taskId: item['task_id'],
              status: DownloadTaskStatus(item['status']),
              progress: item['progress'],
              url: item['url'],
              filename: item['file_name'],
              savedDir: item['saved_dir'],
              timeCreated: item['time_created']))
          .toList();
    } on PlatformException catch (e) {
      _log(e.message);
      return null;
    }
  }

  /// Cancels download task with id [taskId].
  static Future<void> cancel({required String taskId}) async {
    assert(_initialized, 'plugin flutter_downloader is not initialized');

    try {
      return await _channel.invokeMethod('cancel', {'task_id': taskId});
    } on PlatformException catch (e) {
      _log(e.message);
    }
  }

  /// Cancels all enqueued and running download tasks.
  static Future<void> cancelAll() async {
    assert(_initialized, 'plugin flutter_downloader is not initialized');

    try {
      return await _channel.invokeMethod('cancelAll');
    } on PlatformException catch (e) {
      _log(e.message);
    }
  }

  /// Pauses a running download task with id [taskId].
  ///
  static Future<void> pause({required String taskId}) async {
    assert(_initialized, 'plugin flutter_downloader is not initialized');

    try {
      return await _channel.invokeMethod('pause', {'task_id': taskId});
    } on PlatformException catch (e) {
      _log(e.message);
    }
  }

  /// Resumes a paused download task with id [taskId].
  ///
  /// Returns a new [DownloadTask] that is created to continue the partial
  /// download progress. The new [DownloadTask] has a new [taskId].
  static Future<String?> resume({
    required String taskId,
    bool requiresStorageNotLow = true,
  }) async {
    assert(_initialized, 'plugin flutter_downloader is not initialized');

    try {
      return await _channel.invokeMethod('resume', {
        'task_id': taskId,
        'requires_storage_not_low': requiresStorageNotLow,
      });
    } on PlatformException catch (e) {
      _log(e.message);
      return null;
    }
  }

  /// Retries a failed download task.
  ///
  /// **parameters:**
  ///
  /// * `taskId`: unique identifier of a failed download task
  ///
  /// **return:**
  ///
  /// An unique identifier of a new download task that is created to start the
  /// failed download progress from the beginning
  static Future<String?> retry({
    required String taskId,
    bool requiresStorageNotLow = true,
  }) async {
    assert(_initialized, 'plugin flutter_downloader is not initialized');

    try {
      return await _channel.invokeMethod('retry', {
        'task_id': taskId,
        'requires_storage_not_low': requiresStorageNotLow,
      });
    } on PlatformException catch (e) {
      _log(e.message);
      return null;
    }
  }

  /// Deletes a download task from the database. If the given task is running,
  /// it is also canceled. If the task is completed and [shouldDeleteContent] is
  /// true, the downloaded file will be deleted.
  ///
  /// **parameters:**
  ///
  /// * `taskId`: unique identifier of a download task
  /// * `shouldDeleteContent`: if the task is completed, set `true` to let the
  ///   plugin remove the downloaded file. The default value is `false`.
  static Future<void> remove({
    required String taskId,
    bool shouldDeleteContent = false,
  }) async {
    assert(_initialized, 'plugin flutter_downloader is not initialized');

    try {
      return await _channel.invokeMethod('remove', {
        'task_id': taskId,
        'should_delete_content': shouldDeleteContent,
      });
    } on PlatformException catch (e) {
      _log(e.message);
    }
  }

  /// Opens the downloaded file with [taskId]. Returns true if the downloaded
  /// file can be opened, false otherwise.
  ///
  /// On Android, there are two requirements for opening the file:
  /// - The file must be saved in external storage where other applications have
  ///   permission to read the file
  /// - There is at least 1 application that can read the files of type of the
  ///   file.
  static Future<bool> open({required String taskId}) async {
    assert(_initialized, 'plugin flutter_downloader is not initialized');

    try {
      return await _channel.invokeMethod('open', {'task_id': taskId});
    } on PlatformException catch (e) {
      _log(e.message);
      return false;
    }
  }

  /// Registers a callback to track the status and progress of a download task.
  ///
  /// **parameters:**
  ///
  /// * `callback`: a top-level or static function of [DownloadCallback] type
  ///   which is called whenever the status or progress value of a download task
  ///   has been changed.
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
  ///ReceivePort _port = ReceivePort();
  ///
  ///@override
  ///void initState() {
  ///  super.initState();
  ///
  ///  IsolateNameServer.registerPortWithName(_port.sendPort, 'downloader_send_port');
  ///  _port.listen((dynamic data) {
  ///     String id = data[0];
  ///     DownloadTaskStatus status = data[1];
  ///     int progress = data[2];
  ///     setState((){ });
  ///  });
  ///
  ///  FlutterDownloader.registerCallback(downloadCallback);
  ///
  ///}
  ///
  ///static void downloadCallback(
  /// String id,
  /// DownloadTaskStatus status,
  /// int progress,
  /// ) {
  ///  final SendPort send = IsolateNameServer.lookupPortByName(
  ///   'downloader_send_port',
  ///  );
  ///  send.send([id, status, progress]);
  ///}
  ///
  ///```
  ///
  /// {@end-tool}
  static registerCallback(DownloadCallback callback) {
    assert(_initialized, 'plugin flutter_downloader is not initialized');

    final callbackHandle = PluginUtilities.getCallbackHandle(callback)!;
    _channel.invokeMethod(
      'registerCallback',
      <dynamic>[callbackHandle.toRawHandle()],
    );
  }

  /// Prints [message] to console if [_debug] is true.
  static void _log(String? message) {
    if (_debug) {
      // ignore: avoid_print
      print(message);
    }
  }
}
