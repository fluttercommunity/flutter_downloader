package vn.hunghd.flutterdownloader;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.app.Application;
import android.content.BroadcastReceiver;
import android.content.ContentValues;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.os.Bundle;
import android.provider.BaseColumns;
import android.support.v4.content.LocalBroadcastManager;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

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
import io.flutter.view.FlutterNativeView;

public class FlutterDownloaderPlugin implements MethodCallHandler {
    private static final String CHANNEL = "vn.hunghd/downloader";
    private static final String TAG = "flutter_download_task";

    private MethodChannel flutterChannel;
    private TaskDbHelper dbHelper;

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
        flutterChannel = new MethodChannel(messenger, CHANNEL);
        flutterChannel.setMethodCallHandler(this);
        dbHelper = new TaskDbHelper(context);
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
        if (call.method.equals("enqueue")) {
            String url = call.argument("url");
            String savedDir = call.argument("saved_dir");
            String fileName = call.argument("file_name");
            boolean showNotification = call.argument("show_notification");
            WorkRequest request = new OneTimeWorkRequest.Builder(DownloadWorker.class)
                    .setConstraints(new Constraints.Builder()
                            .setRequiredNetworkType(NetworkType.CONNECTED)
                            .build())
                    .addTag(TAG)
                    .setInputData(new Data.Builder()
                            .putString(DownloadWorker.ARG_URL, url)
                            .putString(DownloadWorker.ARG_SAVED_DIR, savedDir)
                            .putString(DownloadWorker.ARG_FILE_NAME, fileName)
                            .putBoolean(DownloadWorker.ARG_SHOW_NOTIFICATION, showNotification)
                            .build()
                    )
                    .build();
            WorkManager.getInstance().enqueue(request);
            String taskId = request.getId().toString();
            sendUpdateProgress(taskId, DownloadStatus.ENQUEUED, 0);
            insertOrUpdateNewTask(taskId, url, DownloadStatus.ENQUEUED, 0, fileName, savedDir);
            result.success(taskId);
        } else if (call.method.equals("loadTasks")) {
            List<String> ids = call.argument("ids");
            List<DownloadTask> tasks = loadTask(ids);
            List<Map> array = new ArrayList<>();
            for (DownloadTask task : tasks) {
                Map<String, Object> item = new HashMap<>();
                item.put("task_id", task.taskId);
                item.put("status", task.status);
                item.put("progress", task.progress);
                array.add(item);
            }
            result.success(array);
        } else if (call.method.equals("cancel")) {
            String taskId = call.argument("task_id");
            cancel(taskId);
        } else if (call.method.equals("cancelAll")) {
            cancelAll();
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

    private void cancel(String taskId) {
        WorkManager.getInstance().cancelWorkById(UUID.fromString(taskId));
    }

    private void cancelAll() {
        WorkManager.getInstance().cancelAllWorkByTag(TAG);
    }

    private void sendUpdateProgress(String id, int status, int progress) {
        Map<String, Object> args = new HashMap<>();
        args.put("task_id", id);
        args.put("status", status);
        args.put("progress", progress);
        flutterChannel.invokeMethod("updateProgress", args);
    }

    private void insertOrUpdateNewTask(String taskId, String url,
                                       int status, int progress, String fileName, String savedDir) {
        SQLiteDatabase db = dbHelper.getWritableDatabase();

        ContentValues values = new ContentValues();
        values.put(TaskContract.TaskEntry.COLUMN_NAME_TASK_ID, taskId);
        values.put(TaskContract.TaskEntry.COLUMN_NAME_URL, url);
        values.put(TaskContract.TaskEntry.COLUMN_NAME_STATUS, status);
        values.put(TaskContract.TaskEntry.COLUMN_NAME_PROGRESS, progress);
        values.put(TaskContract.TaskEntry.COLUMN_NAME_FILE_NAME, fileName);
        values.put(TaskContract.TaskEntry.COLUMN_NAME_SAVED_DIR, savedDir);

        db.insertWithOnConflict(TaskContract.TaskEntry.TABLE_NAME, null, values, SQLiteDatabase.CONFLICT_REPLACE);
    }

    private List<DownloadTask> loadTask(List<String> taskIds) {
        SQLiteDatabase db = dbHelper.getReadableDatabase();

        StringBuilder builder = new StringBuilder();
        for (int i = 0; i < taskIds.size(); i++) {
            builder.append("\'").append(taskIds.get(i)).append("\'");
            if (i < taskIds.size() - 1) builder.append(",");
        }
        String[] projection = new String[]{
                BaseColumns._ID,
                TaskContract.TaskEntry.COLUMN_NAME_TASK_ID,
                TaskContract.TaskEntry.COLUMN_NAME_PROGRESS,
                TaskContract.TaskEntry.COLUMN_NAME_STATUS
        };
        String selection = TaskContract.TaskEntry.COLUMN_NAME_TASK_ID + " IN (" + builder.toString() + ")";

        Cursor cursor = db.query(
                TaskContract.TaskEntry.TABLE_NAME,
                projection,
                selection,
                null,
                null,
                null,
                null
        );

        List<DownloadTask> result = new ArrayList<>();
        while (cursor.moveToNext()) {
            String taskId = cursor.getString(cursor.getColumnIndexOrThrow(TaskContract.TaskEntry.COLUMN_NAME_TASK_ID));
            int status = cursor.getInt(cursor.getColumnIndexOrThrow(TaskContract.TaskEntry.COLUMN_NAME_STATUS));
            int progress = cursor.getInt(cursor.getColumnIndexOrThrow(TaskContract.TaskEntry.COLUMN_NAME_PROGRESS));
            result.add(new DownloadTask(taskId, status, progress));
        }
        cursor.close();
        return result;
    }

    private class DownloadTask {
        String taskId;
        int status;
        int progress;

        DownloadTask(String taskId, int status, int progress) {
            this.taskId = taskId;
            this.status = status;
            this.progress = progress;
        }
    }
}
