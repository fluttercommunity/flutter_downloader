import 'dart:io';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'models.dart';

void callbackDispatcher() {
  const MethodChannel backgroundChannel =
      MethodChannel('vn.hunghd/downloader_background');

  WidgetsFlutterBinding.ensureInitialized();

  backgroundChannel.setMethodCallHandler((MethodCall call) async {
    final List<dynamic> args = call.arguments;
    final handle = CallbackHandle.fromRawHandle(args[0]);
    final Function? callback =
        PluginUtilities.getCallbackFromHandle(handle);

    if (callback == null) {
      print('Fatal: could not find callback');
      exit(-1);
    }

    final String id = args[1];
    final int status = args[2];
    final int progress = args[3];

    callback(id, DownloadTaskStatus(status), progress);
  });

  backgroundChannel.invokeMethod('didInitializeDispatcher');
}
