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
    final int progress = args[3];

    callback(id, _StatusByValue.create(status), progress);
  });

  backgroundChannel.invokeMethod('didInitializeDispatcher');
}

// ReceivePort _port = ReceivePort();
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
