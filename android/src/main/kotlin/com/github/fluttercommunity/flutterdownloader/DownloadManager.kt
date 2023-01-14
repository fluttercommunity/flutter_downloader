package com.github.fluttercommunity.flutterdownloader

import androidx.core.text.isDigitsOnly
import kotlinx.coroutines.*
import java.io.File
import java.lang.IllegalArgumentException
import java.net.URL
import java.security.MessageDigest

/**
 * Manage and persist the download metadata
 */
class DownloadManager private constructor(data: List<String>) {
    val cacheFile: File
        get() = File(FlutterDownloaderPlugin.tempDir, id)
    val headers: Map<String, String> = mutableMapOf()
    val url: URL
    val id: String
    var filename: String? = null
        private set
    var eTag: String? = null
        private set
    val target: Target
    var size: Long = -1
        private set

    companion object {
        fun readConfig(id: String) = DownloadManager(File("${FlutterDownloaderPlugin.tempDir}/$id.meta").readLines())
        fun parseFrom(config: String) = DownloadManager(config.split("\n"))
        fun forUrl(url: String, target: Target) = DownloadManager(listOf(
            "url=$url",
            "target=$target",
            "headers:",
            "User-Agent=${FlutterDownloaderPlugin.userAgent}"
        ))

        private const val HEX_CHARS = "0123456789abcdef"
    }

    init {
        var parseHeaders = false
        var parsedUrl = ""
        var parsedTarget = Target.internal
        data.forEach { row ->
            if (row == "headers:") {
                parseHeaders = true;
            } else {
                val (key, value) = row.split("=")
                if (parseHeaders) {
                    (headers as MutableMap)[key] = value
                } else if (key == "url" && value.isNotEmpty()) {
                    parsedUrl = value
                } else if (key == "etag" && value.isNotEmpty()) {
                    eTag = value
                } else if (key == "size" && value.toLongOrNull() != null) {
                    size = value.toLong()
                } else if (key == "target" && value.isNotEmpty()) {
                    parsedTarget = Target.values().find { it.name == value }
                        ?: throw IllegalArgumentException("Unknown target $value")
                }
            }
        }
        url = URL(parsedUrl)
        id = parsedUrl.sha256()
        target = parsedTarget
        //(headers as MutableMap)["User-Agent"] = FlutterDownloaderPlugin.userAgent
        eTag?.let { eTag ->
            (headers as MutableMap)["If-Match"] = eTag
        }
    }

    /**
     * Interface to enforce that batched changes are persisted.
     */
    suspend fun update(block: MutableDownloadManager.() -> Any) {
        block(object: MutableDownloadManager {
            override val headers: MutableMap<String, String>
                get() = this@DownloadManager.headers as MutableMap<String, String>
            override var filename: String?
                get() = this@DownloadManager.filename
                set(value) {
                    this@DownloadManager.filename = value
                }
            override var eTag: String?
                get() = this@DownloadManager.eTag
                set(value) {
                    this@DownloadManager.eTag = value
                }
            override var size: Long
                get() = this@DownloadManager.size
                set(value) {
                    if(size<-1) throw IllegalArgumentException("The minimal file size is -1 in the case that the server response did not contain the content-length")
                    this@DownloadManager.size = value
                }
        })
        withContext(Dispatchers.IO) {
            File("${FlutterDownloaderPlugin.tempDir}/$id.meta").writer().apply {
                append(toString())
                close()
            }
        }
    }

    interface MutableDownloadManager {
        val headers: MutableMap<String, String>
        var filename: String?
        var eTag: String?
        var size: Long
    }

    override fun toString(): String =
        StringBuilder().apply {
            appendLine("url=$url")
            appendLine("filename=${filename.orEmpty()}")
            appendLine("etag=${eTag.orEmpty()}")
            appendLine("size=$size")
            appendLine("target=$target")
            append("headers:")
            headers.forEach { (key, value) ->
                append("\n$key=$value")
            }
        }.toString()

    private fun String.sha256(): String {
        val bytes = MessageDigest
            .getInstance("SHA-256")
            .digest(toByteArray())
        val result = StringBuilder(bytes.size * 2)

        bytes.forEach {
            val i = it.toInt()
            result.append(HEX_CHARS[i shr 4 and 0x0f])
            result.append(HEX_CHARS[i and 0x0f])
        }

        return result.toString()
    }
}

enum class Target {
    downloadsFolder, desktopFolder, internal
}