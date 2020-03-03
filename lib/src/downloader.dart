import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

part 'task.dart';
part 'status.dart';
part 'callback_dispatcher.dart';

File _fileFromDirAndName(String dir, String name) =>
    File('$dir${Platform.pathSeparator}$name');

abstract class FlutterDownloader {
  static const _channel = const MethodChannel('vn.hunghd/downloader');
  static bool _initialized = false;
  static var _tasksById = <String, DownloadTask>{};

  static Future<void> initialize() async {
    assert(!_initialized,
        'FlutterDownloader.initialize() must be called only once.');

    WidgetsFlutterBinding.ensureInitialized();

    final callback = PluginUtilities.getCallbackHandle(dispatchCallback);
    await _channel.invokeMethod('initialize', <dynamic>[
      callback.toRawHandle(),
    ]);

    // Create callback listener.

    final port = ReceivePort()
      ..listen((dynamic data) {
        final id = data[0] as String;
        final status = data[1] as DownloadTaskStatus;
        final progress = data[2] as double;
        _tasksById[id]?._update(status, progress);
      });
    IsolateNameServer.registerPortWithName(port.sendPort, 'downloader_port');
    final callbackHandle = PluginUtilities.getCallbackHandle(_onUpdate);
    _channel.invokeMethod('registerCallback', <dynamic>[
      callbackHandle.toRawHandle(),
    ]);

    _initialized = true;
  }

  static void _onUpdate(String id, DownloadTaskStatus status, double progress) {
    final send = IsolateNameServer.lookupPortByName('downloader_port');
    send.send([id, status, progress]);
  }

  static void _ensureInitialized() {
    assert(_initialized, 'FlutterDownloader.initialize() must be called first');
  }

  static Future<DownloadTask> _enqueue({
    @required String url,
    @required Directory downloadDirectory,
    String fileName,
    Map<String, String> headers,
    bool showNotification,
    bool openFileFromNotification,
    bool requiresStorageNotLow,
  }) async {
    _ensureInitialized();
    assert(downloadDirectory.existsSync());
    assert(showNotification != null);
    assert(openFileFromNotification != null);
    assert(requiresStorageNotLow != null);

    StringBuffer headerBuilder = StringBuffer();
    if (headers != null) {
      headerBuilder
        ..write('{')
        ..writeAll([
          for (final entry in headers.entries)
            '"${entry.key}": "${entry.value}",',
        ])
        ..write('}');
    }

    // This call might fail, in which case we just throw the PlatformException.
    final taskId = await _channel.invokeMethod('enqueue', {
      'url': url,
      'saved_dir': downloadDirectory.path,
      'file_name': fileName,
      'headers': headerBuilder.toString(),
      'show_notification': showNotification,
      'open_file_from_notification': openFileFromNotification,
      'requires_storage_not_low': requiresStorageNotLow,
    }) as String;

    // Create download task.
    final task = DownloadTask._(
      id: taskId,
      status: DownloadTaskStatus.enqueued,
      progress: 0.0,
      url: url,
      destination: _fileFromDirAndName(downloadDirectory.path, fileName),
    );
    _tasksById[taskId] = task;

    return task;
  }

  /// Loads all tasks.
  static Future<List<DownloadTask>> loadTasks() async {
    _ensureInitialized();

    final allTasks = (await _channel.invokeMethod('loadTasks') as List<dynamic>)
        .map((item) => DownloadTask._fromQueryResult(item))
        .toList();

    _tasksById = {
      for (final task in allTasks)
        if (_tasksById.containsKey(task.id))
          task.id: _tasksById[task.id].._merge(task)
        else
          task.id: task,
    };

    return _tasksById.values.toList();
  }

  /// Loads tasks from Sqlite database with a custom SQL statement.
  /// Use the `SELECT *` statement to load tasks with all fields from the
  /// database – otherwise this function will fail because it tries to parse
  /// the result into [DownloadTask]s.
  ///
  /// ```dart
  /// FlutterDownloader.loadTasksWithRawQuery(query: 'SELECT * FROM task WHERE status=3');
  /// ```
  static Future<List<DownloadTask>> loadTasksWithRawQuery(String query) async {
    _ensureInitialized();

    return (await _channel.invokeMethod(
            'loadTasksWithRawQuery', {'query': query}) as List<dynamic>)
        .map((item) => DownloadTask._fromQueryResult(item))
        .toList();
  }

  static Future<void> _cancel(DownloadTask task) async {
    _ensureInitialized();
    await _channel.invokeMethod('cancel', {'task_id': task.id});
  }

  /// Cancels all enqueued and running [DownloadTask]s.
  static Future<void> cancelAllTasks() async {
    _ensureInitialized();
    await _channel.invokeMethod('cancelAll');
  }

  static Future<void> _pause(DownloadTask task) async {
    _ensureInitialized();
    await _channel.invokeMethod('pause', {'task_id': task.id});
  }

  static Future<String> _resume(
    DownloadTask task, {
    bool requiresStorageNotLow,
  }) async {
    _ensureInitialized();
    assert(requiresStorageNotLow != null);

    // TODO(marcelgarus): This returns the id of a newly created [DownloadTask]
    // that represents the rest of the download of the old one.
    return await _channel.invokeMethod('resume', {
      'task_id': task.id,
      'requires_storage_not_low': requiresStorageNotLow,
    });
  }

  static Future<String> _retry(
    DownloadTask task, {
    bool requiresStorageNotLow,
  }) async {
    _ensureInitialized();
    assert(requiresStorageNotLow != null);

    // TODO(marcelgarus): This returns the id of a newly created [DownloadTask]
    // that represents the rest of the download of the old one.
    return await _channel.invokeMethod('retry', {
      'task_id': task.id,
      'requires_storage_not_low': requiresStorageNotLow,
    });
  }

  static Future<void> _remove(DownloadTask task, {bool removeContent}) async {
    _ensureInitialized();
    assert(removeContent != null);

    await _channel.invokeMethod('remove', {
      'task_id': task.id,
      'should_delete_content': removeContent,
    });
  }

  static Future<bool> _openFile(DownloadTask task) async {
    _ensureInitialized();
    return await _channel.invokeMethod('open', {'task_id': task.id});
  }
}
