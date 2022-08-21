import 'dart:developer';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

late Box<DownloadTaskHiveObject> taskBox;

// pragma annotation is needed to avoid tree shaking in release mode
// https://github.com/dart-lang/sdk/blob/master/runtime/docs/compiler/aot/entry_point_pragma.md
@pragma('vm:entry-point')
void callbackDispatcher() async {
  const MethodChannel backgroundChannel =
      MethodChannel('vn.hunghd/downloader_background');

  WidgetsFlutterBinding.ensureInitialized();

  backgroundChannel.setMethodCallHandler((MethodCall call) async {
    switch (call.method) {
      case 'initDatabase':
        final appDir = call.arguments[0] as String;
        Hive.init(appDir);
        Hive.registerAdapter(DownloadTaskHiveObjectAdapter());
        Hive.registerAdapter(DownloadTaskStatusAdapter());
        taskBox = await Hive.openBox<DownloadTaskHiveObject>("tasks");
        break;
      case 'createDownloaderTask':
        try {
          final methodArgs = call.arguments;
          final task = DownloadTaskHiveObject(
            taskId: methodArgs["taskId"] as String,
            status: DownloadTaskStatus.values[methodArgs["status"] as int],
            progress: methodArgs["progress"] as int,
            url: methodArgs["url"] as String,
            filename: methodArgs["filename"] as String?,
            headers: methodArgs["headers"] as String?,
            savedDir: methodArgs["savedDir"] as String,
            timeCreated: null,
          );
          taskBox.add(task);
        } on Exception catch (e) {
          print(e.toString());
        }

        break;
      case 'getDownloaderTask':
        final String taskId = call.arguments[0] as String;
        final task =
            taskBox.values.singleWhere((element) => element.taskId == taskId);
        return {
          "id": task.key.toString(),
          "taskId": task.taskId,
          "url": task.url,
          "savedDir": task.savedDir,
          "filename": task.filename,
          "progress": task.progress,
          "status": task.status.index,
          "headers": task.headers,
        };
      case 'setDownloaderTask':
        final handle = CallbackHandle.fromRawHandle(call.arguments[0]);
        final callback = PluginUtilities.getCallbackFromHandle(handle);

        if (callback == null) {
          // ignore: avoid_print
          print('fatal error: could not find callback');
          exit(1);
        }

        final methodArgs = call.arguments[1];
        final String taskId = methodArgs["taskId"] as String;
        final task =
            taskBox.values.singleWhere((element) => element.taskId == taskId);

        task.progress = methodArgs["progress"] as int;
        task.status = DownloadTaskStatus.values[methodArgs["status"] as int];
        task.filename = methodArgs["filename"] as String?;
        await task.save();
        callback(task.key, task.status, task.progress);
        break;
      case 'deleteDownloaderTask':
        final String taskId = call.arguments[0] as String;
        final task =
            taskBox.values.singleWhere((element) => element.taskId == taskId);
        await task.delete();
        break;
    }
  });

  backgroundChannel.invokeMethod('didInitializeDispatcher');
}
