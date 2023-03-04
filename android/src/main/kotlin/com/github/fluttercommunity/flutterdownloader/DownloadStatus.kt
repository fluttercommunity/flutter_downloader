package com.github.fluttercommunity.flutterdownloader

/** Defines a set of possible states an [AndroidDownload] can be in. */
enum class DownloadStatus {
    /** The download is in progress. */
    running,

    /** The download has completed successfully. */
    completed,

    /** The download has failed. */
    failed,

    /**
     * The download was canceled and cannot be resumed. When the download instance is freed you this download cannot be
     * recovered without creating a new download of the same url.
     */
    canceled,

    /** The download was paused and can be resumed or restarted, depending on the server. */
    paused,
}