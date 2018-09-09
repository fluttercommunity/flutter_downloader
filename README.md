# Flutter Downloader

[![pub package](https://img.shields.io/pub/v/flutter_downloader.svg)](https://pub.dartlang.org/packages/flutter_downloader)

A plugin for creating and managing download tasks. Supports iOS and Android. 

This plugin is based on [`WorkManager`][1] in Android and [`NSURLSessionDownloadTask`][2] in iOS to run download task in background mode.


## iOS integration

* Open `ios` project (file `Runner.xcworkspace`) in Xcode. 

* Enable background mode.

<img width="512" src="https://github.com/hnvn/flutter_downloader/blob/master/screenshot/enable_background_mode.png?raw=true"/>

* Add `sqlite` library.

<p>
    <img width="512" src="https://github.com/hnvn/flutter_downloader/blob/master/screenshot/add_sqlite_1.png?raw=true" />
    <img width="512" src="https://github.com/hnvn/flutter_downloader/blob/master/screenshot/add_sqlite_2.png?raw=true" />
</p>

**Note:** If you want to download file with HTTP request, you need to disable Apple Transport Security (ATS) feature.
* Disable ATS for a specific domain only: (add following codes to the end of your `Info.plist` file)
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

* Completely disable ATS: (add following codes to the end of your `Info.plist` file)

````xml
<key>NSAppTransportSecurity</key>  
<dict>  
    <key>NSAllowsArbitraryLoads</key><true/>  
</dict>
````

## Android integration

In order to handle click action on notification to open the downloaded file on Android, you need to add some additional configurations:

* add the following codes to your `AndroidManifest.xml` (inside `application` tag):

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

* you have to save your downloaded files in external storage (where the other applications have permission to read your files)

**Note:** The downloaded files are only able to be opened if your device has at least an application that can read these file types (mp3, pdf, etc)

## Usage

````dart
import 'package:flutter_downloader/flutter_downloader.dart';
````

#### Initialize plugin:

````dart
FlutterDownloader.initialize(
  maxConcurrentTasks: 3, // config the maximum number of tasks running at a moment
  messages: {....} // localize messages for Android notification
);
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

#### Load all tasks:

````dart
final tasks = await FlutterDownloader.loadTasks();
````

#### Load tasks with conditions:

````dart
final tasks = await FlutterDownloader.loadTasksWithRawQuery(query: query);
````

- Note: In order to parse data into `DownloadTask` object successfully, you should load data with all fields from DB (in the other word, use: `SELECT *` ). For example:

````sqlite3
SELECT * FROM task WHERE status=3
````

- Note: the following is the schema of `task` table where this plugin stores tasks information

````sqlite3
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

#### Open and preview a downloaded file:

````dart
FlutterDownloader.open(taskId: taskId);
````

- Note: in Android, you can only open a downloaded file if it is placed in the external storage and there's at least one application that can read that file type on your device.

[1]: https://developer.android.com/topic/libraries/architecture/workmanager
[2]: https://developer.apple.com/documentation/foundation/nsurlsessiondownloadtask?language=objc