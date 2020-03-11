part of 'downloader.dart';

void dispatchCallback() {
  const backgroundChannel = MethodChannel('vn.hunghd/downloader_background');

  WidgetsFlutterBinding.ensureInitialized();

  backgroundChannel.setMethodCallHandler((MethodCall call) async {
    final List<dynamic> args = call.arguments;

    final Function callback = PluginUtilities.getCallbackFromHandle(
        CallbackHandle.fromRawHandle(args[0]));

    final String id = args[1];
    final int status = args[2];
    final double progress = (args[3] as int) / 100.0;

    callback(id, status, progress);
  });

  backgroundChannel.invokeMethod('didInitializeDispatcher');
}
