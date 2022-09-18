package vn.hunghd.flutterdownloader

enum class DownloadStatus {
    UNDEFINED,
    ENQUEUED,
    RUNNING,
    COMPLETE,
    FAILED,
    CANCELED,
    PAUSED
}
