package vn.hunghd.flutterdownloader;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.res.Resources;
import android.graphics.BitmapFactory;
import android.os.Build;

import androidx.annotation.NonNull;
import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;
import androidx.core.content.ContextCompat;
import androidx.localbroadcastmanager.content.LocalBroadcastManager;

import android.text.TextUtils;
import android.util.Log;

import org.json.JSONException;
import org.json.JSONObject;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.MalformedURLException;
import java.net.URL;
import java.net.URLDecoder;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;

import androidx.work.Worker;
import androidx.work.WorkerParameters;

public class DownloadWorker extends Worker {
    public static final String UPDATE_PROCESS_EVENT = "vn.hunghd.flutterdownloader.UPDATE_PROCESS_EVENT";

    public static final String ARG_URL = "url";
    public static final String ARG_FILE_NAME = "file_name";
    public static final String ARG_SAVED_DIR = "saved_file";
    public static final String ARG_HEADERS = "headers";
    public static final String ARG_IS_RESUME = "is_resume";
    public static final String ARG_SHOW_NOTIFICATION = "show_notification";
    public static final String ARG_OPEN_FILE_FROM_NOTIFICATION = "open_file_from_notification";

    public static final String EXTRA_ID = "id";
    public static final String EXTRA_PROGRESS = "progress";
    public static final String EXTRA_STATUS = "status";

    private static final String TAG = DownloadWorker.class.getSimpleName();
    private static final int BUFFER_SIZE = 4096;
    private static final String CHANNEL_ID = "FLUTTER_DOWNLOADER_NOTIFICATION";
    private static final int STEP_UPDATE = 10;

    private TaskDbHelper dbHelper;
    private TaskDao taskDao;
    private NotificationCompat.Builder builder;
    private boolean showNotification;
    private boolean clickToOpenDownloadedFile;
    private int lastProgress = 0;
    private int primaryId;
    private String msgStarted, msgInProgress, msgCanceled, msgFailed, msgPaused, msgComplete;

    public DownloadWorker(@NonNull Context context,
                          @NonNull WorkerParameters params) {
        super(context, params);
    }

    @NonNull
    @Override
    public Result doWork() {
        Context context = getApplicationContext();
        dbHelper = TaskDbHelper.getInstance(context);
        taskDao = new TaskDao(dbHelper);

        String url = getInputData().getString(ARG_URL);
        String filename = getInputData().getString(ARG_FILE_NAME);
        String savedDir = getInputData().getString(ARG_SAVED_DIR);
        String headers = getInputData().getString(ARG_HEADERS);
        boolean isResume = getInputData().getBoolean(ARG_IS_RESUME, false);

        Resources res = getApplicationContext().getResources();
        msgStarted = res.getString(R.string.flutter_downloader_notification_started);
        msgInProgress = res.getString(R.string.flutter_downloader_notification_in_progress);
        msgCanceled = res.getString(R.string.flutter_downloader_notification_canceled);
        msgFailed = res.getString(R.string.flutter_downloader_notification_failed);
        msgPaused = res.getString(R.string.flutter_downloader_notification_paused);
        msgComplete = res.getString(R.string.flutter_downloader_notification_complete);

        Log.d(TAG, "DownloadWorker{url=" + url + ",filename=" + filename + ",savedDir=" + savedDir + ",header=" + headers + ",isResume=" + isResume);

        showNotification = getInputData().getBoolean(ARG_SHOW_NOTIFICATION, false);
        clickToOpenDownloadedFile = getInputData().getBoolean(ARG_OPEN_FILE_FROM_NOTIFICATION, false);

        DownloadTask task = taskDao.loadTask(getId().toString());
        primaryId = task.primaryId;

        buildNotification(context);

        updateNotification(context, filename == null ? url : filename, DownloadStatus.RUNNING, task.progress, null);
        taskDao.updateTask(getId().toString(), DownloadStatus.RUNNING, 0);

        try {
            downloadFile(context, url, savedDir, filename, headers, isResume);
            cleanUp();
            dbHelper = null;
            taskDao = null;
            return Result.success();
        } catch (Exception e) {
            updateNotification(context, filename == null ? url : filename, DownloadStatus.FAILED, -1, null);
            taskDao.updateTask(getId().toString(), DownloadStatus.FAILED, lastProgress);
            e.printStackTrace();
            dbHelper = null;
            taskDao = null;
            return Result.failure();
        }
    }

