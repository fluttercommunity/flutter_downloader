package com.github.fluttercommunity.flutterdownloader

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.BufferedInputStream
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.SocketException
import java.net.URL
import kotlin.coroutines.cancellation.CancellationException

/**
 * The DownloadWorker is a [CoroutineWorker] that downloads a file in the background and reports status updates using
 * [MethodChannel] in the [AndroidDownload] class.
 *
 * The required input of the DownloadWorker is the field `urlHash` with the sha1 of the download url.
 */
class DownloadWorker(
    applicationContext: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(applicationContext, workerParams) {
    companion object {
        private const val TAG = "DownloadWorker"
    }

    private val urlHash by lazy { requireNotNull(inputData.getString("urlHash")) }
    private val download by lazy { AndroidDownload(urlHash) }

    // The actual download work
    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        var canRecoverError = true
        try {
            // TODO just use the url of the metadata when the redirect part is done on the dart side
            val (finalUrl, httpConnection) = download.url.followRedirects(limit = 5)
            if (httpConnection.responseCode == 200) {
                download.updateStatus(DownloadStatus.running)

                val contentLength = httpConnection.getHeaderField("content-length").toLongOrNull()
                if (contentLength != null) {
                    download.updateContentLength(contentLength)
                }

                try {
                    finalUrl.downloadRange(download.cacheFile.length(), contentLength)
                    if (isStopped) {
                        throw CancellationException()
                    }
                    moveDownloadToItsTarget()
                    Log.i(TAG, "Successfully downloaded $urlHash")
                    download.updateStatus(DownloadStatus.completed)
                    return@withContext Result.success()
                } catch (e: FileSystemException) {
                    Log.e(TAG, "Filesystem exception downloading $urlHash", e)
                } catch (e: SocketException) {
                    Log.e(TAG, "Socket exception downloading $urlHash", e)
                } catch (e: CancellationException) {
                    Log.v(TAG, "Job $urlHash cancelled")
                }
            } else {
                Log.e(TAG, "Unexpected response code ${httpConnection.responseCode} for download $urlHash")
                canRecoverError = false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error downloading $urlHash", e)
        }
        download.updateStatus(if (canRecoverError) DownloadStatus.paused else DownloadStatus.failed)
        Result.failure()
    }

    /** Extension function to download a range of a file to the cache file */
    private suspend fun URL.downloadRange(first: Long, last: Long?) = withContext(Dispatchers.IO) {
        var bytesReceivedTotal = first
        var lastProgress = 0L
        val canResume = first > 0 && last != null
        val responseStream = openConnection().also { request ->
            if (canResume) {
                request.setRequestProperty("Range", "bytes=$first-$last".also(::println))
            }
            download.metadata.etag?.let { etag ->
                request.setRequestProperty("If-Match", etag)
            }
        }.getInputStream()
        BufferedInputStream(responseStream).use { inputStream ->
            FileOutputStream(download.cacheFile, canResume).use { fileOutputStream ->
                val dataBuffer = ByteArray(8096)
                var bytesRead: Int
                while (inputStream.read(dataBuffer, 0, 8096).also { bytesRead = it } != -1) {
                    if (isStopped) {
                        break
                    }
                    fileOutputStream.write(dataBuffer, 0, bytesRead)
                    bytesReceivedTotal += bytesRead
                    last?.let {
                        val progress = bytesReceivedTotal * 1000 / last
                        if (progress != lastProgress) {
                            lastProgress = progress
                            download.updateProgress(progress)
                            //println("Update: ${progress / 10.0}%")
                        }
                    }
                }
            }
        }
    }

    private fun moveDownloadToItsTarget() {
        // TODO move to final position using scoped storage or fallback to external storage on legacy platforms
        /*
        val destFile = File(filePath)
        dir = destFile.parentFile
        if (!dir.exists()) {
            dir.mkdirs()
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Files.move(
                tempFile.toPath(),
                destFile.toPath(),
                StandardCopyOption.REPLACE_EXISTING
            )
        } else {
            tempFile.copyTo(destFile, overwrite = true)
            tempFile.delete()
        }*/
    }

    // TODO move this and the commented out part to the dart side this is required for all platforms
    private fun URL.followRedirects(limit: Int): Pair<URL, HttpURLConnection> {
        var httpConnection = openConnection() as HttpURLConnection
        httpConnection.addHeaders(download.metadata.headers)
        httpConnection.requestMethod = "HEAD"
        var responseCode = httpConnection.responseCode
        var redirects = 0
        var url = this
        while (responseCode in 301..307 && redirects < limit) {
            redirects++
            url = URL(httpConnection.getHeaderField("Location"))
            httpConnection = url.openConnection() as HttpURLConnection
            httpConnection.addHeaders(download.metadata.headers)
            Log.v(TAG, "Redirecting to $url")
            httpConnection = url.openConnection() as HttpURLConnection
            httpConnection.requestMethod = "HEAD"
            responseCode = httpConnection.responseCode
        }
        return url to httpConnection
    }

    /*
    private val charsetPattern = Pattern.compile("(?i)\\bcharset=\\s*\"?([^\\s;\"]*)")
    private val filenameStarPattern = Pattern.compile("(?i)\\bfilename\\*=([^']+)'([^']*)'\"?([^\"]+)\"?")
    private val filenamePattern = Pattern.compile("(?i)\\bfilename=\"?([^\"]+)\"?")

    private fun getCharsetFromContentType(contentType: String?): String? {
        if (contentType == null) return null
        val m = charsetPattern.matcher(contentType)
        return if (m.find()) {
            m.group(1)?.trim { it <= ' ' }?.uppercase(Locale.US)
        } else null
    }

    private fun getFileNameFromContentDisposition(
        disposition: String?,
        contentCharset: String?
    ): String? {
        if (disposition == null) return null
        var name: String? = null
        var charset = contentCharset

        //first, match plain filename, and then replace it with star filename, to follow the spec
        val plainMatcher = filenamePattern.matcher(disposition)
        if (plainMatcher.find()) name = plainMatcher.group(1)
        val starMatcher = filenameStarPattern.matcher(disposition)
        if (starMatcher.find()) {
            name = starMatcher.group(3)
            charset = starMatcher.group(1)?.uppercase(Locale.US)
        }
        return if (name == null) null else URLDecoder.decode(
            name,
            charset ?: "ISO-8859-1"
        )
    }
    */
}

private fun HttpURLConnection.addHeaders(headers: Map<String, String>) =
    headers.forEach { (header, value) ->
        addRequestProperty(header, value)
    }
