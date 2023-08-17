import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Pragma annotation is needed to avoid tree shaking in release mode. See
/// https://github.com/dart-lang/sdk/blob/master/runtime/docs/compiler/aot/entry_point_pragma.md
@pragma('vm:entry-point')
void callbackDispatcher() {
  const backgroundChannel = MethodChannel('vn.hunghd/downloader_background');

  WidgetsFlutterBinding.ensureInitialized();

  backgroundChannel
    ..setMethodCallHandler((call) async {
      final args = call.arguments as List<dynamic>;
      final handle = CallbackHandle.fromRawHandle(args[0] as int);
      final id = args[1] as String;
      final status = args[2] as int;
      final progress = args[3] as int;

      final callback = PluginUtilities.getCallbackFromHandle(handle) as void
          Function(String id, int status, int progress)?;

      if (callback == null) {
        // The callback wasn't registered. Ignore.
        return;
      }

      callback(id, status, progress);
    })
    ..invokeMethod<void>('didInitializeDispatcher');
}
