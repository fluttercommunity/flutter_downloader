[![Flutter Community: flutter_downloader](https://fluttercommunity.dev/_github/header/flutter_downloader)](https://github.com/fluttercommunity/community)

# Flutter Downloader

[![pub package](https://img.shields.io/pub/v/flutter_downloader.svg)](https://pub.dartlang.org/packages/flutter_downloader)

A plugin for creating and managing download tasks. Supports iOS and Android.

This plugin is based on [`WorkManager`][1] in Android and [`NSURLSessionDownloadTask`][2] in iOS to run download task in background mode.



## iOS integration

### Required configuration:

**Note:** following steps requires to open your `ios` project in Xcode.

* Enable background mode.

<img width="512" src="https://github.com/hnvn/flutter_downloader/blob/master/screenshot/enable_background_mode.png?raw=true"/>

* Add `sqlite` library.

<p>
    <img width="512" src="https://github.com/hnvn/flutter_downloader/blob/master/screenshot/add_sqlite_1.png?raw=true" />
</p>
<p style="margin-top:30;">
    <img width="512" src="https://github.com/hnvn/flutter_downloader/blob/master/screenshot/add_sqlite_2.png?raw=true" />
</p>



### Optional configuration:

* **Support HTTP request:** if you want to download file with HTTP request, you need to disable Apple Transport Security (ATS) feature. There're two options:

1. Disable ATS for a specific domain only: (add following codes to your `Info.plist` file)

````xml
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSExceptionDomains</key>
  <dict>
    <key>www.yourserver.com</key>
    <dict>
      <!-- add this key to enable subdomains such as sub.yourserver.com -->
      <key>NSIncludesSubdomains</key>
      <true/>
      <!-- add this key to allow standard HTTP requests, thus negating the ATS -->
      <key>NSTemporaryExceptionAllowsInsecureHTTPLoads</key>
      <true/>
      <!-- add this key to specify the minimum TLS version to accept -->
      <key>NSTemporaryExceptionMinimumTLSVersion</key>
      <string>TLSv1.1</string>
    </dict>
  </dict>
</dict>
````

2. Completely disable ATS: (add following codes to your `Info.plist` file)

````xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key><true/>
</dict>
````

* **Configure maximum number of concurrent tasks:** the plugin allows 3 download tasks running at a moment by default (if you enqueue more than 3 tasks, there're only 3 tasks running, other tasks are put in pending state). You can change this number by adding following codes to your `Info.plist` file.

````xml
<!-- changes this number to configure the maximum number of concurrent tasks -->
<key>FDMaximumConcurrentTasks</key>
<integer>5</integer>
````

* **Localize notification messages:** the plugin will send a notification message to notify user in case all files are downloaded while your application is not running in foreground. This message is English by default. You can localize this message by adding and localizing following message in `Info.plist` file. (you can find the detail of `Info.plist` localization in this [link][3])

````xml
<key>FDAllFilesDownloadedMessage</key>
<string>All files have been downloaded</string>
````

**Note:**
 - This plugin only supports save files in `NSDocumentDirectory`


## Android integration

### Required configuration:

* In order to handle click action on notification to open the downloaded file on Android, you need to add some additional configurations. Add the following codes to your `AndroidManifest.xml`:

````xml
<provider
    android:name="vn.hunghd.flutterdownloader.DownloadedFileProvider"
    android:authorities="${applicationId}.flutter_downloader.provider"
    android:exported="false"
    android:grantUriPermissions="true">
    <meta-data
        android:name="android.support.FILE_PROVIDER_PATHS"
        android:resource="@xml/provider_paths"/>
</provider>
````

**Note:**
 - You have to save your downloaded files in external storage (where the other applications have permission to read your files)
 - The downloaded files are only able to be opened if your device has at least an application that can read these file types (mp3, pdf, etc)



### Optional configuration:

* **Configure maximum number of concurrent tasks:** the plugin depends on `WorkManager` library and `WorkManager` depends on the number of available processor to configure the maximum number of tasks running at a moment. You can setup a fixed number for this configuration by adding following codes to your `AndroidManifest.xml`:

````xml
 <provider
     android:name="androidx.work.impl.WorkManagerInitializer"
     android:authorities="${applicationId}.workmanager-init"
     android:enabled="false"
     android:exported="false" />

 <provider
     android:name="vn.hunghd.flutterdownloader.FlutterDownloaderInitializer"
     android:authorities="${applicationId}.flutter-downloader-init"
     android:exported="false">
     <!-- changes this number to configure the maximum number of concurrent tasks -->
     <meta-data
         android:name="vn.hunghd.flutterdownloader.MAX_CONCURRENT_TASKS"
         android:value="5" />
 </provider>
 ````

* **Localize notification messages:** you can localize notification messages of download progress by localizing following messages. (you can find the detail of string localization in Android in this [link][4])

````xml
<string name="flutter_downloader_notification_started">Download started</string>
<string name="flutter_downloader_notification_in_progress">Download in progress</string>
<string name="flutter_downloader_notification_canceled">Download canceled</string>
<string name="flutter_downloader_notification_failed">Download failed</string>
<string name="flutter_downloader_notification_complete">Download complete</string>
<string name="flutter_downloader_notification_paused">Download paused</string>
````

* **PackageInstaller:** in order to open APK files, your application needs `REQUEST_INSTALL_PACKAGES` permission. Add following codes in your `AndroidManifest.xml`:

````xml
<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />
````

## Usage

#### Import package:

````dart
import 'package:flutter_downloader/flutter_downloader.dart';
````

#### Create new download task:

````dart
final taskId = await FlutterDownloader.enqueue(
  url: 'your download link',
  savedDir: 'the path of directory where you want to save downloaded files',
  showNotification: true, // show download progress in status bar (for Android)
  openFileFromNotification: true, // click on notification to open downloaded file (for Android)
);
````

#### Update download progress:

````dart
FlutterDownloader.registerCallback((id, status, progress) {
  // code to update your UI
});
````

- Note: set `callback` as `null` to remove listener. You should clean up callback to prevent from leaking references.

#### Load all tasks:

````dart
final tasks = await FlutterDownloader.loadTasks();
````

#### Load tasks with conditions:

````dart
final tasks = await FlutterDownloader.loadTasksWithRawQuery(query: query);
````

- Note: In order to parse data into `DownloadTask` object successfully, you should load data with all fields from DB (in the other word, use: `SELECT *` ). For example:

````SQL
SELECT * FROM task WHERE status=3
````

- Note: the following is the schema of `task` table where this plugin stores tasks information

````SQL
CREATE TABLE `task` (
	`id`	INTEGER PRIMARY KEY AUTOINCREMENT,
	`task_id`	VARCHAR ( 256 ),
	`url`	TEXT,
	`status`	INTEGER DEFAULT 0,
	`progress`	INTEGER DEFAULT 0,
	`file_name`	TEXT,
	`saved_dir`	TEXT,
	`resumable`	TINYINT DEFAULT 0,
	`headers`	TEXT,
	`show_notification`	TINYINT DEFAULT 0,
	`open_file_from_notification`	TINYINT DEFAULT 0,
	`time_created`	INTEGER DEFAULT 0
);
````

#### Cancel a task:

````dart
FlutterDownloader.cancel(taskId: taskId);
````

#### Cancel all tasks:

````dart
FlutterDownloader.cancelAll();
````

#### Pause a task:

````dart
FlutterDownloader.pause(taskId: taskId);
````

#### Resume a task:

````dart
FlutterDownloader.resume(taskId: taskId);
````

- Note: `resume()` will return a new `taskId` corresponding to a new background task that is created to continue the download process. You should replace the original `taskId` (that is marked as `paused` status) by this new `taskId` to continue tracking the download progress.

#### Retry a failed task:

````dart
FlutterDownloader.retry(taskId: taskId);
````

- Note: `retry()` will return a new `taskId` (like `resume()`)

#### Remove a task:

```dart
FlutterDownloader.remove(taskId: taskId, shouldDeleteContent:false);
```

#### Open and preview a downloaded file:

````dart
FlutterDownloader.open(taskId: taskId, title: "Title (Optional)");
````

**Note:**
 - In Android, you can only open a downloaded file if it is placed in the external storage and there's at least one application that can read that file type on your device.
 - The title option is only supported in iOS.

## Bugs/Requests
If you encounter any problems feel free to open an issue. If you feel the library is
missing a feature, please raise a ticket on Github. Pull request are also welcome.

[1]: https://developer.android.com/topic/libraries/architecture/workmanager
[2]: https://developer.apple.com/documentation/foundation/nsurlsessiondownloadtask?language=objc
[3]: https://medium.com/@guerrix/info-plist-localization-ad5daaea732a
[4]: https://developer.android.com/training/basics/supporting-devices/languages
