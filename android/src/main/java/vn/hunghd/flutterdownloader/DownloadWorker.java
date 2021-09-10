package vn.hunghd.flutterdownloader;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.content.res.Resources;
import android.database.Cursor;
import android.media.MediaScannerConnection;
import android.net.Uri;
import android.os.Build;

import androidx.annotation.NonNull;
import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;
import androidx.core.content.ContextCompat;

import android.os.Environment;
import android.os.Handler;
import android.provider.MediaStore;
import android.text.TextUtils;
import android.util.Log;

import androidx.annotation.RequiresApi;

import org.json.JSONException;
import org.json.JSONObject;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLDecoder;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import androidx.work.Worker;
import androidx.work.WorkerParameters;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;
import io.flutter.plugin.common.PluginRegistry.PluginRegistrantCallback;
import io.flutter.view.FlutterCallbackInformation;
import io.flutter.view.FlutterMain;
import io.flutter.view.FlutterNativeView;
import io.flutter.view.FlutterRunArguments;

public class DownloadWorker extends Worker implements MethodChannel.MethodCallHandler {
    public static final String ARG_URL = "url";
    public static final String ARG_FILE_NAME = "file_name";
    public static final String ARG_SAVED_DIR = "saved_file";
    public static final String ARG_HEADERS = "headers";
    public static final String ARG_IS_RESUME = "is_resume";
    public static final String ARG_SHOW_NOTIFICATION = "show_notification";
    public static final String ARG_OPEN_FILE_FROM_NOTIFICATION = "open_file_from_notification";
    public static final String ARG_NOTIFICATION_TITLE = "notification_title";
    public static final String ARG_CALLBACK_HANDLE = "callback_handle";
    public static final String ARG_DEBUG = "debug";

    private static final String TAG = DownloadWorker.class.getSimpleName();
    private static final int BUFFER_SIZE = 4096;
    private static final String CHANNEL_ID = "FLUTTER_DOWNLOADER_NOTIFICATION";
    private static final int STEP_UPDATE = 5;

    private static final AtomicBoolean isolateStarted = new AtomicBoolean(false);
    private static final ArrayDeque<List> isolateQueue = new ArrayDeque<>();
    private static FlutterNativeView backgroundFlutterView;

    private final Pattern charsetPattern = Pattern.compile("(?i)\\bcharset=\\s*\"?([^\\s;\"]*)");
    private final Pattern filenameStarPattern = Pattern.compile("(?i)\\bfilename\\*=([^']+)'([^']*)'\"?([^\"]+)\"?");
    private final Pattern filenamePattern = Pattern.compile("(?i)\\bfilename=\"?([^\"]+)\"?");

    private MethodChannel backgroundChannel;
    private TaskDbHelper dbHelper;
    private TaskDao taskDao;
    private boolean showNotification;
    private boolean clickToOpenDownloadedFile;
    private boolean debug;
    private int lastProgress = 0;
    private int primaryId;
    private String msgStarted, msgInProgress, msgCanceled, msgFailed, msgPaused, msgComplete;
    private long lastCallUpdateNotification = 0;

    public DownloadWorker(@NonNull final Context context,
                          @NonNull WorkerParameters params) {
        super(context, params);

        new Handler(context.getMainLooper()).post(new Runnable() {
            @Override
            public void run() {
                startBackgroundIsolate(context);
            }
        });
    }

    private void startBackgroundIsolate(Context context) {
        synchronized (isolateStarted) {
            if (backgroundFlutterView == null) {
                SharedPreferences pref = context.getSharedPreferences(FlutterDownloaderPlugin.SHARED_PREFERENCES_KEY, Context.MODE_PRIVATE);
                long callbackHandle = pref.getLong(FlutterDownloaderPlugin.CALLBACK_DISPATCHER_HANDLE_KEY, 0);

                FlutterMain.startInitialization(context); // Starts initialization of the native system, if already initialized this does nothing
                FlutterMain.ensureInitializationComplete(context, null);

                FlutterCallbackInformation callbackInfo = FlutterCallbackInformation.lookupCallbackInformation(callbackHandle);
                if (callbackInfo == null) {
                    Log.e(TAG, "Fatal: failed to find callback");
                    return;
                }

                backgroundFlutterView = new FlutterNativeView(getApplicationContext(), true);

                /// backward compatibility with V1 embedding
                if (getApplicationContext() instanceof PluginRegistrantCallback) {
                    PluginRegistrantCallback pluginRegistrantCallback = (PluginRegistrantCallback) getApplicationContext();
                    PluginRegistry registry = backgroundFlutterView.getPluginRegistry();
                    pluginRegistrantCallback.registerWith(registry);
                }

                FlutterRunArguments args = new FlutterRunArguments();
                args.bundlePath = FlutterMain.findAppBundlePath();
                args.entrypoint = callbackInfo.callbackName;
                args.libraryPath = callbackInfo.callbackLibraryPath;

                backgroundFlutterView.runFromBundle(args);
            }
        }

        backgroundChannel = new MethodChannel(backgroundFlutterView, "vn.hunghd/downloader_background");
        backgroundChannel.setMethodCallHandler(this);
    }