    private void setupHeaders(HttpURLConnection conn, String headers) {
        if (!TextUtils.isEmpty(headers)) {
            Log.d(TAG, "Headers = " + headers);
            try {
                JSONObject json = new JSONObject(headers);
                for (Iterator<String> it = json.keys(); it.hasNext(); ) {
                    String key = it.next();
                    conn.setRequestProperty(key, json.getString(key));
                }
                conn.setDoInput(true);
            } catch (JSONException e) {
                e.printStackTrace();
            }
        }
    }

    private long setupPartialDownloadedDataHeader(HttpURLConnection conn, String filename, String savedDir) {
        String saveFilePath = savedDir + File.separator + filename;
        File partialFile = new File(saveFilePath);
        long downloadedBytes = partialFile.length();
        Log.d(TAG, "Resume download: Range: bytes=" + downloadedBytes + "-");
        conn.setRequestProperty("Accept-Encoding", "identity");
        conn.setRequestProperty("Range", "bytes=" + downloadedBytes + "-");
        conn.setDoInput(true);
        return downloadedBytes;
    }

    private void downloadFile(Context context, String fileURL, String savedDir, String filename, String headers, boolean isResume) throws IOException {
        String url = fileURL;
        URL resourceUrl, base, next;
        Map<String, Integer> visited;
        HttpURLConnection httpConn = null;
        InputStream inputStream = null;
        FileOutputStream outputStream = null;
        String saveFilePath;
        String location;
        long downloadedBytes = 0;
        int responseCode;
        int times;

        visited = new HashMap<>();

        try {
            // handle redirection logic
            while (true) {
                if (!visited.containsKey(url)) {
                    times = 1;
                    visited.put(url, times);
                } else {
                    times = visited.get(url) + 1;
                }

                if (times > 3)
                    throw new IOException("Stuck in redirect loop");

                resourceUrl = new URL(url);
                Log.d(TAG, "Open connection to " + url);
                httpConn = (HttpURLConnection) resourceUrl.openConnection();

                httpConn.setConnectTimeout(15000);
                httpConn.setReadTimeout(15000);
                httpConn.setInstanceFollowRedirects(false);   // Make the logic below easier to detect redirections
                httpConn.setRequestProperty("User-Agent", "Mozilla/5.0...");

                // setup request headers if it is set
                setupHeaders(httpConn, headers);
                // try to continue downloading a file from its partial downloaded data.
                if (isResume) {
                    downloadedBytes = setupPartialDownloadedDataHeader(httpConn, filename, savedDir);
                }

                responseCode = httpConn.getResponseCode();
                switch (responseCode) {
                    case HttpURLConnection.HTTP_MOVED_PERM:
                    case HttpURLConnection.HTTP_MOVED_TEMP:
                        Log.d(TAG, "Response with redirection code");
                        location = httpConn.getHeaderField("Location");
                        location = URLDecoder.decode(location, "UTF-8");
                        base = new URL(fileURL);
                        next = new URL(base, location);  // Deal with relative URLs
                        url = next.toExternalForm();
                        Log.d(TAG, "New url: " + url);
                        continue;
                }

                break;
            }

            httpConn.connect();

            if ((responseCode == HttpURLConnection.HTTP_OK || (isResume && responseCode == HttpURLConnection.HTTP_PARTIAL)) && !isStopped()) {
                String contentType = httpConn.getContentType();
                int contentLength = httpConn.getContentLength();
                Log.d(TAG, "Content-Type = " + contentType);
                Log.d(TAG, "Content-Length = " + contentLength);

                if (!isResume) {
                    // try to extract filename from HTTP headers if it is not given by user
                    if (filename == null) {
                        String disposition = httpConn.getHeaderField("Content-Disposition");
                        Log.d(TAG, "Content-Disposition = " + disposition);
                        if (disposition != null && !disposition.isEmpty()) {
                            String name = disposition.replaceFirst("(?i)^.*filename=\"?([^\"]+)\"?.*$", "$1");
                            filename = URLDecoder.decode(name, "ISO-8859-1");
                        }
                        if (filename == null || filename.isEmpty()) {
                            filename = url.substring(url.lastIndexOf("/") + 1);
                        }
                    }
                }
                saveFilePath = savedDir + File.separator + filename;

                Log.d(TAG, "fileName = " + filename);

                taskDao.updateTask(getId().toString(), filename, contentType);

                // opens input stream from the HTTP connection
                inputStream = httpConn.getInputStream();

                // opens an output stream to save into file
                outputStream = new FileOutputStream(saveFilePath, isResume);

                long count = downloadedBytes;
                int bytesRead = -1;
                byte[] buffer = new byte[BUFFER_SIZE];
                while ((bytesRead = inputStream.read(buffer)) != -1 && !isStopped()) {
                    count += bytesRead;
                    int progress = (int) ((count * 100) / (contentLength + downloadedBytes));
                    outputStream.write(buffer, 0, bytesRead);

                    if ((lastProgress == 0 || progress > lastProgress + STEP_UPDATE || progress == 100)
                            && progress != lastProgress) {
                        lastProgress = progress;
                        updateNotification(context, filename, DownloadStatus.RUNNING, progress, null);

                        // This line possibly causes system overloaded because of accessing to DB too many ?!!!
                        // but commenting this line causes tasks loaded from DB missing current downloading progress,
                        // however, this missing data should be temporary and it will be updated as soon as
                        // a new bunch of data fetched and a notification sent
                        //taskDao.updateTask(getId().toString(), DownloadStatus.RUNNING, progress);
                    }
                }

                DownloadTask task = taskDao.loadTask(getId().toString());
                int progress = isStopped() && task.resumable ? lastProgress : 100;
                int status = isStopped() ? (task.resumable ? DownloadStatus.PAUSED : DownloadStatus.CANCELED) : DownloadStatus.COMPLETE;
                int storage = ContextCompat.checkSelfPermission(getApplicationContext(), android.Manifest.permission.WRITE_EXTERNAL_STORAGE);
                PendingIntent pendingIntent = null;
                if (status == DownloadStatus.COMPLETE && clickToOpenDownloadedFile && storage == PackageManager.PERMISSION_GRANTED) {
                    Intent intent = IntentUtils.getOpenFileIntent(getApplicationContext(), saveFilePath, contentType);
                    if (IntentUtils.validateIntent(getApplicationContext(), intent)) {
                        Log.d(TAG, "Setting an intent to open the file " + saveFilePath);
                        pendingIntent = PendingIntent.getActivity(getApplicationContext(), 0, intent, PendingIntent.FLAG_CANCEL_CURRENT);
                    } else {
                        Log.d(TAG, "There's no application that can open the file " + saveFilePath);
                    }
                }
                updateNotification(context, filename, status, progress, pendingIntent);
                taskDao.updateTask(getId().toString(), status, progress);

                Log.d(TAG, isStopped() ? "Download canceled" : "File downloaded");
            } else {
                DownloadTask task = taskDao.loadTask(getId().toString());
                int status = isStopped() ? (task.resumable ? DownloadStatus.PAUSED : DownloadStatus.CANCELED) : DownloadStatus.FAILED;
                updateNotification(context, filename, status, -1, null);
                taskDao.updateTask(getId().toString(), status, lastProgress);
                Log.d(TAG, isStopped() ? "Download canceled" : "Server replied HTTP code: " + responseCode);
            }
        } catch (IOException e) {
            updateNotification(context, filename == null ? fileURL : filename, DownloadStatus.FAILED, -1, null);
            taskDao.updateTask(getId().toString(), DownloadStatus.FAILED, lastProgress);
            e.printStackTrace();
        } finally {
            if (outputStream != null) {
                try {
                    outputStream.close();
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }
            if (inputStream != null) {
                try {
                    inputStream.close();
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }
            if (httpConn != null) {
                httpConn.disconnect();
            }
        }
    }

    private void cleanUp() {
        DownloadTask task = taskDao.loadTask(getId().toString());
        if (task != null && task.status != DownloadStatus.COMPLETE && !task.resumable) {
            String filename = task.filename;
            if (filename == null) {
                filename = task.url.substring(task.url.lastIndexOf("/") + 1, task.url.length());
            }

            // check and delete uncompleted file
            String saveFilePath = task.savedDir + File.separator + filename;
            File tempFile = new File(saveFilePath);
            if (tempFile.exists()) {
                tempFile.delete();
            }
        }
    }

    private void buildNotification(Context context) {
        // Make a channel if necessary
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Create the NotificationChannel, but only on API 26+ because
            // the NotificationChannel class is new and not in the support library

            CharSequence name = context.getApplicationInfo().loadLabel(context.getPackageManager());
            int importance = NotificationManager.IMPORTANCE_DEFAULT;
            NotificationChannel channel = new NotificationChannel(CHANNEL_ID, name, importance);
            channel.setSound(null, null);

            // Add the channel
            NotificationManager notificationManager = context.getSystemService(NotificationManager.class);

            if (notificationManager != null) {
                notificationManager.createNotificationChannel(channel);
            }
        }

        // Create the notification
        builder = new NotificationCompat.Builder(context, CHANNEL_ID)
//                .setSmallIcon(R.drawable.ic_download)
                .setOnlyAlertOnce(true)
                .setAutoCancel(true)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT);

    }

