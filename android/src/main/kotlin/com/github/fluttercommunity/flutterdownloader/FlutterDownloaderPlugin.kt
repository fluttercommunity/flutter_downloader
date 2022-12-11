package com.github.fluttercommunity.flutterdownloader

import android.util.Log
import androidx.annotation.NonNull
import androidx.work.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** FlutterDownloaderPlugin */
class FlutterDownloaderPlugin : FlutterPlugin, MethodCallHandler {
    companion object {
        private const val TAG = "FlutterDownloaderPlugin"
        private const val channelId = "fluttercommunity://flutter_downloader"
        private lateinit var workManager: WorkManager
        private var messenger: BinaryMessenger? = null

        fun getProgressChannel(downloadId: String) = messenger?.let { messenger ->
            MethodChannel(messenger, "$channelId/$downloadId")
        }
        val tempDir get() = tempPath
        private lateinit var tempPath: String
        val userAgent get() = requireNotNull(dartUserAgent)
        private var dartUserAgent: String? = null
    }
    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, channelId)
        channel?.setMethodCallHandler(this)
        workManager = WorkManager.getInstance(flutterPluginBinding.applicationContext)
        tempPath = flutterPluginBinding.applicationContext.cacheDir.absolutePath
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "resume" -> resume(call, result)
            "pause" -> pause(call, result)
            "tempDir" -> result.success(tempPath)
            "setUserAgent" -> updateUserAgent(call, result)
            else -> result.notImplemented()
        }
    }


    /**
     * Resume or start the download
     *
     * Returns true if successful, but will emit a status update that the background task is running
     */
    private fun resume(call: MethodCall, result: Result) {
        val args = call.arguments as List<*>
        val downloadId = args[0] as String
        val config = args[1] as String
        Log.v(TAG, "Starting task with id $downloadId")
        val data = Data.Builder()
            .putString(DownloadWorker.config, config)
            .build()
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()
        val request = OneTimeWorkRequestBuilder<DownloadWorker>()
            .setInputData(data)
            .setConstraints(constraints)
            .addTag(TAG)
            .addTag("downloadId=$downloadId")
            .build()
        val operation = workManager.enqueue(request)
        try {
            operation.result.get()
            Log.v(TAG,"done?")
        } catch (e: Throwable) {
            Log.w(TAG, "Unable to start background request for download $downloadId in operation: $operation")
            result.success(false)
        }
        result.success(true)
    }

    /**
     * Pause a download by canceling the worker.
     *
     * Returns the number of tasks canceled which should be always 1.
     */
    private fun pause(call: MethodCall, result: Result) {
        val downloadId = call.arguments as String
        var counter = 0
        val workers = workManager.getWorkInfosByTag(TAG).get().filter {
            !it.state.isFinished && it.tags.contains("downloadId=$downloadId")
        }
        for (worker in workers) {
            workManager.cancelWorkById(worker.id)
            counter++
        }
        Log.v(TAG, "Paused $counter worker for $downloadId")
        result.success(counter)
    }

    /**
     * Set the user agent build from the dart side
     */
    private fun updateUserAgent(call: MethodCall, result: Result) {
        dartUserAgent = call.arguments as String
        result.success(true)
    }
}