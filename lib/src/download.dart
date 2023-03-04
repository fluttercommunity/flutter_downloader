import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_downloader/src/download_controller.dart';

/// The current download status/progress
abstract class Download extends ChangeNotifier
    implements DownloadProgress, DownloadController {
  /// The url of the download
  String get url;
}
