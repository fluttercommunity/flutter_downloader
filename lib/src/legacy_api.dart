part of 'downloader.dart';

/// Signature for a function which is called when the download state of a task
/// with [id] changes.
@Deprecated('Use a observer on the Download class')
typedef DownloadCallback = void Function(
  String id,
  DownloadTaskStatus status,
  int progress,
);

/// The legacy parts of the FlutterDownloader. Mostly does nothing
class FlutterDownloaderLegacy {
  static final FlutterDownloader _singleton = FlutterDownloader._internal();

  /// Left for compatibility does nothing.
  @Deprecated('Not used anymore')
  static Future<void> initialize({
    bool debug = false,
    bool ignoreSsl = false,
  }) async {}

  /// Migration path to the new API.
  ///
  /// Creates a new download for the file from [url] and saved to internal
  /// memory.
  ///
  /// If defined the [headers] are passed to the server for the download.
  ///
  /// All other parameters are ignored.
  ///
  /// Returns always null.
  @Deprecated('Use startDownload() instead')
  static Future<String?> enqueue({
    required String url,
    required String savedDir,
    String? fileName,
    Map<String, String> headers = const {},
    bool showNotification = true,
    bool openFileFromNotification = true,
    bool requiresStorageNotLow = true,
    bool saveInPublicStorage = false,
  }) async {
    final download =
        await _singleton.startDownload(url, additionalHeaders: headers);
    return download.urlHash;
  }

  /// Return all downloads in the legacy DownloadTask format when the download
  /// was generated with the deprecated enqueue method, otherwise does returns
  /// an empty list.
  @Deprecated('Use getDownloads() instead')
  static Future<List<DownloadTask>?> loadTasks() async {
    final downloads = await _singleton.getDownloads();
    return downloads
        .map(
          (download) => DownloadTask(
            taskId: download.urlHash,
            status: DownloadTaskStatus.undefined,
            // TODO add migration
            progress: download.progress ~/ 10,
            url: download.url,
            filename: null,
            savedDir: '',
            timeCreated: -1,
          ),
        )
        .toList(growable: false);
  }

  /// Left for compatibility returns null.
  @Deprecated('The database was removed use getDownloads() instead')
  static Future<List<DownloadTask>?> loadTasksWithRawQuery({
    required String query,
  }) async =>
      null;

  /// Cancels the download when the taskId was generated with the deprecated
  /// enqueue method, otherwise does nothing.
  @Deprecated('The Download.cancel() instead')
  static Future<void> cancel({required String taskId}) async {
    for (final download in await _singleton.getDownloads()) {
      if (download.urlHash == taskId) {
        await download.cancel();
        break;
      }
    }
  }

  /// Cancels all enqueued and running download tasks.
  @Deprecated('Iterate over all downloads and cancel them')
  static Future<void> cancelAll() async {
    for (final download in await _singleton.getDownloads()) {
      await download.cancel();
    }
  }

  /// Pauses the download when the taskId was generated with the deprecated
  /// enqueue method, otherwise does nothing.
  @Deprecated('Use Download.pause() instead')
  static Future<void> pause({required String taskId}) async {
    for (final download in await _singleton.getDownloads()) {
      if (download.urlHash == taskId) {
        await download.cancel();
        break;
      }
    }
  }

  /// Resumes the download when the taskId was generated with the deprecated
  /// enqueue method, otherwise does nothing.
  @Deprecated('Use Download.resume() instead')
  static Future<String?> resume({
    required String taskId,
    bool requiresStorageNotLow = true,
  }) async {
    for (final download in await _singleton.getDownloads()) {
      if (download.urlHash == taskId) {
        download.pause();
        return download.urlHash;
      }
    }
    return null;
  }

  /// Retries or resumes the download when the taskId was generated with the
  /// deprecated enqueue method, otherwise does nothing.
  @Deprecated('Use Download.resume() instead')
  static Future<String?> retry({
    required String taskId,
    bool requiresStorageNotLow = true,
  }) async {
    for (final download in await _singleton.getDownloads()) {
      if (download.urlHash == taskId) {
        await download.resume();
        return download.urlHash;
      }
    }
    return null;
  }

  /// Deletes the download when the taskId was generated with the deprecated
  /// enqueue method, otherwise does nothing.
  @Deprecated('Use Download.delete() instead')
  static Future<void> remove({
    required String taskId,
    bool shouldDeleteContent = false,
  }) async {
    for (final download in await _singleton.getDownloads()) {
      if (download.urlHash == taskId) {
        await download.delete();
        break;
      }
    }
  }

  /// Left for compatibility returns false.
  @Deprecated('There is no replacement')
  static Future<bool> open({required String taskId}) async => false;

  /// Left for compatibility does nothing.
  @Deprecated('Use an observer on Download or FlutterDownloader instead')
  static Future<void> registerCallback(
    DownloadCallback callback, {
    int step = 10,
  }) async {}
}
