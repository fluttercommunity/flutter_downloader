part of 'downloader.dart';

/// Represents a single ongoing download.
class DownloadTask {
  DownloadTask._({
    @required this.id,
    @required DownloadTaskStatus status,
    @required double progress,
    @required this.url,
    @required this.destination,
  })  : _status = status,
        _progress = progress,
        _updatesController = StreamController() {
    _updates = _updatesController.stream.asBroadcastStream();
  }

  /// Uniquely identifies this [DownloadTask] among all other [DownloadTask]s
  /// that were happing (and will be happening) during this runtime of the app.
  final String id;

  DownloadTaskStatus _status;
  DownloadTaskStatus get status => _status;
  bool get hasUndefinedStatus => status == DownloadTaskStatus.undefined;
  bool get isEnqueued => status == DownloadTaskStatus.enqueued;
  bool get isRunning => status == DownloadTaskStatus.running;
  bool get isPaused => status == DownloadTaskStatus.paused;
  bool get isCompleted => status == DownloadTaskStatus.completed;
  bool get hasFailed => status == DownloadTaskStatus.failed;
  bool get gotCanceled => status == DownloadTaskStatus.canceled;

  /// The progress of this [DownloadTask], where `0.0` refers to nothing being
  /// downloaded yet and `1.0` refers to all data being downloaded.
  double _progress;
  double get progress => _progress;

  /// The url that this task downloads from.
  final String url;

  /// The local file that this tasks downloads to.
  final File destination;

  StreamController<DownloadTask> _updatesController;
  Stream<DownloadTask> _updates;
  Stream<DownloadTask> get updates => _updates;

  /// Creates a new [DownloadTask].
  /// If the [fileName] is not set, it will be extracted from HTTP headers
  /// response or the [url].
  /// [showNotification] and [openFileFromNotification] both only work on
  /// Android.
  static Future<DownloadTask> create({
    @required String url,
    @required Directory downloadDirectory,
    String fileName,
    Map<String, String> httpHeaders,
    bool showNotification = true,
    bool openFileFromNotification = true,
    bool requiresStorageNotLow = true,
  }) =>
      FlutterDownloader._enqueue(
        url: url,
        downloadDirectory: downloadDirectory,
        fileName: fileName,
        headers: httpHeaders,
        showNotification: showNotification,
        openFileFromNotification: openFileFromNotification,
        requiresStorageNotLow: requiresStorageNotLow,
      );

  DownloadTask._fromQueryResult(dynamic result)
      : this._(
          id: result['task_id'] as String,
          status: _StatusByValue.create(result['status']),
          progress: (result['progress'] as int).toDouble() * 0.01,
          url: result['url'] as String,
          destination: _fileFromDirAndName(
              result['saved_dir'] as String, result['file_name'] as String),
        );

  void _merge(DownloadTask other) {
    // Id, url and destination file shouldn't change.
    assert(id == other.id);
    assert(url == other.url);
    assert(destination.path == other.destination.path);

    _update(other.status, other.progress);
  }

  void _update(DownloadTaskStatus status, double progress) {
    _status = status;
    _progress = progress;

    _updatesController.add(this);
  }

  @override
  String toString() => 'DownloadTask #$id (${status.toShortString()} – '
      '${(progress * 100.0).toStringAsFixed(0)} %): $url -> ${destination.path}';

  // onUpdate(VoidCallback callback);

  Future<void> pause() => FlutterDownloader._pause(this);
  Future<String> resume() => FlutterDownloader._resume(this);
  Future<void> cancel() => FlutterDownloader._cancel(this);
  Future<String> retry() => FlutterDownloader._retry(this);

  /// Removes the task.
  /// If the task is running, it's cancelled.
  /// If the task is completed and and [removeContent] is set to `true`, the
  /// downloaded file will be deleted.
  Future<void> remove({bool removeContent = false}) =>
      FlutterDownloader._remove(this, removeContent: removeContent);

  /// Opens and previews a downloaded file.
  /// Returns `true` if the downloaded file can be opened on the current device,
  /// `false` otherwise.
  ///
  /// **Note:**
  ///
  /// To succeed on Android, these two requirements need to be met:
  /// - The file has to be saved in external storage where other applications
  /// have permission to read this file.
  /// - The current device has at least an application that can read the file
  /// type of the file.
  Future<bool> openFile() => FlutterDownloader._openFile(this);
}
