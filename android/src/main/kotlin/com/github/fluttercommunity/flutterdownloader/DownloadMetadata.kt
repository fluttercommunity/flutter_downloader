package com.github.fluttercommunity.flutterdownloader

import kotlinx.serialization.Serializable

/** The metadata of the file to download */
@Serializable
data class DownloadMetadata(
    /** The url to download */
    val url: String,
    /** The filename which should be used for the filesystem */
    var filename: String?,
    /** The [ETag](https://developer.mozilla.org/docs/Web/HTTP/Headers/ETag), if given, to resume the download */
    val etag: String?,
    /** The target of the download */
    val target: DownloadTarget,
    /** The final file size of the file to download */
    val size: Long?,
    /** The request headers */
    val headers: Map<String, String>,
)
