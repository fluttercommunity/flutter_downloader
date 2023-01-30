package com.github.fluttercommunity.flutterdownloader

import android.util.Log
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
        private const val channelId = "fluttercommunity/flutter_downloader"
        private lateinit var workManager: WorkManager
        internal var messenger: BinaryMessenger? = null

        fun getBackChannel(urlHash: String) = MethodChannel(requireNotNull(messenger), "$channelId/$urlHash")
        val tempDir get() = tempPath
        private lateinit var tempPath: String
        private var dartUserAgent: String? = null
    }
    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        messenger = flutterPluginBinding.binaryMessenger
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, channelId)
        channel?.setMethodCallHandler(this)
        workManager = WorkManager.getInstance(flutterPluginBinding.applicationContext)
        tempPath = flutterPluginBinding.applicationContext.cacheDir.absolutePath
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        messenger = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getCacheDir" -> result.success(tempPath)
            "resume" -> resume(call, result)
            "pause" -> pause(call, result)
            else -> result.notImplemented()
        }
    }

    /**
     * Resumes the existing download, or starts a new download.
     *
     * Returns true if successful, but will emit a status update that the background task is running
     */
    private fun resume(call: MethodCall, result: Result) {
        val urlHash = call.arguments as String
        val data = Data.Builder()
            .putString("urlHash", urlHash)
            .build()
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()
        val request = OneTimeWorkRequestBuilder<DownloadWorker>()
            .setInputData(data)
            .setConstraints(constraints)
            .addTag(TAG)
            .addTag("urlHash=$urlHash")
            .build()
        val operation = workManager.enqueue(request)
        try {
            operation.result.get()
            Log.v(TAG,"done?")
        } catch (e: Throwable) {
            Log.w(TAG, "Unable to start background request for download $urlHash in operation: $operation")
            result.success(false)
        }

        result.success(true)
    }

    /**
     * Pauses the download identified by @param urlHash by canceling the worker.
     *
     * Returns the number of tasks canceled. This number should be always 1.
     */
    private fun pause(call: MethodCall, result: Result) {
        val urlHash = call.arguments as String
        var counter = 0
        val workers = workManager.getWorkInfosByTag(TAG).get().filter {
            !it.state.isFinished && it.tags.contains("urlHash=$urlHash")
        }
        for (worker in workers) {
            workManager.cancelWorkById(worker.id)
            counter++
        }
        Log.v(TAG, "Paused $counter worker for $urlHash")
        if(counter > 0) {
            KotlinDownload(urlHash).status = DownloadStatus.paused
        }
        result.success(counter)
    }
}
