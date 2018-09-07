package vn.hunghd.flutterdownloader;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.app.Application;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Bundle;
import android.support.v4.content.LocalBroadcastManager;
import android.util.Log;


import java.io.File;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.Executors;
import java.util.concurrent.LinkedBlockingDeque;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;

import androidx.work.BackoffPolicy;
import androidx.work.Configuration;
import androidx.work.Constraints;
import androidx.work.Data;
import androidx.work.NetworkType;
import androidx.work.OneTimeWorkRequest;
import androidx.work.WorkManager;
import androidx.work.WorkRequest;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.PluginRegistry;

public class FlutterDownloaderPlugin implements MethodCallHandler {
    private static final String CHANNEL = "vn.hunghd/downloader";
    private static final String TAG = "flutter_download_task";

    private MethodChannel flutterChannel;
    private TaskDbHelper dbHelper;
    private TaskDao taskDao;
    private boolean initialized = false;
    private Map<String, String> messages;
    private Context context;

    private final BroadcastReceiver updateProcessEventReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            String id = intent.getStringExtra(DownloadWorker.EXTRA_ID);
            int progress = intent.getIntExtra(DownloadWorker.EXTRA_PROGRESS, 0);
            int status = intent.getIntExtra(DownloadWorker.EXTRA_STATUS, DownloadStatus.UNDEFINED);
            sendUpdateProgress(id, status, progress);
        }
    };

    private FlutterDownloaderPlugin(Context context, BinaryMessenger messenger) {
        this.context = context;
        flutterChannel = new MethodChannel(messenger, CHANNEL);
        flutterChannel.setMethodCallHandler(this);
        dbHelper = TaskDbHelper.getInstance(context);
        taskDao = new TaskDao(dbHelper);
    }

    @SuppressLint("NewApi")
    public static void registerWith(PluginRegistry.Registrar registrar) {
        final FlutterDownloaderPlugin plugin = new FlutterDownloaderPlugin(registrar.context(), registrar.messenger());
        registrar.activity().getApplication()
                .registerActivityLifecycleCallbacks(new Application.ActivityLifecycleCallbacks() {
                    @Override
                    public void onActivityCreated(Activity activity, Bundle bundle) {

                    }

                    @Override
                    public void onActivityStarted(Activity activity) {
                        plugin.onStart(activity);
                    }

                    @Override
                    public void onActivityResumed(Activity activity) {

                    }

                    @Override
                    public void onActivityPaused(Activity activity) {

                    }

                    @Override
                    public void onActivityStopped(Activity activity) {
                        plugin.onStop(activity);
                    }

                    @Override
                    public void onActivitySaveInstanceState(Activity activity, Bundle bundle) {

                    }

                    @Override
                    public void onActivityDestroyed(Activity activity) {

                    }
                });
    }

    @Override
    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        if (call.method.equals("initialize") && !initialized) {
            int maximumConcurrentTask = call.argument("max_concurrent_tasks");
            messages = call.argument("messages");

            WorkManager.initialize(context, new Configuration.Builder()
                    .setExecutor(Executors.newFixedThreadPool(maximumConcurrentTask))
                    .build());

            initialized = true;
        } else if (call.method.equals("enqueue")) {
            if (initialized) {
                String url = call.argument("url");
                String savedDir = call.argument("saved_dir");
                String filename = call.argument("file_name");
                String headers = call.argument("headers");
                boolean showNotification = call.argument("show_notification");
                boolean clickToOpenDownloadedFile = call.argument("click_to_open_downloaded_file");
                WorkRequest request = buildRequest(url, savedDir, filename, headers, showNotification, clickToOpenDownloadedFile, false);
                WorkManager.getInstance().enqueue(request);
                String taskId = request.getId().toString();
                result.success(taskId);
                sendUpdateProgress(taskId, DownloadStatus.ENQUEUED, 0);
                taskDao.insertOrUpdateNewTask(taskId, url, DownloadStatus.ENQUEUED, 0, filename, savedDir, headers, showNotification, clickToOpenDownloadedFile);
            } else {
                result.error("not_initialized", "initialize() must be called first", null);
            }
        } else if (call.method.equals("loadTasks")) {
            if (initialized) {
                List<DownloadTask> tasks = taskDao.loadAllTasks();
                List<Map> array = new ArrayList<>();
                for (DownloadTask task : tasks) {
                    Map<String, Object> item = new HashMap<>();
                    item.put("task_id", task.taskId);
                    item.put("status", task.status);
                    item.put("progress", task.progress);
                    item.put("url", task.url);
                    item.put("file_name", task.filename);
                    item.put("saved_dir", task.savedDir);
                    array.add(item);
                }
                result.success(array);
            } else {
                result.error("not_initialized", "initialize() must be called first", null);
            }
        } else if (call.method.equals("cancel")) {
            if (initialized) {
                String taskId = call.argument("task_id");
                cancel(taskId);
                result.success(null);
            } else {
                result.error("not_initialized", "initialize() must be called first", null);
            }
        } else if (call.method.equals("cancelAll")) {
            if (initialized) {
                cancelAll();
                result.success(null);
            } else {
                result.error("not_initialized", "initialize() must be called first", null);
            }
        } else if (call.method.equals("pause")) {
            if (initialized) {
                String taskId = call.argument("task_id");
                pause(taskId);
                result.success(null);
            } else {
                result.error("not_initialized", "initialize() must be called first", null);
            }
        } else if (call.method.equals("resume")) {
            if (initialized) {
                String taskId = call.argument("task_id");
                String newTaskId = resume(taskId);
                result.success(newTaskId);
            } else {
                result.error("not_initialized", "initialize() must be called first", null);
            }
        } else {
            result.notImplemented();
        }
    }

    private void onStart(Context context) {
        LocalBroadcastManager.getInstance(context)
                .registerReceiver(updateProcessEventReceiver,
                        new IntentFilter(DownloadWorker.UPDATE_PROCESS_EVENT));
    }

    private void onStop(Context context) {
        LocalBroadcastManager.getInstance(context)
                .unregisterReceiver(updateProcessEventReceiver);
    }

    private WorkRequest buildRequest(String url, String savedDir, String filename, String headers, boolean showNotification, boolean clickToOpenDownloadedFile, boolean isResume) {
        WorkRequest request = new OneTimeWorkRequest.Builder(DownloadWorker.class)
//                .setConstraints(new Constraints.Builder()
//                        .setRequiresStorageNotLow(true)
//                        .setRequiredNetworkType(NetworkType.CONNECTED)
//                        .build())
                .addTag(TAG)
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 5, TimeUnit.SECONDS)
                .setInputData(new Data.Builder()
                        .putString(DownloadWorker.ARG_URL, url)
                        .putString(DownloadWorker.ARG_SAVED_DIR, savedDir)
                        .putString(DownloadWorker.ARG_FILE_NAME, filename)
                        .putString(DownloadWorker.ARG_HEADERS, headers)
                        .putBoolean(DownloadWorker.ARG_SHOW_NOTIFICATION, showNotification)
                        .putBoolean(DownloadWorker.ARG_CLICK_TO_OPEN_DOWNLOADED_FILE, clickToOpenDownloadedFile)
                        .putBoolean(DownloadWorker.ARG_IS_RESUME, isResume)
                        .putString(DownloadWorker.MSG_STARTED, messages.get("started"))
                        .putString(DownloadWorker.MSG_IN_PROGRESS, messages.get("in_progress"))
                        .putString(DownloadWorker.MSG_CANCELED, messages.get("canceled"))
                        .putString(DownloadWorker.MSG_FAILED, messages.get("failed"))
                        .putString(DownloadWorker.MSG_PAUSED, messages.get("paused"))
                        .putString(DownloadWorker.MSG_COMPLETE, messages.get("complete"))
                        .build()
                )
                .build();
        return request;
    }

    private void cancel(String taskId) {
        WorkManager.getInstance().cancelWorkById(UUID.fromString(taskId));
    }

    private void cancelAll() {
        WorkManager.getInstance().cancelAllWorkByTag(TAG);
    }

    private void pause(String taskId) {
        taskDao.updateTask(taskId, true);
        WorkManager.getInstance().cancelWorkById(UUID.fromString(taskId));
    }

    private String resume(String taskId) {
        DownloadTask task = taskDao.loadTask(taskId);
        String filename = task.filename;
        if (filename == null) {
            filename = task.url.substring(task.url.lastIndexOf("/") + 1, task.url.length());
        }
        String partialFilePath = task.savedDir + File.separator + filename;
        File partialFile = new File(partialFilePath);
        if (partialFile.exists()) {
            WorkRequest request = buildRequest(task.url, task.savedDir, task.filename, task.headers, task.showNotification, task.clickToOpenDownloadedFile, true);
            String newTaskId = request.getId().toString();
            sendUpdateProgress(newTaskId, DownloadStatus.RUNNING, task.progress);
            taskDao.updateTask(taskId, newTaskId, DownloadStatus.RUNNING, task.progress, false);
            WorkManager.getInstance().enqueue(request);
            return newTaskId;
        }
        return null;
    }

    private void sendUpdateProgress(String id, int status, int progress) {
        Map<String, Object> args = new HashMap<>();
        args.put("task_id", id);
        args.put("status", status);
        args.put("progress", progress);
        flutterChannel.invokeMethod("updateProgress", args);
    }
}
