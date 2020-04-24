part of 'downloader.dart';

/// Represents a single download.
class DownloadTask {
  DownloadTask._({
    @required String id,
    @required DownloadTaskStatus status,
    @required double progress,
    @required this.url,
    @required File destination,
  })  : _id = id,
        _status = status,
        _progress = progress,
        _destination = destination,
        _updatesController = StreamController() {
    _updates = _updatesController.stream.asBroadcastStream();
  }

  /// Uniquely identifies this [DownloadTask] among all other [DownloadTask]s
  /// that were happing, are happening and will be happening during this
  /// runtime of the app.
  /// The [id] will change if you [pause] and [resume] this task or if you
  /// [retry] this task after it [hasFailed] or [gotCanceled].
  String get id => _id;
  String _id;

  /// The [status] of this task.
  /// For more readable code, check out the [hasUndefinedStatus], [isEnqueued],
  /// [isRunning], [isPaused], [isCompleted], [hasFailed], [gotCanceled]
  /// getters.
  DownloadTaskStatus get status => _status;
  DownloadTaskStatus _status;
  bool get hasUndefinedStatus => status == DownloadTaskStatus.undefined;
  bool get isEnqueued => status == DownloadTaskStatus.enqueued;
  bool get isRunning => status == DownloadTaskStatus.running;
  bool get isPaused => status == DownloadTaskStatus.paused;
  bool get isCompleted => status == DownloadTaskStatus.completed;
  bool get hasFailed => status == DownloadTaskStatus.failed;
  bool get gotCanceled => status == DownloadTaskStatus.canceled;

  /// The progress of this task, where `0.0` refers to nothing being downloaded
  /// yet and `1.0` refers to all data being downloaded.
  double get progress => _progress;
  double _progress;

  /// The [url] that this task downloads from.
  final String url;

  /// The local file that this tasks downloads to.
  File get destination => _destination;
  File _destination;

  /// A [Stream] that repeatedly emits [this] [DownloadTask] whenever some of
  /// its fields change.
  Stream<DownloadTask> get updates => _updates;
  StreamController<DownloadTask> _updatesController;
  Stream<DownloadTask> _updates;

  // The following are functions and methods that interact with the
  // [FlutterDownloader].

  /// Creates a new [DownloadTask].
  /// If the [destinationFileName] is not set, it will be extracted from HTTP headers
  /// response or the [url].
  /// Both [showNotification] and [openFileFromNotification] only work on
  /// Android.
  static Future<DownloadTask> create({
    @required String url,
    @required Directory downloadDirectory,
    String destinationFileName,
    Map<String, String> httpHeaders,
    bool showNotification = true,
    bool openFileFromNotification = true,
    bool requiresStorageNotLow = true,
  }) =>
      FlutterDownloader._enqueue(
        url: url,
        downloadDirectory: downloadDirectory,
        fileName: destinationFileName,
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
    assert(url == other.url);

    _update(other.id, other.status, other.progress, other.destination);
  }

  void _update(
      String id, DownloadTaskStatus status, double progress, File destination) {
    if (_id != id ||
        _status != status ||
        _progress != progress ||
        _destination != destination) {
      _id = id;
      _status = status;
      _progress = progress;
      _destination = destination;

      _updatesController.add(this);
    }
  }

  @override
  String toString() => 'DownloadTask #$id (${status.toShortString()} – '
      '${(progress * 100.0).toStringAsFixed(0)} %): $url -> ${destination.path}';

  Future<void> pause() => FlutterDownloader._pause(this);
  Future<void> resume({bool requiresStorageNotLow = true}) async {
    _merge(await FlutterDownloader._resume(
      this,
      requiresStorageNotLow: requiresStorageNotLow,
    ));
  }

  Future<void> cancel() => FlutterDownloader._cancel(this);
  Future<void> retry({bool requiresStorageNotLow = true}) async {
    _merge(await FlutterDownloader._retry(
      this,
      requiresStorageNotLow: requiresStorageNotLow,
    ));
  }

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

  Future<void> wait() async {
    await updates.firstWhere(
      (task) => task.isCompleted || task.gotCanceled || task.hasFailed,
      orElse: () => null,
    );
  }
}
