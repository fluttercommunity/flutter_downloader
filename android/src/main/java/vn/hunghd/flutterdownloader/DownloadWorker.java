package vn.hunghd.flutterdownloader;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.ContentValues;
import android.content.Context;
import android.content.Intent;
import android.database.sqlite.SQLiteDatabase;
import android.os.Build;
import android.support.annotation.NonNull;
import android.support.v4.app.NotificationCompat;
import android.support.v4.app.NotificationManagerCompat;
import android.support.v4.content.LocalBroadcastManager;
import android.text.TextUtils;
import android.util.Log;

import org.json.JSONException;
import org.json.JSONObject;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.Iterator;
import java.util.Map;

import androidx.work.Worker;
import vn.hunghd.flutterdownloader.TaskContract.TaskEntry;

public class DownloadWorker extends Worker {
    public static final String UPDATE_PROCESS_EVENT = "vn.hunghd.flutterdownloader.UPDATE_PROCESS_EVENT";

    public static final String ARG_URL = "url";
    public static final String ARG_FILE_NAME = "file_name";
    public static final String ARG_SAVED_DIR = "saved_file";
    public static final String ARG_HEADERS = "headers";
    public static final String ARG_SHOW_NOTIFICATION = "show_notification";

    public static final String EXTRA_ID = "id";
    public static final String EXTRA_PROGRESS = "progress";
    public static final String EXTRA_STATUS = "status";

    private static final String TAG = DownloadWorker.class.getSimpleName();
    private static final int BUFFER_SIZE = 4096;
    private static final String CHANNEL_ID = "FLUTTER_DOWNLOADER_NOTIFICATION";
    private static final int STEP_UPDATE = 10;

    private TaskDbHelper dbHelper;
    private NotificationCompat.Builder builder;
    private boolean showNotification;
    private int lastProgress = 0;

    @NonNull
    @Override
    public WorkerResult doWork() {
        Context context = getApplicationContext();
        dbHelper = new TaskDbHelper(context);

        String url = getInputData().getString(ARG_URL, null);
        String fileName = getInputData().getString(ARG_FILE_NAME, null);
        String savedDir = getInputData().getString(ARG_SAVED_DIR, null);
        String headers = getInputData().getString(ARG_HEADERS, null);
        if (url == null || savedDir == null)
            throw new IllegalArgumentException("url and saved_dir must be not null");

        showNotification = getInputData().getBoolean(ARG_SHOW_NOTIFICATION, false);

        buildNotification(context);

        updateNotification(context, fileName == null ? url : fileName, 0);
        updateTask(getId(), url, DownloadStatus.RUNNING, 0, fileName, savedDir);
        try {
            downloadFile(context, url, savedDir, fileName, headers);
            return WorkerResult.SUCCESS;
        } catch (IOException e) {
            updateNotification(context, fileName == null ? url : fileName, -1);
            updateTask(getId(), url, DownloadStatus.FAILED, lastProgress, fileName, savedDir);
            e.printStackTrace();
            return WorkerResult.FAILURE;
        }
    }

    private void downloadFile(Context context, String fileURL, String saveDir, String fileName, String headers)
            throws IOException {

        URL url = new URL(fileURL);
        HttpURLConnection httpConn = (HttpURLConnection) url.openConnection();
        if (!TextUtils.isEmpty(headers)) {
            Log.d(TAG, "Headers = " + headers);
            try {
                JSONObject json = new JSONObject(headers);
                for (Iterator<String> it = json.keys(); it.hasNext(); ) {
                    String key = it.next();
                    httpConn.setRequestProperty(key, json.getString(key));
                }
                httpConn.setDoInput(true);
                httpConn.setDoOutput(true);
            } catch (JSONException e) {
                e.printStackTrace();
            }
        }

        int responseCode = httpConn.getResponseCode();

        // always check HTTP response code first
        if (responseCode == HttpURLConnection.HTTP_OK && !isStopped()) {
            String contentType = httpConn.getContentType();
            int contentLength = httpConn.getContentLength();

            if (fileName == null) {
                fileName = fileURL.substring(fileURL.lastIndexOf("/") + 1, fileURL.length());
            }

            Log.d(TAG, "Content-Type = " + contentType);
            Log.d(TAG, "Content-Length = " + contentLength);
            Log.d(TAG, "fileName = " + fileName);

            // opens input stream from the HTTP connection
            InputStream inputStream = httpConn.getInputStream();
            String saveFilePath = saveDir + File.separator + fileName;

            // opens an output stream to save into file
            FileOutputStream outputStream = new FileOutputStream(saveFilePath);

            long count = 0;
            int bytesRead = -1;
            byte[] buffer = new byte[BUFFER_SIZE];
            while ((bytesRead = inputStream.read(buffer)) != -1 && !isStopped()) {
                count += bytesRead;
                int progress = (int) ((count * 100) / contentLength);
                outputStream.write(buffer, 0, bytesRead);

                if ((lastProgress == 0 || progress > lastProgress + STEP_UPDATE || progress == 100)
                        && progress != lastProgress) {
                    lastProgress = progress;
                    updateNotification(context, fileName, progress);
                    updateTask(getId(), fileURL, DownloadStatus.RUNNING, progress, fileName, saveDir);
                }
            }

            outputStream.close();
            inputStream.close();

            int progress = isStopped() ? -1 : 100;
            int status = isStopped() ? DownloadStatus.CANCELED : DownloadStatus.COMPLETE;
            updateNotification(context, fileName, progress);
            updateTask(getId(), fileURL, status, progress, fileName, saveDir);

            Log.d(TAG, isStopped() ? "Download canceled" : "File downloaded");
        } else {
            int status = isStopped() ? DownloadStatus.CANCELED : DownloadStatus.FAILED;
            updateNotification(context, fileName, -1);
            updateTask(getId(), fileURL, status, lastProgress, fileName, saveDir);
            Log.d(TAG, isStopped() ? "Download canceled" : "No file to download. Server replied HTTP code: " + responseCode);
        }
        httpConn.disconnect();
    }

