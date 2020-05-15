package vn.hunghd.flutterdownloader;

import android.annotation.SuppressLint;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;

import androidx.core.app.NotificationManagerCompat;

import java.io.File;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.TimeUnit;

import androidx.work.BackoffPolicy;
import androidx.work.Constraints;
import androidx.work.Data;
import androidx.work.NetworkType;
import androidx.work.OneTimeWorkRequest;
import androidx.work.WorkManager;
import androidx.work.WorkRequest;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.PluginRegistry;

public class FlutterDownloaderPlugin implements MethodCallHandler, FlutterPlugin {
    private static final String CHANNEL = "vn.hunghd/downloader";
    private static final String TAG = "flutter_download_task";

    public static final String SHARED_PREFERENCES_KEY = "vn.hunghd.downloader.pref";
    public static final String CALLBACK_DISPATCHER_HANDLE_KEY = "callback_dispatcher_handle_key";

    private static FlutterDownloaderPlugin instance;
    private MethodChannel flutterChannel;
    private TaskDbHelper dbHelper;
    private TaskDao taskDao;
    private Context context;
    private long callbackHandle;
    private int debugMode;
    private final Object initializationLock = new Object();

    @SuppressLint("NewApi")
    public static void registerWith(PluginRegistry.Registrar registrar) {
        if (instance == null) {
            instance = new FlutterDownloaderPlugin();
        }
        instance.onAttachedToEngine(registrar.context(), registrar.messenger());
    }

    public void onAttachedToEngine(Context applicationContext, BinaryMessenger messenger) {
        synchronized (initializationLock) {
            if (flutterChannel != null) {
                return;
            }
            this.context = applicationContext;
            flutterChannel = new MethodChannel(messenger, CHANNEL);
            flutterChannel.setMethodCallHandler(this);
            dbHelper = TaskDbHelper.getInstance(context);
            taskDao = new TaskDao(dbHelper);
        }
    }