    @Override
    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        if (call.method.equals("didInitializeDispatcher")) {
            synchronized (isolateStarted) {
                while (!isolateQueue.isEmpty()) {
                    backgroundChannel.invokeMethod("", isolateQueue.remove());
                }
                isolateStarted.set(true);
                result.success(null);
            }
        } else {
            result.notImplemented();
        }
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
        debug = getInputData().getBoolean(ARG_DEBUG, false);

        Resources res = getApplicationContext().getResources();
        msgStarted = res.getString(R.string.flutter_downloader_notification_started);
        msgInProgress = res.getString(R.string.flutter_downloader_notification_in_progress);
        msgCanceled = res.getString(R.string.flutter_downloader_notification_canceled);
        msgFailed = res.getString(R.string.flutter_downloader_notification_failed);
        msgPaused = res.getString(R.string.flutter_downloader_notification_paused);
        msgComplete = res.getString(R.string.flutter_downloader_notification_complete);

        log("DownloadWorker{url=" + url + ",filename=" + filename + ",savedDir=" + savedDir + ",header=" + headers + ",isResume=" + isResume);

        showNotification = getInputData().getBoolean(ARG_SHOW_NOTIFICATION, false);
        clickToOpenDownloadedFile = getInputData().getBoolean(ARG_OPEN_FILE_FROM_NOTIFICATION, false);
        String notificationTitle = getInputData().getString(ARG_NOTIFICATION_TITLE);

        DownloadTask task = taskDao.loadTask(getId().toString());
        primaryId = task.primaryId;

        setupNotification(context);

        updateNotification(context, filename == null ? url : filename, DownloadStatus.RUNNING, task.progress, null, false, notificationTitle);
        taskDao.updateTask(getId().toString(), DownloadStatus.RUNNING, task.progress);

        //automatic resume for partial files. (if the workmanager unexpectedly quited in background)
        String saveFilePath = savedDir + File.separator + filename;
        File partialFile = new File(saveFilePath);
        if (partialFile.exists()) {
            isResume = true;
            log("exists file for "+ filename + "automatic resuming...");
        }

