package com.github.fluttercommunity.flutterdownloader

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.BufferedInputStream
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.SocketException
import java.net.URL
import kotlin.coroutines.cancellation.CancellationException

/**
 * A simple worker that posts the input its given back to the Flutter application.
 *
 * It blocks the background thread until a value of either true or false is received back from Flutter code.
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

/* TODO move this to the dart side this is required for all platforms

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

    override suspend fun doWork(): Result {
        var canRecoverError = true
        withContext(Dispatchers.IO) {
            try {
                val (finalUrl, httpConnection) = download.url.followRedirects(limit = 5)
                if (httpConnection.responseCode == 200) {
                    withContext(Dispatchers.Main) {
                        download.status = DownloadStatus.running
                    }
                    val contentLength = httpConnection.contentLengthOrNull()?.also { contentLength ->
                        withContext(Dispatchers.Main) {
                            download.finalSize = contentLength
                        }
                    }

                    try {
                        finalUrl.downloadRange(0, contentLength)
                        if (!isStopped) {
                            moveDownloadToItsTarget()
                            Log.i(TAG, "Successfully downloaded ${download.urlHash}")
                            withContext(Dispatchers.Main) {
                                download.status = DownloadStatus.completed
                            }
                            return@withContext Result.success()
                        } else {
                            throw CancellationException()
                        }
                    } catch (e: FileSystemException) {
                        Log.e(TAG, "Filesystem exception downloading ${download.urlHash}", e)
                    } catch (e: SocketException) {
                        Log.e(TAG, "Socket exception downloading ${download.urlHash}", e)
                    } catch (e: CancellationException) {
                        Log.v(TAG, "Job ${download.urlHash} cancelled")
                    }
                } else {
                    Log.e(TAG, "Unexpected response code ${httpConnection.responseCode} for download ${download.urlHash}")
                    canRecoverError = false
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error downloading from ${download.url}", e)
            }
        }
        withContext(Dispatchers.Main) {
            download.status = if(canRecoverError) DownloadStatus.paused else DownloadStatus.failed
        }
        return Result.failure()
    }

    // TODO move this to dart
    private fun URL.followRedirects(limit: Int): Pair<URL, HttpURLConnection> {
        var httpConnection = openConnection() as HttpURLConnection
        httpConnection.addHeaders(download.headers)
        httpConnection.requestMethod = "HEAD"
        var responseCode = httpConnection.responseCode
        var redirects = 0
        var url = this
        while (responseCode in 301..307 && redirects < limit) {
            redirects++
            url = URL(httpConnection.getHeaderField("Location"))
            httpConnection = url.openConnection() as HttpURLConnection
            httpConnection.addHeaders(download.headers)
            Log.v(TAG, "Redirecting to $url")
            httpConnection = url.openConnection() as HttpURLConnection
            httpConnection.requestMethod = "HEAD"
            responseCode = httpConnection.responseCode
        }
        return url to httpConnection
    }

    private suspend fun URL.downloadRange(first: Long, last: Long?) = withContext(Dispatchers.IO) {
        var bytesReceivedTotal = first
        var lastProgress = 0L
        // TODO apply range requests
        val responseStream = openConnection().getInputStream()
        BufferedInputStream(responseStream).use { inputStream ->
            FileOutputStream(download.cacheFile).use { fileOutputStream ->
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
                            withContext(Dispatchers.Main) {
                                download.progress = progress
                            }
                            //println("Update: ${progress / 10.0}%")
                        }
                    }
                }
            }
        }
    }

    private fun HttpURLConnection.contentLengthOrNull() =
        getHeaderField("content-length").toLongOrNull()


    private fun moveDownloadToItsTarget() {
        // TODO move to final position
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
}

private fun HttpURLConnection.addHeaders(headers: Map<String, String>) =
    headers.forEach { (header, value) ->
        addRequestProperty(header, value)
    }
