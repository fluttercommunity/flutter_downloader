// In some cases, it's hard to get around calls on 'dynamic'.
// ignore_for_file: avoid_dynamic_calls

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_downloader/src/exceptions.dart';

import 'callback_dispatcher.dart';
import 'models.dart';

/// Signature for a function which is called when the download state of a task
/// with [id] changes.
typedef DownloadCallback = void Function(
  String id,
  int status,
  int progress,
);

/// Provides access to all functions of the plugin in a single place.
class FlutterDownloader {
  static const _channel = MethodChannel('vn.hunghd/downloader');

  static bool _initialized = false;

  /// Whether the plugin is initialized. The plugin must be initialized before
  /// use.
  static bool get initialized => _initialized;

  static bool _debug = false;

  /// If true, more logs are printed.
  static bool get debug => _debug;

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

    final callback = PluginUtilities.getCallbackHandle(callbackDispatcher)!;
    await _channel.invokeMethod<void>('initialize', <dynamic>[
      callback.toRawHandle(),
      if (debug) 1 else 0,
      if (ignoreSsl) 1 else 0,
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
  ///
  /// [timeout] is the HTTP connection timeout.
  static Future<String?> enqueue({
    required String url,
    required String savedDir,
    String? fileName,
    Map<String, String> headers = const {},
    bool showNotification = true,
    bool openFileFromNotification = true,
    bool requiresStorageNotLow = true,
    bool saveInPublicStorage = false,
    bool allowCellular = true,
    int timeout = 15000,
  }) async {
    assert(_initialized, 'plugin flutter_downloader is not initialized');
    assert(Directory(savedDir).existsSync(), 'savedDir does not exist');

    try {
      final taskId = await _channel.invokeMethod<String>('enqueue', {
        'url': url,
        'saved_dir': savedDir,
        'file_name': fileName,
        'headers': jsonEncode(headers),
        'show_notification': showNotification,
        'open_file_from_notification': openFileFromNotification,
        'requires_storage_not_low': requiresStorageNotLow,
        'save_in_public_storage': saveInPublicStorage,
        'timeout': timeout,
        'allow_cellular': allowCellular,
      });

      if (taskId == null) {
        throw const FlutterDownloaderException(
          message: '`enqueue` returned null taskId',
        );
      }

      return taskId;
    } on FlutterDownloaderException catch (err) {
      _log('Failed to enqueue. Reason: ${err.message}');
    } on PlatformException catch (err) {
      _log('Failed to enqueue. Reason: ${err.message}');
    }

    return null;
  }

  /// Loads all tasks from SQLite database.
  static Future<List<DownloadTask>?> loadTasks() async {
    assert(_initialized, 'plugin flutter_downloader is not initialized');

    try {
      final result = await _channel.invokeMethod<List<dynamic>>('loadTasks');

      if (result == null) {
        throw const FlutterDownloaderException(
          message: '`loadTasks` returned null',
        );
      }

      return result.map(
        (dynamic item) {
          return DownloadTask(
            taskId: item['task_id'] as String,
            status: DownloadTaskStatus.fromInt(item['status'] as int),
            progress: item['progress'] as int,
            url: item['url'] as String,
            filename: item['file_name'] as String?,
            savedDir: item['saved_dir'] as String,
            timeCreated: item['time_created'] as int,

            // allowCellular field is true by default (similar to enqueue())
            allowCellular: (item['allow_cellular'] as bool?) ?? true,
          );
        },
      ).toList();
    } on FlutterDownloaderException catch (err) {
      _log('Failed to load tasks. Reason: ${err.message}');
    } on PlatformException catch (err) {
      _log(err.message);
      return null;
    }
    return null;
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
      final result = await _channel.invokeMethod<List<dynamic>>(
        'loadTasksWithRawQuery',
        {'query': query},
      );

      if (result == null) {
        throw const FlutterDownloaderException(
          message: '`loadTasksWithRawQuery` returned null',
        );
      }

      return result.map(
        (dynamic item) {
          return DownloadTask(
            taskId: item['task_id'] as String,
            status: DownloadTaskStatus.fromInt(item['status'] as int),
            progress: item['progress'] as int,
            url: item['url'] as String,
            filename: item['file_name'] as String?,
            savedDir: item['saved_dir'] as String,
            timeCreated: item['time_created'] as int,

            // allowCellular field is true by default (similar to enqueue())
            allowCellular: (item['allow_cellular'] as bool?) ?? true,
          );
        },
      ).toList();
    } on PlatformException catch (err) {
      _log('Failed to loadTasksWithRawQuery. Reason: ${err.message}');
      return null;
    }
  }

  /// Cancels download task with id [taskId].
  static Future<void> cancel({required String taskId}) async {
    assert(_initialized, 'plugin flutter_downloader is not initialized');

    try {
      await _channel.invokeMethod<void>('cancel', {'task_id': taskId});
    } on PlatformException catch (err) {
      _log(err.message);
    }
  }

  /// Cancels all enqueued and running download tasks.
  static Future<void> cancelAll() async {
    assert(_initialized, 'plugin flutter_downloader is not initialized');

    try {
      return await _channel.invokeMethod('cancelAll');
    } on PlatformException catch (err) {
      _log(err.message);
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
    int timeout = 15000,
  }) async {
    assert(_initialized, 'plugin flutter_downloader is not initialized');

    try {
      return await _channel.invokeMethod('resume', {
        'task_id': taskId,
        'requires_storage_not_low': requiresStorageNotLow,
        'timeout': timeout,
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
  /// * `timeout`: http request connection timeout. Android only.
  ///
  /// **return:**
  ///
  /// An unique identifier of a new download task that is created to start the
  /// failed download progress from the beginning
  static Future<String?> retry({
    required String taskId,
    bool requiresStorageNotLow = true,
    int timeout = 15000,
  }) async {
    assert(_initialized, 'plugin flutter_downloader is not initialized');

    try {
      return await _channel.invokeMethod('retry', {
        'task_id': taskId,
        'requires_storage_not_low': requiresStorageNotLow,
        'timeout': timeout,
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

  /// Opens the file downloaded by download task with [taskId]. Returns true if
  /// the downloaded file can be opened, false otherwise.
  ///
  /// On Android, there are two requirements for opening the file:
  /// - The file must be saved in external storage where other applications have
  ///   permission to read the file
  /// - There must be at least 1 application that can read the files of type of
  ///   the file.
  static Future<bool> open({required String taskId}) async {
    assert(_initialized, 'plugin flutter_downloader is not initialized');

    bool? result;
    try {
      result = await _channel.invokeMethod<bool>(
        'open',
        {'task_id': taskId},
      );

      if (result == null) {
        throw const FlutterDownloaderException(message: '`open` returned null');
      }
    } on PlatformException catch (err) {
      _log('Failed to open downloaded file. Reason: ${err.message}');
    }

    return result ?? false;
  }

  /// Registers a [callback] to track the status and progress of a download
  /// task.
  ///
  /// [callback] must be a top-level or static function of [DownloadCallback]
  /// type which is called whenever the status or progress value of a download
  /// task has been changed.
  ///
  /// Your UI is rendered on the main isolate, while download events come from a
  /// background isolate (in other words, code in [callback] is run in the
  /// background isolate), so you have to handle the communication between two
  /// isolates.
  ///
  /// Example:
  ///
  /// ```dart
  ///ReceivePort _port = ReceivePort();
  ///
  ///@override
  ///void initState() {
  ///  super.initState();
  ///
  ///  IsolateNameServer.registerPortWithName(_port.sendPort, 'downloader_send_port');
  ///  _port.listen((dynamic data) {
  ///     String id = data[0];
  ///     DownloadTaskStatus status = DownloadTaskStatus(data[1]);
  ///     int progress = data[2];
  ///     setState((){ });
  ///  });
  ///
  ///  FlutterDownloader.registerCallback(downloadCallback);
  ///}
  ///
  ///static void downloadCallback(
  ///  String id,
  ///  int status,
  ///  int progress,
  ///  ) {
  ///    final SendPort send = IsolateNameServer.lookupPortByName(
  ///    'downloader_send_port',
  ///  );
  ///  send.send([id, status, progress]);
  ///}
  ///```
  static Future<void> registerCallback(
    DownloadCallback callback, {
    int step = 10,
  }) async {
    assert(_initialized, 'plugin flutter_downloader is not initialized');

    final callbackHandle = PluginUtilities.getCallbackHandle(callback);
    assert(
      callbackHandle != null,
      'callback must be a top-level or static function',
    );

    assert(
      0 <= step && step <= 100,
      'step size is not in the inclusive <0;100> range',
    );

    await _channel.invokeMethod<void>(
      'registerCallback',
      <dynamic>[callbackHandle!.toRawHandle(), step],
    );
  }

  /// Prints [message] to console if [_debug] is true.
  static void _log(String? message) {
    if (_debug) {
      // Using print here seeems good enough.
      // ignore: avoid_print
      print(message);
    }
  }
}
