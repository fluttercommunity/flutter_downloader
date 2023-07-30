package vn.hunghd.flutterdownloader

import android.content.ContentResolver
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.MediaStore
import android.util.Log
import androidx.core.app.NotificationManagerCompat
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.Data
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequest
import androidx.work.WorkManager
import androidx.work.WorkRequest
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.TimeUnit

private const val invalidTaskId = "invalid_task_id"
private const val invalidStatus = "invalid_status"
private const val invalidData = "invalid_data"

class FlutterDownloaderPlugin : MethodChannel.MethodCallHandler, FlutterPlugin {
    private var flutterChannel: MethodChannel? = null
    private var taskDao: TaskDao? = null
    private var context: Context? = null
    private var callbackHandle: Long = 0
    private var step = 0
    private var debugMode = 0
    private var ignoreSsl = 0
    private val initializationLock = Any()

    private fun onAttachedToEngine(applicationContext: Context?, messenger: BinaryMessenger) {
        synchronized(initializationLock) {
            if (flutterChannel != null) {
                return
            }
            context = applicationContext
            flutterChannel = MethodChannel(messenger, CHANNEL)
            flutterChannel?.setMethodCallHandler(this)
            val dbHelper: TaskDbHelper = TaskDbHelper.getInstance(context)
            taskDao = TaskDao(dbHelper)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> initialize(call, result)
            "registerCallback" -> registerCallback(call, result)
            "enqueue" -> enqueue(call, result)
            "loadTasks" -> loadTasks(result)
            "loadTasksWithRawQuery" -> loadTasksWithRawQuery(call, result)
            "cancel" -> cancel(call, result)
            "cancelAll" -> cancelAll(result)
            "pause" -> pause(call, result)
            "resume" -> resume(call, result)
            "retry" -> retry(call, result)
            "open" -> open(call, result)
            "remove" -> remove(call, result)
            else -> result.notImplemented()
        }
    }

    override fun onAttachedToEngine(binding: FlutterPluginBinding) {
        onAttachedToEngine(binding.applicationContext, binding.binaryMessenger)
    }

    override fun onDetachedFromEngine(binding: FlutterPluginBinding) {
        context = null
        flutterChannel?.setMethodCallHandler(null)
        flutterChannel = null
    }

    private fun requireContext() = requireNotNull(context)