    @Override
    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        if (call.method.equals("initialize")) {
            initialize(call, result);
        } else if (call.method.equals("registerCallback"))  {
            registerCallback(call, result);
        } else if (call.method.equals("enqueue")) {
            enqueue(call, result);
        } else if (call.method.equals("loadTasks")) {
            loadTasks(call, result);
        } else if (call.method.equals("loadTasksWithRawQuery")) {
            loadTasksWithRawQuery(call, result);
        } else if (call.method.equals("cancel")) {
            cancel(call, result);
        } else if (call.method.equals("cancelAll")) {
            cancelAll(call, result);
        } else if (call.method.equals("pause")) {
            pause(call, result);
        } else if (call.method.equals("resume")) {
            resume(call, result);
        } else if (call.method.equals("retry")) {
            retry(call, result);
        } else if (call.method.equals("open")) {
            open(call, result);
        } else if (call.method.equals("remove")) {
            remove(call, result);
        } else {
            result.notImplemented();
        }
    }

    @Override
    public void onAttachedToEngine(FlutterPluginBinding binding) {
        onAttachedToEngine(binding.getApplicationContext(), binding.getBinaryMessenger());
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        context = null;
        if (flutterChannel != null) {
            flutterChannel.setMethodCallHandler(null);
            flutterChannel = null;
        }
    }

    private WorkRequest buildRequest(String url, String savedDir, String title, String filename, String headers, boolean showNotification, boolean openFileFromNotification, boolean isResume, boolean requiresStorageNotLow) {
        WorkRequest request = new OneTimeWorkRequest.Builder(DownloadWorker.class)
                .setConstraints(new Constraints.Builder()
                        .setRequiresStorageNotLow(requiresStorageNotLow)
                        .setRequiredNetworkType(NetworkType.CONNECTED)
                        .build())
                .addTag(TAG)
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 5, TimeUnit.SECONDS)
                .setInputData(new Data.Builder()
                        .putString(DownloadWorker.ARG_TITLE, title)
                        .putString(DownloadWorker.ARG_URL, url)
                        .putString(DownloadWorker.ARG_SAVED_DIR, savedDir)
                        .putString(DownloadWorker.ARG_FILE_NAME, filename)
                        .putString(DownloadWorker.ARG_HEADERS, headers)
                        .putBoolean(DownloadWorker.ARG_SHOW_NOTIFICATION, showNotification)
                        .putBoolean(DownloadWorker.ARG_OPEN_FILE_FROM_NOTIFICATION, openFileFromNotification)
                        .putBoolean(DownloadWorker.ARG_IS_RESUME, isResume)
                        .putLong(DownloadWorker.ARG_CALLBACK_HANDLE, callbackHandle)
                        .putBoolean(DownloadWorker.ARG_DEBUG, debugMode == 1)
                        .build()
                )
                .build();
        return request;
    }

    private void sendUpdateProgress(String id, int status, int progress) {
        Map<String, Object> args = new HashMap<>();
        args.put("task_id", id);
        args.put("status", status);
        args.put("progress", progress);
        flutterChannel.invokeMethod("updateProgress", args);
    }

    private void initialize(MethodCall call, MethodChannel.Result result) {
        List args = (List) call.arguments;
        long callbackHandle = Long.parseLong(args.get(0).toString());
        debugMode = Integer.parseInt(args.get(1).toString());

        SharedPreferences pref = context.getSharedPreferences(SHARED_PREFERENCES_KEY, Context.MODE_PRIVATE);
        pref.edit().putLong(CALLBACK_DISPATCHER_HANDLE_KEY, callbackHandle).apply();

        result.success(null);
    }

    private void registerCallback(MethodCall call, MethodChannel.Result result) {
        List args = (List) call.arguments;
        callbackHandle = Long.parseLong(args.get(0).toString());
        result.success(null);
    }

    private void enqueue(MethodCall call, MethodChannel.Result result) {
        String title = call.argument("title");
        String url = call.argument("url");
        String savedDir = call.argument("saved_dir");
        String filename = call.argument("file_name");
        String headers = call.argument("headers");
        boolean showNotification = call.argument("show_notification");
        boolean openFileFromNotification = call.argument("open_file_from_notification");
        boolean requiresStorageNotLow = call.argument("requires_storage_not_low");
        WorkRequest request = buildRequest(url, savedDir, title, filename, headers, showNotification, openFileFromNotification, false, requiresStorageNotLow);
        WorkManager.getInstance(context).enqueue(request);
        String taskId = request.getId().toString();
        result.success(taskId);
        sendUpdateProgress(taskId, DownloadStatus.ENQUEUED, 0);
        taskDao.insertOrUpdateNewTask(taskId, title, url, DownloadStatus.ENQUEUED, 0, filename, savedDir, headers, showNotification, openFileFromNotification);
    }

    private void loadTasks(MethodCall call, MethodChannel.Result result) {
        List<DownloadTask> tasks = taskDao.loadAllTasks();
        List<Map> array = new ArrayList<>();
        for (DownloadTask task : tasks) {
            Map<String, Object> item = new HashMap<>();
            item.put("task_id", task.taskId);
            item.put("status", task.status);
            item.put("progress", task.progress);
            item.put("title", task.title);
            item.put("url", task.url);
            item.put("file_name", task.filename);
            item.put("saved_dir", task.savedDir);
            item.put("time_created", task.timeCreated);
            array.add(item);
        }
        result.success(array);
    }

    private void loadTasksWithRawQuery(MethodCall call, MethodChannel.Result result) {
        String query = call.argument("query");
        List<DownloadTask> tasks = taskDao.loadTasksWithRawQuery(query);
        List<Map> array = new ArrayList<>();
        for (DownloadTask task : tasks) {
            Map<String, Object> item = new HashMap<>();
            item.put("task_id", task.taskId);
            item.put("status", task.status);
            item.put("progress", task.progress);
            item.put("title", task.title);
            item.put("url", task.url);
            item.put("file_name", task.filename);
            item.put("saved_dir", task.savedDir);
            item.put("time_created", task.timeCreated);
            array.add(item);
        }
        result.success(array);
    }

    private void cancel(MethodCall call, MethodChannel.Result result) {
        String taskId = call.argument("task_id");
        WorkManager.getInstance(context).cancelWorkById(UUID.fromString(taskId));
        result.success(null);
    }

    private void cancelAll(MethodCall call, MethodChannel.Result result) {
        WorkManager.getInstance(context).cancelAllWorkByTag(TAG);
        result.success(null);
    }

    private void pause(MethodCall call, MethodChannel.Result result) {
        String taskId = call.argument("task_id");
        taskDao.updateTask(taskId, true);
        WorkManager.getInstance(context).cancelWorkById(UUID.fromString(taskId));
        result.success(null);
    }

    private void resume(MethodCall call, MethodChannel.Result result) {
        String taskId = call.argument("task_id");
        DownloadTask task = taskDao.loadTask(taskId);
        boolean requiresStorageNotLow = call.argument("requires_storage_not_low");
        if (task != null) {
            if (task.status == DownloadStatus.PAUSED) {
                String filename = task.filename;
                if (filename == null) {
                    filename = task.url.substring(task.url.lastIndexOf("/") + 1, task.url.length());
                }
                String partialFilePath = task.savedDir + File.separator + filename;
                File partialFile = new File(partialFilePath);
                if (partialFile.exists()) {
                    WorkRequest request = buildRequest(task.url, task.savedDir, task.title, task.filename, task.headers, task.showNotification, task.openFileFromNotification, true, requiresStorageNotLow);
                    String newTaskId = request.getId().toString();
                    result.success(newTaskId);
                    sendUpdateProgress(newTaskId, DownloadStatus.RUNNING, task.progress);
                    taskDao.updateTask(taskId, newTaskId, DownloadStatus.RUNNING, task.progress, false);
                    WorkManager.getInstance(context).enqueue(request);
                } else {
                    result.error("invalid_data", "not found partial downloaded data, this task cannot be resumed", null);
                }
            } else {
                result.error("invalid_status", "only paused task can be resumed", null);
            }
        } else {
            result.error("invalid_task_id", "not found task corresponding to given task id", null);
        }
    }

    private void retry(MethodCall call, MethodChannel.Result result) {
        String taskId = call.argument("task_id");
        DownloadTask task = taskDao.loadTask(taskId);
        boolean requiresStorageNotLow = call.argument("requires_storage_not_low");
        if (task != null) {
            if (task.status == DownloadStatus.FAILED || task.status == DownloadStatus.CANCELED) {
                WorkRequest request = buildRequest(task.url, task.savedDir, task.title, task.filename, task.headers, task.showNotification, task.openFileFromNotification, false, requiresStorageNotLow);
                String newTaskId = request.getId().toString();
                result.success(newTaskId);
                sendUpdateProgress(newTaskId, DownloadStatus.ENQUEUED, task.progress);
                taskDao.updateTask(taskId, newTaskId, DownloadStatus.ENQUEUED, task.progress, false);
                WorkManager.getInstance(context).enqueue(request);
            } else {
                result.error("invalid_status", "only failed and canceled task can be retried", null);
            }
        } else {
            result.error("invalid_task_id", "not found task corresponding to given task id", null);
        }
    }

    private void open(MethodCall call, MethodChannel.Result result) {
        String taskId = call.argument("task_id");
        DownloadTask task = taskDao.loadTask(taskId);
        if (task != null) {
            if (task.status == DownloadStatus.COMPLETE) {
                String fileURL = task.url;
                String savedDir = task.savedDir;
                String filename = task.filename;
                if (filename == null) {
                    filename = fileURL.substring(fileURL.lastIndexOf("/") + 1, fileURL.length());
                }
                String saveFilePath = savedDir + File.separator + filename;
                Intent intent = IntentUtils.validatedFileIntent(context, saveFilePath, task.mimeType);
                if (intent != null) {
                    context.startActivity(intent);
                    result.success(true);
                } else {
                    result.success(false);
                }
            } else {
                result.error("invalid_status", "only success task can be opened", null);
            }
        } else {
            result.error("invalid_task_id", "not found task corresponding to given task id", null);
        }
    }

    private void remove(MethodCall call, MethodChannel.Result result) {
        String taskId = call.argument("task_id");
        boolean shouldDeleteContent = call.argument("should_delete_content");
        DownloadTask task = taskDao.loadTask(taskId);
        if (task != null) {
            if (task.status == DownloadStatus.ENQUEUED || task.status == DownloadStatus.RUNNING) {
                WorkManager.getInstance(context).cancelWorkById(UUID.fromString(taskId));
            }
            if (shouldDeleteContent) {
                String filename = task.filename;
                if (filename == null) {
                    filename = task.url.substring(task.url.lastIndexOf("/") + 1, task.url.length());
                }

                String saveFilePath = task.savedDir + File.separator + filename;
                File tempFile = new File(saveFilePath);
                if (tempFile.exists()) {
                    tempFile.delete();
                }
            }
            taskDao.deleteTask(taskId);

            NotificationManagerCompat.from(context).cancel(task.primaryId);

            result.success(null);
        } else {
            result.error("invalid_task_id", "not found task corresponding to given task id", null);
        }
    }
}
