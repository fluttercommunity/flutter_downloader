package com.github.fluttercommunity.flutterdownloader

import android.content.Context
import android.net.Uri
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import kotlinx.coroutines.*
import java.io.BufferedInputStream
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.SocketException
import java.net.URL
import java.net.URLDecoder
import java.util.*
import java.util.regex.Pattern
import kotlin.coroutines.cancellation.CancellationException

/***
 * A simple worker that will post your input back to your Flutter application.
 *
 * It will block the background thread until a value of either true or false is received back from Flutter code.
 */
class DownloadWorker(
    applicationContext: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(applicationContext, workerParams) {

    companion object {
        const val TAG = "DownloadWorker"
        const val config = "config"
    }

    /**
     * Processes a change in status for the task
     *
     * Sends status update via the background channel to Flutter, if requested, and if the task
     * is finished, processes a final status update and remove references to persistent storage
     * * /
    fun processStatusUpdate(
    backgroundDownloadTask: BackgroundDownloadTask,
    status: DownloadTaskStatus
    ) {
    if (backgroundDownloadTask.providesStatusUpdates()) {
    Handler(Looper.getMainLooper()).post {
    try {
    val gson = Gson()
    val arg = listOf<Any>(
    gson.toJson(backgroundDownloadTask.toJsonMap()),
    status.ordinal
    )
    BackgroundDownloaderPlugin.backgroundChannel?.invokeMethod(
    "statusUpdate",
    arg
    )
    } catch (e: Exception) {
    Log.w(TAG, "Exception trying to post status update: ${e.message}")
    }
    }
    }
    // if task is in final state, process a final progressUpdate and remove from
    // persistent storage
    if (status != DownloadTaskStatus.running) {
    when (status) {
    DownloadTaskStatus.complete -> processProgressUpdate(
    backgroundDownloadTask,
    1.0
    )
    DownloadTaskStatus.failed -> processProgressUpdate(backgroundDownloadTask, -1.0)
    DownloadTaskStatus.canceled -> processProgressUpdate(
    backgroundDownloadTask,
    -2.0
    )
    DownloadTaskStatus.notFound -> processProgressUpdate(
    backgroundDownloadTask,
    -3.0
    )
    else -> {}
    }
    BackgroundDownloaderPlugin.prefsLock.write {
    val jsonString =
    BackgroundDownloaderPlugin.prefs.getString(
    BackgroundDownloaderPlugin.keyTasksMap,
    "{}"
    )
    val backgroundDownloadTaskMap =
    BackgroundDownloaderPlugin.gson.fromJson<Map<String, Any>>(
    jsonString,
    BackgroundDownloaderPlugin.mapType
    ).toMutableMap()
    backgroundDownloadTaskMap.remove(backgroundDownloadTask.taskId)
    val editor = BackgroundDownloaderPlugin.prefs.edit()
    editor.putString(
    BackgroundDownloaderPlugin.keyTasksMap,
    BackgroundDownloaderPlugin.gson.toJson(backgroundDownloadTaskMap)
    )
    editor.apply()
    }
    }
    } // */

    /**
     * Processes a progress update for the [backgroundDownloadTask]
     *
     * Sends progress update via the background channel to Flutter, if requested
     * /
    fun processProgressUpdate(
    backgroundDownloadTask: BackgroundDownloadTask,
    progress: Double
    ) {
    if (backgroundDownloadTask.providesProgressUpdates()) {
    Handler(Looper.getMainLooper()).post {
    try {
    val gson = Gson()
    val arg =
    listOf<Any>(gson.toJson(backgroundDownloadTask.toJsonMap()), progress)
    BackgroundDownloaderPlugin.backgroundChannel?.invokeMethod(
    "progressUpdate",
    arg
    )
    } catch (e: Exception) {
    Log.w(TAG, "Exception trying to post progress update: ${e.message}")
    }
    }
    }
    } // */

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

    /*fun foo(httpConn: HttpURLConnection) {
        val contentType = httpConn.contentType
        val charset = getCharsetFromContentType(contentType)
        val disposition: String? = httpConn.getHeaderField("Content-Disposition")
        var filename: String? = null
        if (!disposition.isNullOrEmpty()) {
            filename = getFileNameFromContentDisposition(disposition, charset)
        }
        if (filename.isNullOrEmpty()) {
            filename = url.substring(url.lastIndexOf("/") + 1)
            try {
                filename = URLDecoder.decode(filename, "UTF-8")
            } catch (e: IllegalArgumentException) {
                /* ok, just let filename be not encoded */
                e.printStackTrace()
            }
        }
    }*/

    override suspend fun doWork(): Result {
        val manager = DownloadManager.readConfig(requireNotNull(inputData.getString("urlHash")))
        Log.i(TAG, "Starting download ${manager.url}...")
        val status = FlutterDownloaderPlugin.getProgressChannel(manager.id)
        withContext(Dispatchers.IO) {


            try {
                var url = manager.url
                Uri.parse(url.toString()).lastPathSegment
                var httpConnection = url.openConnection() as HttpURLConnection
                httpConnection.addHeaders(manager.headers)
                httpConnection.requestMethod = "HEAD"
                var responseCode = httpConnection.responseCode
                var redirects = 0
                while (responseCode in 301..307 && redirects < 5) {
                    redirects++
                    url = URL(httpConnection.getHeaderField("Location"))
                    httpConnection.addHeaders(manager.headers)
                    Log.v(TAG, "Redirecting to $url")
                    httpConnection = url.openConnection() as HttpURLConnection
                    httpConnection.requestMethod = "HEAD"
                    responseCode = httpConnection.responseCode
                }
                if (responseCode == 200) {
                    val contentLength = httpConnection.getHeaderField("content-length").toLongOrNull() ?: -1
                    var bytesReceivedTotal = 0L
                    var lastProgressUpdate = 0.0
                    var nextProgressUpdateTime = 0L
                    httpConnection.getHeaderField("content-disposition")
                    try {
                        BufferedInputStream(url.openStream()).use { `in` ->
                            FileOutputStream(manager.cacheFile).use { fileOutputStream ->
                                val dataBuffer = ByteArray(8096)
                                var bytesRead: Int
                                while (`in`.read(dataBuffer, 0, 8096).also { bytesRead = it } != -1) {
                                    if (isStopped) {
                                        break
                                    }
                                    fileOutputStream.write(dataBuffer, 0, bytesRead)
                                    bytesReceivedTotal += bytesRead
                                    // TODO provide progress
                                    //val progress =
                                    //    min(bytesReceivedTotal.toDouble() / contentLength, 0.999)
                                    //if (contentLength > 0 &&
                                    //    (bytesReceivedTotal < 10000 || (progress - lastProgressUpdate > 0.02 && System.currentTimeMillis() > nextProgressUpdateTime))
                                    //) {
                                    //    //processProgressUpdate(downloadTask, progress)
                                    //    lastProgressUpdate = progress
                                    //    nextProgressUpdateTime = System.currentTimeMillis() + 500
                                    //}
                                }
                            }
                        }
                        if (!isStopped) {
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
                        } else {
                            Log.v(TAG, "Canceled task for ${manager.id}")
                            return@withContext Result.failure()
                        }
                        Log.i(
                            TAG,
                            "Successfully downloaded taskId ${manager.id} to $ filePath"
                        )
                        return@withContext Result.success()
                    } catch (e: Exception) {
                        when (e) {
                            is FileSystemException -> Log.w(
                                TAG,
                                "Filesystem exception downloading from ${manager.url} to $ filePath: ${e.message}"
                            )
                            is SocketException -> Log.i(
                                TAG,
                                "Socket exception downloading from ${manager.url} to $ filePath: ${e.message}"
                            )
                            is CancellationException -> {
                                Log.v(TAG, "Job cancelled: ${manager.url} to $ filePath: ${e.message}")
                                return@withContext Result.failure()
                            }
                            else -> Log.w(
                                TAG,
                                "Error downloading from ${manager.url} to $ filePath: ${e.message}"
                            )
                        }
                    }
                    return@withContext Result.failure()
                } else {
                    Log.i(
                        TAG,
                        "Response code $responseCode for download from  ${manager.url} to $ filePath"
                    )
                    //return if (responseCode == 404) {
                    //    DownloadTaskStatus.notFound
                    //} else {
                    //    DownloadTaskStatus.failed
                    //}
                    return@withContext Result.failure()
                }
            } catch (e: Exception) {
                Log.w(
                    TAG,
                    "Error downloading from ${manager.url} to $ {downloadTask.filename}: $e"
                )
                return@withContext Result.failure()
            }
        }
        return Result.success()
    }
}

private fun HttpURLConnection.addHeaders(headers: Map<String, String>) =
    headers.forEach { (header, value) ->
        addRequestProperty(header, value)
    }
