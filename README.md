[![Flutter Community: flutter_downloader](https://fluttercommunity.dev/_github/header/flutter_downloader)](https://github.com/fluttercommunity/community)

# Flutter Downloader

[![pub package](https://img.shields.io/pub/v/flutter_downloader.svg)](https://pub.dartlang.org/packages/flutter_downloader)

A plugin for creating and managing download tasks. Supports iOS and Android.

This plugin is based on [`WorkManager`][1] in Android and [`NSURLSessionDownloadTask`][2] in iOS to run download task in background mode.

### *Development note*:

*The changes of external storage APIs in Android 11 cause some problems with the current implementation. I decide to re-design this plugin with new strategy to manage download file location. It is still in triage and discussion in this [PR](https://github.com/fluttercommunity/flutter_downloader/pull/550). It is very appreciated to have contribution and feedback from Flutter developer to get better design for the plugin.*

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

* Configure `AppDelegate`:

Objective-C:
```objective-c
/// AppDelegate.h
#import <Flutter/Flutter.h>
#import <UIKit/UIKit.h>

@interface AppDelegate : FlutterAppDelegate

@end
```

```objective-c
// AppDelegate.m
#include "AppDelegate.h"
#include "GeneratedPluginRegistrant.h"
#include "FlutterDownloaderPlugin.h"

@implementation AppDelegate

void registerPlugins(NSObject<FlutterPluginRegistry>* registry) {   
  if (![registry hasPlugin:@"FlutterDownloaderPlugin"]) {
     [FlutterDownloaderPlugin registerWithRegistrar:[registry registrarForPlugin:@"FlutterDownloaderPlugin"]];
  }
}

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  [GeneratedPluginRegistrant registerWithRegistry:self];
  [FlutterDownloaderPlugin setPluginRegistrantCallback:registerPlugins];
  // Override point for customization after application launch.
  return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

@end

```

Or Swift:
```swift
import UIKit
import Flutter
import flutter_downloader

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    FlutterDownloaderPlugin.setPluginRegistrantCallback(registerPlugins)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

private func registerPlugins(registry: FlutterPluginRegistry) { 
    if (!registry.hasPlugin("FlutterDownloaderPlugin")) {
       FlutterDownloaderPlugin.register(with: registry.registrar(forPlugin: "FlutterDownloaderPlugin")!)
    }
}

```

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

* If your project is running on Flutter versions prior v1.12, have a look at [this document](android_integration_note.md) to configure your Android project.

* From Flutter v1.12 with Android v2 embedding there's no additional configurations required to work with background isolation in Android (but you need to setup your project properly. See [upgrading pre 1.12 Android projects](https://github.com/flutter/flutter/wiki/Upgrading-pre-1.12-Android-projects))

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
<!-- Begin FlutterDownloader customization -->
<!-- disable default Initializer -->
<provider
    android:name="androidx.startup.InitializationProvider"
    android:authorities="${applicationId}.androidx-startup"
    android:exported="false"
    tools:node="merge">
    <meta-data
        android:name="androidx.work.WorkManagerInitializer"
        android:value="androidx.startup"
        tools:node="remove" />
</provider>

<!-- declare customized Initializer -->
<provider
    android:name="vn.hunghd.flutterdownloader.FlutterDownloaderInitializer"
    android:authorities="${applicationId}.flutter-downloader-init"
    android:exported="false">
    <!-- changes this number to configure the maximum number of concurrent tasks -->
    <meta-data
        android:name="vn.hunghd.flutterdownloader.MAX_CONCURRENT_TASKS"
        android:value="5" />
</provider>
<!-- End FlutterDownloader customization -->
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

* [Fix Cleartext Traffic Error in Android 9 Pie](https://medium.com/@son.rommer/fix-cleartext-traffic-error-in-android-9-pie-2f4e9e2235e6)

## Usage

#### Import package:

````dart
import 'package:flutter_downloader/flutter_downloader.dart';
````

#### Initialize

````dart
WidgetsFlutterBinding.ensureInitialized();
await FlutterDownloader.initialize(
  debug: true // optional: set false to disable printing logs to console
);
````

- Note: the plugin must be initialized before using.

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
FlutterDownloader.registerCallback(callback); // callback is a top-level or static function
````

**Important note:** your UI is rendered in the main isolate, while download events come from a background isolate (in other words, codes in `callback` are run in the background isolate), so you have to handle the communication between two isolates. For example:

````dart
ReceivePort _port = ReceivePort();

@override
void initState() {
	super.initState();

	IsolateNameServer.registerPortWithName(_port.sendPort, 'downloader_send_port');
	_port.listen((dynamic data) {
		String id = data[0];
		DownloadTaskStatus status = data[1];
		int progress = data[2];
		setState((){ });
	});

	FlutterDownloader.registerCallback(downloadCallback);
}

@override
void dispose() {
	IsolateNameServer.removePortNameMapping('downloader_send_port');
	super.dispose();
}

@pragma('vm:entry-point')
static void downloadCallback(String id, DownloadTaskStatus status, int progress) {
	final SendPort send = IsolateNameServer.lookupPortByName('downloader_send_port');
	send.send([id, status, progress]);
}

````

`@pragma('vm:entry-point')` must be placed above the `callback` function to avoid tree shaking in release mode for Android.


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
FlutterDownloader.open(taskId: taskId);
````

- Note: in Android, you can only open a downloaded file if it is placed in the external storage and there's at least one application that can read that file type on your device.

## Bugs/Requests
If you encounter any problems feel free to open an issue. If you feel the library is
missing a feature, please raise a ticket on Github. Pull request are also welcome.

[1]: https://developer.android.com/topic/libraries/architecture/workmanager
[2]: https://developer.apple.com/documentation/foundation/nsurlsessiondownloadtask?language=objc
[3]: https://medium.com/@guerrix/info-plist-localization-ad5daaea732a
[4]: https://developer.android.com/training/basics/supporting-devices/languages