    private fun buildRequest(
        url: String?,
        savedDir: String?,
        filename: String?,
        headers: String?,
        showNotification: Boolean,
        openFileFromNotification: Boolean,
        isResume: Boolean,
        requiresStorageNotLow: Boolean,
        saveInPublicStorage: Boolean,
        timeout: Int,
        allowCellular: Boolean
    ): WorkRequest {
        return OneTimeWorkRequest.Builder(DownloadWorker::class.java)
            .setConstraints(
                Constraints.Builder()
                    .setRequiresStorageNotLow(requiresStorageNotLow)
                    .setRequiredNetworkType(if (allowCellular) NetworkType.CONNECTED else NetworkType.UNMETERED)
                    .build()
            )
            .addTag(TAG)
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 10, TimeUnit.SECONDS)
            .setInputData(
                Data.Builder()
                    .putString(DownloadWorker.ARG_URL, url)
                    .putString(DownloadWorker.ARG_SAVED_DIR, savedDir)
                    .putString(DownloadWorker.ARG_FILE_NAME, filename)
                    .putString(DownloadWorker.ARG_HEADERS, headers)
                    .putBoolean(DownloadWorker.ARG_SHOW_NOTIFICATION, showNotification)
                    .putBoolean(
                        DownloadWorker.ARG_OPEN_FILE_FROM_NOTIFICATION,
                        openFileFromNotification
                    )
                    .putBoolean(DownloadWorker.ARG_IS_RESUME, isResume)
                    .putLong(DownloadWorker.ARG_CALLBACK_HANDLE, callbackHandle)
                    .putInt(DownloadWorker.ARG_STEP, step)
                    .putBoolean(DownloadWorker.ARG_DEBUG, debugMode == 1)
                    .putBoolean(DownloadWorker.ARG_IGNORESSL, ignoreSsl == 1)
                    .putBoolean(
                        DownloadWorker.ARG_SAVE_IN_PUBLIC_STORAGE,
                        saveInPublicStorage
                    )
                    .putInt(DownloadWorker.ARG_TIMEOUT, timeout)
                    .build()
            )
            .build()
    }

    private fun sendUpdateProgress(id: String, status: DownloadStatus, progress: Int) {
        val args: MutableMap<String, Any> = HashMap()
        args["task_id"] = id
        args["status"] = status.ordinal
        args["progress"] = progress
        flutterChannel?.invokeMethod("updateProgress", args)
    }

    private fun initialize(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as List<*>
        val callbackHandle = args[0].toString().toLong()
        debugMode = args[1].toString().toInt()
        ignoreSsl = args[2].toString().toInt()
        val pref =
            context?.getSharedPreferences(SHARED_PREFERENCES_KEY, Context.MODE_PRIVATE)
        pref?.edit()?.putLong(CALLBACK_DISPATCHER_HANDLE_KEY, callbackHandle)?.apply()
        result.success(null)
    }

    private fun registerCallback(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as List<*>
        callbackHandle = args[0].toString().toLong()
        step = args[1].toString().toInt()
        result.success(null)
    }

    private fun <T> MethodCall.requireArgument(key: String): T = requireNotNull(argument(key)) {
        "Required key '$key' was null"
    }

    private fun enqueue(call: MethodCall, result: MethodChannel.Result) {
        val url: String = call.requireArgument("url")
        val savedDir: String = call.requireArgument("saved_dir")
        val filename: String? = call.argument("file_name")
        val headers: String = call.requireArgument("headers")
        val timeout: Int = call.requireArgument("timeout")
        val showNotification: Boolean = call.requireArgument("show_notification")
        val openFileFromNotification: Boolean = call.requireArgument("open_file_from_notification")
        val requiresStorageNotLow: Boolean = call.requireArgument("requires_storage_not_low")
        val saveInPublicStorage: Boolean = call.requireArgument("save_in_public_storage")
        val allowCellular: Boolean = call.requireArgument("allow_cellular")
        val request: WorkRequest = buildRequest(
            url,
            savedDir,
            filename,
            headers,
            showNotification,
            openFileFromNotification,
            false,
            requiresStorageNotLow,
            saveInPublicStorage,
            timeout,
            allowCellular = allowCellular
        )
        WorkManager.getInstance(requireContext()).enqueue(request)
        val taskId: String = request.id.toString()
        result.success(taskId)
        sendUpdateProgress(taskId, DownloadStatus.ENQUEUED, 0)
        taskDao!!.insertOrUpdateNewTask(
            taskId,
            url,
            DownloadStatus.ENQUEUED,
            0,
            filename,
            savedDir,
            headers,
            showNotification,
            openFileFromNotification,
            saveInPublicStorage,
            allowCellular = allowCellular
        )
    }

    private fun loadTasks(result: MethodChannel.Result) {
        val tasks = taskDao!!.loadAllTasks()
        val array: MutableList<Map<*, *>> = ArrayList()
        for (task in tasks) {
            val item: MutableMap<String, Any?> = HashMap()
            item["task_id"] = task.taskId
            item["status"] = task.status.ordinal
            item["progress"] = task.progress
            item["url"] = task.url
            item["file_name"] = task.filename
            item["saved_dir"] = task.savedDir
            item["time_created"] = task.timeCreated
            item["allow_cellular"] = task.allowCellular
            array.add(item)
        }
        result.success(array)
    }

    private fun loadTasksWithRawQuery(call: MethodCall, result: MethodChannel.Result) {
        val query: String = call.requireArgument("query")
        val tasks = taskDao!!.loadTasksWithRawQuery(query)
        val array: MutableList<Map<*, *>> = ArrayList()
        for (task in tasks) {
            val item: MutableMap<String, Any?> = HashMap()
            item["task_id"] = task.taskId
            item["status"] = task.status.ordinal
            item["progress"] = task.progress
            item["url"] = task.url
            item["file_name"] = task.filename
            item["saved_dir"] = task.savedDir
            item["time_created"] = task.timeCreated
            item["allow_cellular"] = task.allowCellular
            array.add(item)
        }
        result.success(array)
    }

    private fun cancel(call: MethodCall, result: MethodChannel.Result) {
        val taskId: String = call.requireArgument("task_id")
        WorkManager.getInstance(requireContext()).cancelWorkById(UUID.fromString(taskId))
        result.success(null)
    }

    private fun cancelAll(result: MethodChannel.Result) {
        WorkManager.getInstance(requireContext()).cancelAllWorkByTag(TAG)
        result.success(null)
    }

    private fun pause(call: MethodCall, result: MethodChannel.Result) {
        val taskId: String = call.requireArgument("task_id")
        // mark the current task is cancelled to process pause request
        // the worker will depends on this flag to prepare data for resume request
        taskDao!!.updateTask(taskId, true)
        // cancel running task, this method causes WorkManager.isStopped() turning true and the download loop will be stopped
        WorkManager.getInstance(requireContext()).cancelWorkById(UUID.fromString(taskId))
        result.success(null)
    }

    private fun resume(call: MethodCall, result: MethodChannel.Result) {
        val taskId: String = call.requireArgument("task_id")
        val task = taskDao!!.loadTask(taskId)
        val requiresStorageNotLow: Boolean = call.requireArgument("requires_storage_not_low")
        var timeout: Int = call.requireArgument("timeout")
        if (task != null) {
            if (task.status == DownloadStatus.PAUSED) {
                var filename = task.filename
                if (filename == null) {
                    filename = task.url.substring(task.url.lastIndexOf("/") + 1, task.url.length)
                }
                val partialFilePath = task.savedDir + File.separator + filename
                val partialFile = File(partialFilePath)
                if (partialFile.exists()) {
                    val request: WorkRequest = buildRequest(
                        task.url,
                        task.savedDir,
                        task.filename,
                        task.headers,
                        task.showNotification,
                        task.openFileFromNotification,
                        true,
                        requiresStorageNotLow,
                        task.saveInPublicStorage,
                        timeout,
                        allowCellular = task.allowCellular
                    )
                    val newTaskId: String = request.id.toString()
                    result.success(newTaskId)
                    sendUpdateProgress(newTaskId, DownloadStatus.RUNNING, task.progress)
                    taskDao!!.updateTask(
                        taskId,
                        newTaskId,
                        DownloadStatus.RUNNING,
                        task.progress,
                        false
                    )
                    WorkManager.getInstance(requireContext()).enqueue(request)
                } else {
                    taskDao!!.updateTask(taskId, false)
                    result.error(
                        invalidData,
                        "not found partial downloaded data, this task cannot be resumed",
                        null
                    )
                }
            } else {
                result.error(invalidStatus, "only paused task can be resumed", null)
            }
        } else {
            result.error(invalidTaskId, "not found task corresponding to given task id", null)
        }
    }

    private fun retry(call: MethodCall, result: MethodChannel.Result) {
        val taskId: String = call.requireArgument("task_id")
        val task = taskDao!!.loadTask(taskId)
        val requiresStorageNotLow: Boolean = call.requireArgument("requires_storage_not_low")
        var timeout: Int = call.requireArgument("timeout")
        if (task != null) {
            if (task.status == DownloadStatus.FAILED || task.status == DownloadStatus.CANCELED) {
                val request: WorkRequest = buildRequest(
                    task.url, task.savedDir, task.filename,
                    task.headers, task.showNotification, task.openFileFromNotification,
                    false, requiresStorageNotLow, task.saveInPublicStorage, timeout, allowCellular = task.allowCellular
                )
                val newTaskId: String = request.id.toString()
                result.success(newTaskId)
                sendUpdateProgress(newTaskId, DownloadStatus.ENQUEUED, task.progress)
                taskDao!!.updateTask(
                    taskId,
                    newTaskId,
                    DownloadStatus.ENQUEUED,
                    task.progress,
                    false
                )
                WorkManager.getInstance(requireContext()).enqueue(request)
            } else {
                result.error(invalidStatus, "only failed and canceled task can be retried", null)
            }
        } else {
            result.error(invalidTaskId, "not found task corresponding to given task id", null)
        }
    }

    private fun open(call: MethodCall, result: MethodChannel.Result) {
        val taskId: String = call.requireArgument("task_id")
        val task = taskDao!!.loadTask(taskId)
        if (task == null) {
            result.error(invalidTaskId, "not found task with id $taskId", null)
            return
        }

        if (task.status != DownloadStatus.COMPLETE) {
            result.error(invalidStatus, "only completed tasks can be opened", null)
            return
        }

        val fileURL = task.url
        val savedDir = task.savedDir
        var filename = task.filename
        if (filename == null) {
            filename = fileURL.substring(fileURL.lastIndexOf("/") + 1, fileURL.length)
        }
        val saveFilePath = savedDir + File.separator + filename
        val intent: Intent? =
            IntentUtils.validatedFileIntent(requireContext(), saveFilePath, task.mimeType)
        if (intent != null) {
            requireContext().startActivity(intent)
            result.success(true)
        } else {
            result.success(false)
        }
    }

    private fun remove(call: MethodCall, result: MethodChannel.Result) {
        val taskId: String = call.requireArgument("task_id")
        val shouldDeleteContent: Boolean = call.requireArgument("should_delete_content")
        val task = taskDao!!.loadTask(taskId)
        if (task != null) {
            if (task.status == DownloadStatus.ENQUEUED || task.status == DownloadStatus.RUNNING) {
                WorkManager.getInstance(requireContext()).cancelWorkById(UUID.fromString(taskId))
            }
            if (shouldDeleteContent) {
                var filename = task.filename
                if (filename == null) {
                    filename = task.url.substring(task.url.lastIndexOf("/") + 1, task.url.length)
                }
                val saveFilePath = task.savedDir + File.separator + filename
                val tempFile = File(saveFilePath)
                if (tempFile.exists()) {
                    try {
                        deleteFileInMediaStore(tempFile)
                    } catch (e: SecurityException) {
                        Log.d(
                            "FlutterDownloader",
                            "Failed to delete file in media store, will fall back to normal delete()"
                        )
                    }
                    tempFile.delete()
                }
            }
            taskDao!!.deleteTask(taskId)
            NotificationManagerCompat.from(requireContext()).cancel(task.primaryId)
            result.success(null)
        } else {
            result.error(invalidTaskId, "not found task corresponding to given task id", null)
        }
    }

    private fun deleteFileInMediaStore(file: File) {
        // Set up the projection (we only need the ID)
        val projection = arrayOf(MediaStore.Images.Media._ID)

        // Match on the file path
        val imageSelection: String = MediaStore.Images.Media.DATA + " = ?"
        val selectionArgs = arrayOf<String>(file.absolutePath)

        // Query for the ID of the media matching the file path
        val imageQueryUri: Uri = MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        val contentResolver: ContentResolver = requireContext().contentResolver

        // search the file in image store first
        val imageCursor = contentResolver.query(imageQueryUri, projection, imageSelection, selectionArgs, null)
        if (imageCursor != null && imageCursor.moveToFirst()) {
            // We found the ID. Deleting the item via the content provider will also remove the file
            val id: Long =
                imageCursor.getLong(imageCursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID))
            val deleteUri = ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id)
            contentResolver.delete(deleteUri, null, null)
        } else {
            // File not found in image store DB, try to search in video store
            val videoCursor = contentResolver.query(imageQueryUri, projection, imageSelection, selectionArgs, null)
            if (videoCursor != null && videoCursor.moveToFirst()) {
                // We found the ID. Deleting the item via the content provider will also remove the file
                val id: Long =
                    videoCursor.getLong(videoCursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID))
                val deleteUri: Uri =
                    ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id)
                contentResolver.delete(deleteUri, null, null)
            } else {
                // can not find the file in media store DB at all
            }
            videoCursor?.close()
        }
        imageCursor?.close()
    }

    companion object {
        private const val CHANNEL = "vn.hunghd/downloader"
        private const val TAG = "flutter_download_task"
        const val SHARED_PREFERENCES_KEY = "vn.hunghd.downloader.pref"
        const val CALLBACK_DISPATCHER_HANDLE_KEY = "callback_dispatcher_handle_key"
    }
}