    private void buildNotification(Context context) {
        // Make a channel if necessary
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Create the NotificationChannel, but only on API 26+ because
            // the NotificationChannel class is new and not in the support library
            int importance = NotificationManager.IMPORTANCE_HIGH;
            NotificationChannel channel = new NotificationChannel(CHANNEL_ID, "", importance);

            // Add the channel
            NotificationManager notificationManager =
                    (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);

            if (notificationManager != null) {
                notificationManager.createNotificationChannel(channel);
            }
        }

        // Create the notification
        builder = new NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_download)
                .setPriority(NotificationCompat.PRIORITY_HIGH);
    }

    private void updateNotification(Context context, String title, int progress) {
        builder.setContentTitle(title);

        int status;

        if (progress > 0 && progress < 100) {
            status = DownloadStatus.RUNNING;
            builder.setContentText("Download in progress")
                    .setProgress(100, progress, false);
        } else if (progress == 0) {
            status = DownloadStatus.RUNNING;
            builder.setContentText("Download started")
                    .setProgress(0, 0, true);
        } else if (progress < 0) {
            status = isStopped() ? DownloadStatus.CANCELED : DownloadStatus.FAILED;
            String message = isStopped() ? "Download canceled" : "Download failed";
            builder.setContentText(message)
                    .setProgress(0, 0, false);
        } else {
            status = DownloadStatus.COMPLETE;
            builder.setContentText("Download complete")
                    .setProgress(0, 0, false);
        }

        // Show the notification
        if (showNotification) {
            NotificationManagerCompat.from(context).notify(getId().hashCode(), builder.build());
        }

        sendUpdateProcessEvent(context, status, progress);
    }

    private void sendUpdateProcessEvent(Context context, int status, int progress) {
        Intent intent = new Intent(UPDATE_PROCESS_EVENT);
        intent.putExtra(EXTRA_ID, getId());
        intent.putExtra(EXTRA_STATUS, status);
        intent.putExtra(EXTRA_PROGRESS, progress);
        LocalBroadcastManager.getInstance(context).sendBroadcast(intent);
    }

    private void updateTask(String taskId, String url,
                            int status, int progress, String fileName, String savedDir) {
        SQLiteDatabase db = dbHelper.getWritableDatabase();

        ContentValues values = buildContentValues(taskId, url, status, progress, fileName, savedDir);

        db.update(TaskEntry.TABLE_NAME, values, TaskEntry.COLUMN_NAME_TASK_ID + " = ?", new String[]{taskId});
    }

    private ContentValues buildContentValues(String taskId, String url, int status,
                                             int progress, String fileName, String savedDir) {
        ContentValues values = new ContentValues();
        values.put(TaskEntry.COLUMN_NAME_TASK_ID, taskId);
        values.put(TaskEntry.COLUMN_NAME_URL, url);
        values.put(TaskEntry.COLUMN_NAME_STATUS, status);
        values.put(TaskEntry.COLUMN_NAME_PROGRESS, progress);
        values.put(TaskEntry.COLUMN_NAME_FILE_NAME, fileName);
        values.put(TaskEntry.COLUMN_NAME_SAVED_DIR, savedDir);
        return values;
    }
}
