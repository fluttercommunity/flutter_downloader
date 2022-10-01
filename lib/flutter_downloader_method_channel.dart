import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_downloader_platform_interface.dart';

/// An implementation of [FlutterDownloaderPlatform] that uses method channels.
class MethodChannelFlutterDownloader extends FlutterDownloaderPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_downloader');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