        try {
            downloadFile(context, url, savedDir, filename, notificationTitle, headers, isResume);
            cleanUp();
            dbHelper = null;
            taskDao = null;
            return Result.success();
        } catch (Exception e) {
            updateNotification(context, filename == null ? url : filename, DownloadStatus.FAILED, -1, null, true, notificationTitle);
            taskDao.updateTask(getId().toString(), DownloadStatus.FAILED, lastProgress);
            e.printStackTrace();
            dbHelper = null;
            taskDao = null;
            return Result.failure();
        }
    }

    private void setupHeaders(HttpURLConnection conn, String headers) {
        if (!TextUtils.isEmpty(headers)) {
            log("Headers = " + headers);
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
        log("Resume download: Range: bytes=" + downloadedBytes + "-");
        conn.setRequestProperty("Accept-Encoding", "identity");
        conn.setRequestProperty("Range", "bytes=" + downloadedBytes + "-");
        conn.setDoInput(true);
        return downloadedBytes;
    }

    private void downloadFile(Context context, String fileURL, String savedDir, String filename, String notificationTitle, String headers, boolean isResume) throws IOException {
        String url = fileURL;
        URL resourceUrl, base, next;
        Map<String, Integer> visited;
        HttpURLConnection httpConn = null;
        InputStream inputStream = null;
        OutputStream outputStream = null;
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
                log("Open connection to " + url);
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
                    case HttpURLConnection.HTTP_SEE_OTHER:
                    case HttpURLConnection.HTTP_MOVED_TEMP:
                        log("Response with redirection code");
                        location = httpConn.getHeaderField("Location");
                        log("Location = " + location);
                        base = new URL(url);
                        next = new URL(base, location);  // Deal with relative URLs
                        url = next.toExternalForm();
                        log("New url: " + url);
                        continue;
                }

                break;
            }

            httpConn.connect();

            if ((responseCode == HttpURLConnection.HTTP_OK || (isResume && responseCode == HttpURLConnection.HTTP_PARTIAL)) && !isStopped()) {
                String contentType = httpConn.getContentType();
                long contentLength = android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N ? httpConn.getContentLengthLong() : httpConn.getContentLength();
                log("Content-Type = " + contentType);
                log("Content-Length = " + contentLength);

                String charset = getCharsetFromContentType(contentType);
                log("Charset = " + charset);
                if (!isResume) {
                    // try to extract filename from HTTP headers if it is not given by user
                    if (filename == null) {
                        String disposition = httpConn.getHeaderField("Content-Disposition");
                        log("Content-Disposition = " + disposition);
                        if (disposition != null && !disposition.isEmpty()) {
                            filename = getFileNameFromContentDisposition(disposition, charset);
                        }
                        if (filename == null || filename.isEmpty()) {
                            filename = url.substring(url.lastIndexOf("/") + 1);
                            try {
                                filename = URLDecoder.decode(filename, "UTF-8");
                            } catch (IllegalArgumentException e) {
                                /* ok, just let filename be not encoded */
                                e.printStackTrace();
                            }
                        }
                    }
                }
                saveFilePath = savedDir + File.separator + filename;

                log("fileName = " + filename);

                taskDao.updateTask(getId().toString(), filename, contentType);

                // opens input stream from the HTTP connection
                inputStream = httpConn.getInputStream();

                // opens an output stream to save into file
                Uri uriApi29 = null;
                File fileApi21 = null;
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    uriApi29 = addFileToDownloadsApi29(filename);
                    if (isResume) {
                        outputStream = context.getContentResolver().openOutputStream(uriApi29, "wa");
                    } else {
                        outputStream = context.getContentResolver().openOutputStream(uriApi29, "w");
                    }
                } else {
                    fileApi21 = addFileToDownloadsApi21(filename);
                    outputStream = new FileOutputStream(fileApi21, isResume);
                }

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
                        updateNotification(context, filename, DownloadStatus.RUNNING, progress, null, false, notificationTitle);

                        // This line possibly causes system overloaded because of accessing to DB too many ?!!!
                        // but commenting this line causes tasks loaded from DB missing current downloading progress,
                        // however, this missing data should be temporary and it will be updated as soon as
                        // a new bunch of data fetched and a notification sent
                        taskDao.updateTask(getId().toString(), DownloadStatus.RUNNING, progress);
                    }
                }

                DownloadTask task = taskDao.loadTask(getId().toString());
                int progress = isStopped() && task.resumable ? lastProgress : 100;
                int status = isStopped() ? (task.resumable ? DownloadStatus.PAUSED : DownloadStatus.CANCELED) : DownloadStatus.COMPLETE;
                int storage = ContextCompat.checkSelfPermission(getApplicationContext(), android.Manifest.permission.WRITE_EXTERNAL_STORAGE);
                PendingIntent pendingIntent = null;
                if (status == DownloadStatus.COMPLETE) {

                    String fileSavedPath = null;
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        String savedPath = getMediaStoreEntryPathApi29(uriApi29);
                        log("File downloaded (" + savedPath + ")");
                        if (savedPath != null) {
                            scanFilePath(savedPath, contentType, uriResponse -> {
                                log("MediaStore updated (" + uriResponse + ")");
                            });
                        }
                        fileSavedPath = savedPath;
                    } else {
                        if (fileApi21 != null) {
                            log("File downloaded (" + fileApi21.getPath() + ")");
                            scanFilePath(fileApi21.getPath(), contentType, uriResponse -> {
                                log("MediaStore updated (" + uriResponse + ")");
                            });
                            fileSavedPath = fileApi21.getPath();
                        }
                    }

                    if (clickToOpenDownloadedFile) {
                        if(android.os.Build.VERSION.SDK_INT < Build.VERSION_CODES.Q && storage != PackageManager.PERMISSION_GRANTED)
                            return;
                        Intent intent = IntentUtils.validatedFileIntent(getApplicationContext(), fileSavedPath, contentType);
                        if (intent != null) {
                            log("Setting an intent to open the file " + fileSavedPath);
                            pendingIntent = PendingIntent.getActivity(getApplicationContext(), 0, intent, PendingIntent.FLAG_CANCEL_CURRENT);
                        } else {
                            log("There's no application that can open the file " + fileSavedPath);
                        }
                    }
                }
                updateNotification(context, filename, status, progress, pendingIntent, true, notificationTitle);
                taskDao.updateTask(getId().toString(), status, progress);

                log(isStopped() ? "Download canceled" : "File downloaded");
            } else {
                DownloadTask task = taskDao.loadTask(getId().toString());
                int status = isStopped() ? (task.resumable ? DownloadStatus.PAUSED : DownloadStatus.CANCELED) : DownloadStatus.FAILED;
                updateNotification(context, filename == null ? fileURL : filename, status, -1, null, true, notificationTitle);
                taskDao.updateTask(getId().toString(), status, lastProgress);
                log(isStopped() ? "Download canceled" : "Server replied HTTP code: " + responseCode);
            }
        } catch (IOException e) {
            updateNotification(context, filename == null ? fileURL : filename, DownloadStatus.FAILED, -1, null, true, notificationTitle);
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

    /**
     * Create a file inside the Download folder using java.io API
     */
    private File addFileToDownloadsApi21(String filename) {
        File downloadsFolder = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS);
        File newFile = new File(downloadsFolder, filename);
        try {
            boolean rs = newFile.createNewFile();
            if(rs) {
                return newFile;
            }
        } catch (IOException e) {
            e.printStackTrace();
            log("Create a file using java.io API failed ");
        }
        return null;
    }

    /**
     * Create a file inside the Download folder using MediaStore API
     */
    @RequiresApi(Build.VERSION_CODES.Q)
    private Uri addFileToDownloadsApi29(String filename) {
        Uri collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY);
        try {
            ContentValues values = new ContentValues();
            values.put(MediaStore.Downloads.DISPLAY_NAME, filename);
            ContentResolver contentResolver = getApplicationContext().getContentResolver();
            return contentResolver.insert(collection, values);
        } catch (Exception e) {
            e.printStackTrace();
            log("Create a file using MediaStore API failed ");
        }
        return null;
    }

    /**
     * Get a path for a MediaStore entry as it's needed when calling MediaScanner
     */
    private String getMediaStoreEntryPathApi29(Uri uri) {
        try (Cursor cursor = getApplicationContext().getContentResolver().query(
                uri,
                new String[]{MediaStore.Files.FileColumns.DATA},
                null,
                null,
                null
        )) {
            if (cursor == null)
                return null;
            if (!cursor.moveToFirst())
                return null;
            return cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATA));
        } catch (IllegalArgumentException e) {
            e.printStackTrace();
            log("Get a path for a MediaStore failed");
            return null;
        }
    }

    void scanFilePath(String path, String mimeType, CallbackUri callback) {
        MediaScannerConnection.scanFile(
            getApplicationContext(),
            new String[]{path},
            new String[]{mimeType},
            (path1, uri) -> callback.invoke(uri));
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

    private int getNotificationIconRes() {
        try {
            ApplicationInfo applicationInfo = getApplicationContext().getPackageManager().getApplicationInfo(getApplicationContext().getPackageName(), PackageManager.GET_META_DATA);
            int appIconResId = applicationInfo.icon;
            return applicationInfo.metaData.getInt("vn.hunghd.flutterdownloader.NOTIFICATION_ICON", appIconResId);
        } catch (PackageManager.NameNotFoundException e) {
            e.printStackTrace();
        }
        return 0;
    }

    private void setupNotification(Context context) {
        if (!showNotification) return;
        // Make a channel if necessary
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Create the NotificationChannel, but only on API 26+ because
            // the NotificationChannel class is new and not in the support library


            Resources res = getApplicationContext().getResources();
            String channelName = res.getString(R.string.flutter_downloader_notification_channel_name);
            String channelDescription = res.getString(R.string.flutter_downloader_notification_channel_description);
            int importance = NotificationManager.IMPORTANCE_LOW;
            NotificationChannel channel = new NotificationChannel(CHANNEL_ID, channelName, importance);
            channel.setDescription(channelDescription);
            channel.setSound(null, null);

            // Add the channel
            NotificationManagerCompat notificationManager = NotificationManagerCompat.from(context);
            notificationManager.createNotificationChannel(channel);
        }
    }

    private void updateNotification(Context context, String title, int status, int progress, PendingIntent intent, boolean finalize, String notificationTitle) {
        sendUpdateProcessEvent(status, progress);

        // Show the notification
        if (showNotification) {
            // Create the notification
            NotificationCompat.Builder builder = new NotificationCompat.Builder(context, CHANNEL_ID).
                    setContentTitle(notificationTitle == null ? title : notificationTitle)
                    .setContentIntent(intent)
                    .setOnlyAlertOnce(true)
                    .setAutoCancel(true)
                    .setPriority(NotificationCompat.PRIORITY_LOW);

            if (status == DownloadStatus.RUNNING) {
                if (progress <= 0) {
                    builder.setContentText(msgStarted)
                            .setProgress(0, 0, false);
                    builder.setOngoing(false)
                            .setSmallIcon(getNotificationIconRes());
                } else if (progress < 100) {
                    builder.setContentText(msgInProgress)
                            .setProgress(100, progress, false);
                    builder.setOngoing(true)
                            .setSmallIcon(android.R.drawable.stat_sys_download);
                } else {
                    builder.setContentText(msgComplete).setProgress(0, 0, false);
                    builder.setOngoing(false)
                            .setSmallIcon(android.R.drawable.stat_sys_download_done);
                }
            } else if (status == DownloadStatus.CANCELED) {
                builder.setContentText(msgCanceled).setProgress(0, 0, false);
                builder.setOngoing(false)
                        .setSmallIcon(android.R.drawable.stat_sys_download_done);
            } else if (status == DownloadStatus.FAILED) {
                builder.setContentText(msgFailed).setProgress(0, 0, false);
                builder.setOngoing(false)
                        .setSmallIcon(android.R.drawable.stat_sys_download_done);
            } else if (status == DownloadStatus.PAUSED) {
                builder.setContentText(msgPaused).setProgress(0, 0, false);
                builder.setOngoing(false)
                        .setSmallIcon(android.R.drawable.stat_sys_download_done);
            } else if (status == DownloadStatus.COMPLETE) {
                builder.setContentText(msgComplete).setProgress(0, 0, false);
                builder.setOngoing(false)
                        .setSmallIcon(android.R.drawable.stat_sys_download_done);
            } else {
                builder.setProgress(0, 0, false);
                builder.setOngoing(false).setSmallIcon(getNotificationIconRes());
            }

            // Note: Android applies a rate limit when updating a notification.
            // If you post updates to a notification too frequently (many in less than one second),
            // the system might drop some updates. (https://developer.android.com/training/notify-user/build-notification#Updating)
            //
            // If this is progress update, it's not much important if it is dropped because there're still incoming updates later
            // If this is the final update, it must be success otherwise the notification will be stuck at the processing state
            // In order to ensure the final one is success, we check and sleep a second if need.
            if (System.currentTimeMillis() - lastCallUpdateNotification < 1000) {
                if (finalize) {
                    log("Update too frequently!!!!, but it is the final update, we should sleep a second to ensure the update call can be processed");
                    try {
                        Thread.sleep(1000);
                    } catch (InterruptedException e) {
                        e.printStackTrace();
                    }
                } else {
                    log("Update too frequently!!!!, this should be dropped");
                    return;
                }
            }
            log("Update notification: {notificationId: " + primaryId + ", title: " + title + ", status: " + status + ", progress: " + progress + "}");
            NotificationManagerCompat.from(context).notify(primaryId, builder.build());
            lastCallUpdateNotification = System.currentTimeMillis();
        }
    }

    private void sendUpdateProcessEvent(int status, int progress) {
        final List<Object> args = new ArrayList<>();
        long callbackHandle = getInputData().getLong(ARG_CALLBACK_HANDLE, 0);
        args.add(callbackHandle);
        args.add(getId().toString());
        args.add(status);
        args.add(progress);

        synchronized (isolateStarted) {
            if (!isolateStarted.get()) {
                isolateQueue.add(args);
            } else {
                new Handler(getApplicationContext().getMainLooper()).post(new Runnable() {
                    @Override
                    public void run() {
                        backgroundChannel.invokeMethod("", args);
                    }
                });
            }
        }
    }

    private String getCharsetFromContentType(String contentType) {
        if (contentType == null)
            return null;

        Matcher m = charsetPattern.matcher(contentType);
        if (m.find()) {
            return m.group(1).trim().toUpperCase();
        }
        return null;
    }

    private String getFileNameFromContentDisposition(String disposition, String contentCharset) throws java.io.UnsupportedEncodingException {
        if (disposition == null)
            return null;

        String name = null;
        String charset = contentCharset;

        //first, match plain filename, and then replace it with star filename, to follow the spec

        Matcher plainMatcher = filenamePattern.matcher(disposition);
        if (plainMatcher.find())
            name = plainMatcher.group(1);

        Matcher starMatcher = filenameStarPattern.matcher(disposition);
        if (starMatcher.find()) {
            name = starMatcher.group(3);
            charset = starMatcher.group(1).toUpperCase();
        }

        if (name == null)
            return null;

        return URLDecoder.decode(name, charset != null ? charset : "ISO-8859-1");
    }

    private void log(String message) {
        if (debug) {
            Log.d(TAG, message);
        }
    }

    public interface CallbackUri {
        void invoke(Uri uri);
    }
}
