package vn.hunghd.flutterdownloader;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.net.Uri;
import android.os.Build;
import android.support.annotation.NonNull;
import android.support.v4.app.NotificationCompat;
import android.support.v4.app.NotificationManagerCompat;
import android.support.v4.content.FileProvider;
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
import java.net.MalformedURLException;
import java.net.URL;
import java.util.Iterator;
import java.util.List;

import androidx.work.Worker;

public class DownloadWorker extends Worker {
    public static final String UPDATE_PROCESS_EVENT = "vn.hunghd.flutterdownloader.UPDATE_PROCESS_EVENT";

    public static final String ARG_URL = "url";
    public static final String ARG_FILE_NAME = "file_name";
    public static final String ARG_SAVED_DIR = "saved_file";
    public static final String ARG_HEADERS = "headers";
    public static final String ARG_IS_RESUME = "is_resume";
    public static final String ARG_SHOW_NOTIFICATION = "show_notification";
    public static final String ARG_CLICK_TO_OPEN_DOWNLOADED_FILE = "click_to_open_downloaded_file";
    public static final String ARG_MESSAGES = "messages";

    public static final String MSG_STARTED = "msg_started";
    public static final String MSG_IN_PROGRESS = "msg_in_progress";
    public static final String MSG_CANCELED = "msg_canceled";
    public static final String MSG_FAILED = "msg_failed";
    public static final String MSG_PAUSED = "msg_paused";
    public static final String MSG_COMPLETE = "msg_complete";

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

        msgStarted = getInputData().getString(MSG_STARTED);
        msgInProgress = getInputData().getString(MSG_IN_PROGRESS);
        msgCanceled = getInputData().getString(MSG_CANCELED);
        msgFailed = getInputData().getString(MSG_FAILED);
        msgPaused = getInputData().getString(MSG_PAUSED);
        msgComplete = getInputData().getString(MSG_COMPLETE);

        Log.d(TAG, "DownloadWorker{url=" + url + ",filename=" + filename + ",savedDir=" + savedDir + ",header=" + headers + ",isResume=" + isResume);