    private void updateNotification(Context context, String title, int status, int progress, PendingIntent intent) {
        builder.setContentTitle(title);
        builder.setContentIntent(intent);
        boolean shouldUpdate = false;

        if (status == DownloadStatus.RUNNING) {
            shouldUpdate = true;
            builder.setContentText(progress == 0 ? msgStarted : msgInProgress)
                    .setProgress(100, progress, progress == 0);
            builder.setOngoing(true)
                    .setSmallIcon(android.R.drawable.stat_sys_download)
                    .setLargeIcon(BitmapFactory.decodeResource(getApplicationContext().getResources(),
                            android.R.drawable.stat_sys_download));
        } else if (status == DownloadStatus.CANCELED) {
            shouldUpdate = true;
            builder.setContentText(msgCanceled).setProgress(0, 0, false);
            builder.setOngoing(false)
                    .setSmallIcon(android.R.drawable.stat_sys_download_done)
                    .setLargeIcon(BitmapFactory.decodeResource(getApplicationContext().getResources(),
                            android.R.drawable.stat_sys_download_done));
        } else if (status == DownloadStatus.FAILED) {
            shouldUpdate = true;
            builder.setContentText(msgFailed).setProgress(0, 0, false);
            builder.setOngoing(false)
                    .setSmallIcon(android.R.drawable.stat_notify_error)
                    .setLargeIcon(BitmapFactory.decodeResource(getApplicationContext().getResources(),
                            android.R.drawable.stat_sys_download_done));
        } else if (status == DownloadStatus.PAUSED) {
            shouldUpdate = true;
            builder.setContentText(msgPaused).setProgress(0, 0, false);
            builder.setOngoing(false)
                    .setSmallIcon(android.R.drawable.stat_sys_download)
                    .setLargeIcon(BitmapFactory.decodeResource(getApplicationContext().getResources(),
                            android.R.drawable.stat_sys_download));
        } else if (status == DownloadStatus.COMPLETE) {
            shouldUpdate = true;
            builder.setContentText(msgComplete).setProgress(0, 0, false);
            builder.setOngoing(false)
                    .setSmallIcon(android.R.drawable.stat_sys_download_done)
                    .setLargeIcon(BitmapFactory.decodeResource(getApplicationContext().getResources(),
                            android.R.drawable.stat_sys_download_done));
        }

        // Show the notification
        if (showNotification && shouldUpdate) {
            NotificationManagerCompat.from(context).notify(primaryId, builder.build());
        }

        sendUpdateProcessEvent(context, status, progress);
    }

    private void sendUpdateProcessEvent(Context context, int status, int progress) {
        Intent intent = new Intent(UPDATE_PROCESS_EVENT);
        intent.putExtra(EXTRA_ID, getId().toString());
        intent.putExtra(EXTRA_STATUS, status);
        intent.putExtra(EXTRA_PROGRESS, progress);
        LocalBroadcastManager.getInstance(context).sendBroadcast(intent);
    }
}
