package com.github.fluttercommunity.flutterdownloader

import androidx.annotation.UiThread
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.json.Json
import java.io.File
import java.net.URL

/**
 * The Kotlin part of the PlatformDownload from dart. This class holds the metadata and sends with a [MethodChannel]
 * changes back to the dart code.
 */
internal class AndroidDownload(
    /** The URL hashed with sha1. It's used as internal, unique identifier of this download */
    val urlHash: String
) {
    private val backChannel = FlutterDownloaderPlugin.getBackChannel(urlHash)

    /** The metadata for the download */
    val metadata: DownloadMetadata

    /** The url to download */
    val url: URL

    init {
        val metaFile = File("${FlutterDownloaderPlugin.tempDir}/$urlHash.meta").readText()
        metadata = Json.decodeFromString(metaFile)
        url = URL(metadata.url)
    }

    /** The cache file of the (partial) download */
    val cacheFile = File(FlutterDownloaderPlugin.tempDir, "$urlHash.part")

    /** The final file size of the file to download */
    var finalSize: Long? = null
        private set

    /** The progress of the download in permille [0..1000] */
    var progress: Long = 0
        private set

    /** The current status of this download */
    var status: DownloadStatus = DownloadStatus.paused
        private set


    /** Update the download's status on main thread */
    suspend fun updateStatus(newStatus: DownloadStatus) = withContext(Dispatchers.Main) {
        status = newStatus

        backChannel.invokeMethod("updateStatus", newStatus.name)
    }

    /** Update the download's final size on main thread */
    suspend fun updateFinalSize(newSize: Long) = withContext(Dispatchers.Main) {
        finalSize = newSize

        backChannel.invokeMethod("updateSize", newSize)
    }

    /** Update the download's progress on main thread */
    suspend fun updateProgress(newProgress: Long) = withContext(Dispatchers.Main) {
        progress = newProgress

        backChannel.invokeMethod("updateProgress", newProgress)
    }
}