        showNotification = getInputData().getBoolean(ARG_SHOW_NOTIFICATION, false);
        clickToOpenDownloadedFile = getInputData().getBoolean(ARG_CLICK_TO_OPEN_DOWNLOADED_FILE, false);

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
            return Result.SUCCESS;
        } catch (Exception e) {
            updateNotification(context, filename == null ? url : filename, DownloadStatus.FAILED, -1, null);
            taskDao.updateTask(getId().toString(), DownloadStatus.FAILED, lastProgress);
            e.printStackTrace();
            dbHelper = null;
            taskDao = null;
            return Result.FAILURE;
        }
    }

    private void downloadFile(Context context, String fileURL, String savedDir, String filename, String headers, boolean isResume) throws MalformedURLException {
        URL url = new URL(fileURL);

        HttpURLConnection httpConn = null;
        InputStream inputStream = null;
        FileOutputStream outputStream = null;

        if (filename == null) {
            filename = fileURL.substring(fileURL.lastIndexOf("/") + 1, fileURL.length());
        }
        String saveFilePath = savedDir + File.separator + filename;
        long downloadedBytes = 0;

        try {
            httpConn = (HttpURLConnection) url.openConnection();

            if (!TextUtils.isEmpty(headers)) {
                Log.d(TAG, "Headers = " + headers);
                try {
                    JSONObject json = new JSONObject(headers);
                    for (Iterator<String> it = json.keys(); it.hasNext(); ) {
                        String key = it.next();
                        httpConn.setRequestProperty(key, json.getString(key));
                    }
                    httpConn.setDoInput(true);
                } catch (JSONException e) {
                    e.printStackTrace();
                }
            }
            if (isResume) {
                File partialFile = new File(saveFilePath);
                downloadedBytes = partialFile.length();
                Log.d(TAG, "Resume download: Range: bytes=" + downloadedBytes + "-");
                httpConn.setRequestProperty("Accept-Encoding", "identity");
                httpConn.setRequestProperty("Range", "bytes=" + downloadedBytes + "-");
                httpConn.setDoInput(true);
            }
            httpConn.connect();
            int responseCode = httpConn.getResponseCode();

            // always check HTTP response code first
            if ((responseCode == HttpURLConnection.HTTP_OK || (isResume && responseCode == HttpURLConnection.HTTP_PARTIAL)) && !isStopped() && !isCancelled()) {
                String contentType = httpConn.getContentType();
                int contentLength = httpConn.getContentLength();

                Log.d(TAG, "Content-Type = " + contentType);
                Log.d(TAG, "Content-Length = " + contentLength);
                Log.d(TAG, "fileName = " + filename);

                // opens input stream from the HTTP connection
                inputStream = httpConn.getInputStream();

                // opens an output stream to save into file
                outputStream = new FileOutputStream(saveFilePath, isResume);

                long count = downloadedBytes;
                int bytesRead = -1;
                byte[] buffer = new byte[BUFFER_SIZE];
                while ((bytesRead = inputStream.read(buffer)) != -1 && !isStopped() && !isCancelled()) {
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
                int progress = (isStopped() || isCancelled()) && task.resumable ? lastProgress : 100;
                int status = (isStopped() || isCancelled()) && task.resumable ? DownloadStatus.PAUSED : DownloadStatus.COMPLETE;
                PendingIntent pendingIntent = null;
                if (status == DownloadStatus.COMPLETE && clickToOpenDownloadedFile) {
                    Intent intent = getOpenFileIntent(saveFilePath, contentType);
                    if (validateIntent(intent)) {
                        Log.d(TAG, "Setting an intent to open the file " + saveFilePath);
                        pendingIntent = PendingIntent.getActivity(getApplicationContext(), 0, intent, PendingIntent.FLAG_CANCEL_CURRENT);
                    } else {
                        Log.d(TAG, "There's no application that can open the file " + saveFilePath);
                    }
                }
                updateNotification(context, filename, status, progress, pendingIntent);
                taskDao.updateTask(getId().toString(), status, progress);

                Log.d(TAG, isStopped() || isCancelled() ? "Download canceled" : "File downloaded");
            } else {
                DownloadTask task = taskDao.loadTask(getId().toString());
                int status = isStopped() || isCancelled() ? ((task.resumable) ? DownloadStatus.PAUSED : DownloadStatus.CANCELED) : DownloadStatus.FAILED;
                updateNotification(context, filename, status, -1, null);
                taskDao.updateTask(getId().toString(), status, lastProgress);
                Log.d(TAG, isStopped() || isCancelled() ? "Download canceled" : "Server replied HTTP code: " + responseCode);
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
                .setSmallIcon(R.drawable.ic_download)
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
        } else if (status == DownloadStatus.CANCELED) {
            shouldUpdate = true;
            builder.setContentText(msgCanceled).setProgress(0, 0, false);
        } else if (status == DownloadStatus.FAILED) {
            shouldUpdate = true;
            builder.setContentText(msgFailed).setProgress(0, 0, false);
        } else if (status == DownloadStatus.PAUSED) {
            shouldUpdate = true;
            builder.setContentText(msgPaused).setProgress(0, 0, false);
        } else if (status == DownloadStatus.COMPLETE) {
            shouldUpdate = true;
            builder.setContentText(msgComplete).setProgress(0, 0, false);
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

    private Intent getOpenFileIntent(String path, String contentType) {
        File file = new File(path);
        Uri uri = FileProvider.getUriForFile(getApplicationContext(), getApplicationContext().getPackageName() + ".flutter_downloader.provider", file);
        Intent intent = new Intent(Intent.ACTION_VIEW);
        intent.setDataAndType(uri, contentType);
        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        return intent;
    }

    private boolean validateIntent(Intent intent) {
        PackageManager manager = getApplicationContext().getPackageManager();
        List<ResolveInfo> infos = manager.queryIntentActivities(intent, 0);
        if (infos.size() > 0) {
            //Then there is an Application(s) can handle this intent
            return true;
        } else {
            //No Application can handle this intent
            return false;
        }
    }
}
