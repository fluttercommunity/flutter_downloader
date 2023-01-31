package com.github.fluttercommunity.flutterdownloader

import androidx.annotation.UiThread
import java.io.File
import java.net.URL

/**
 * The Kotlin part of the PlatformDownload from dart. The naming should be quiet similar to the dart and Swift
 * implementation. Some details will differ since that are different programming languages.
 */
internal class AndroidDownload(
    /** The URL hashed with sha1. It's used as internal, unique identifier of this download */
    val urlHash: String
) {
    /** The cache file of the (partial) download */
    val cacheFile = File(FlutterDownloaderPlugin.tempDir, "$urlHash.part")

    /** The request headers */
    val headers = mutableMapOf<String, String>()
    val url: URL

    /** The filename which should be used for the filesystem */
    var filename: String? = null
        private set

    /** The [ETag](https://developer.mozilla.org/docs/Web/HTTP/Headers/ETag), if given, to resume the download */
    var eTag: String? = null
        private set

    /** The target of the download */
    val target: DownloadTarget

    /** The final file size of the file to download */
    var finalSize: Long? = null
        @UiThread
        set(value) {
            field = value

            backChannel.invokeMethod("updateSize", value)
        }

    /** The progress of the download in permille [0..1000] */
    var progress: Long = 0
        @UiThread
        set(value) {
            field = value

            backChannel.invokeMethod("updateProgress", value)
        }

    /** The current status of this download */
    var status: DownloadStatus = DownloadStatus.paused
        @UiThread set(value) {
            field = value

            backChannel.invokeMethod("updateStatus", value.name)
        }

    private val backChannel = FlutterDownloaderPlugin.getBackChannel(urlHash)

    init {
        // TODO replace with a simpler JSON structure
        var parseHeaders = false
        var parsedUrl = ""
        var parsedTarget = DownloadTarget.internal
        val metaFile = File("${FlutterDownloaderPlugin.tempDir}/$urlHash.meta")
        metaFile.readLines().forEach { row ->
            if (row == "headers:") {
                parseHeaders = true
            } else {
                val (key, value) = row.split("=", limit = 2)
                if (parseHeaders) {
                    headers[key] = value
                } else if (key == "url" && value.isNotEmpty()) {
                    parsedUrl = value
                } else if (key == "etag" && value.isNotEmpty()) {
                    eTag = value
                } else if (key == "size" && value.toLongOrNull() != null) {
                    finalSize = value.toLong()
                } else if (key == "target" && value.isNotEmpty()) {
                    parsedTarget = DownloadTarget.values().find { it.name == value }
                        ?: throw IllegalArgumentException("Unknown target $value")
                }
            }
        }
        url = URL(parsedUrl)
        target = parsedTarget
        eTag?.let { eTag ->
            headers["If-Match"] = eTag
        }
    }
}
