package com.github.fluttercommunity.flutterdownloader

/** The target where the download should be visible for the user.*/
enum class DownloadTarget {
    /** Put the download in the download folder. */
    downloadsFolder,

    /** Put the download in the desktop folder. Since Android has no desktop the internal storage will be used instead. */
    desktopFolder,

    /** Put the download into the internal storage of the app. */
    internal,
}