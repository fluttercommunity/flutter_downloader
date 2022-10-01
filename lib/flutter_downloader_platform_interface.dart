import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_downloader_method_channel.dart';

abstract class FlutterDownloaderPlatform extends PlatformInterface {
  /// Constructs a FlutterDownloaderPlatform.
  FlutterDownloaderPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterDownloaderPlatform _instance = MethodChannelFlutterDownloader();

  /// The default instance of [FlutterDownloaderPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterDownloader].
  static FlutterDownloaderPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterDownloaderPlatform] when
  /// they register themselves.
  static set instance(FlutterDownloaderPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
