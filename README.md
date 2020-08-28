[![Flutter Community: flutter_downloader](https://fluttercommunity.dev/_github/header/flutter_downloader)](https://github.com/fluttercommunity/community)

[![pub package](https://img.shields.io/pub/v/flutter_downloader.svg)](https://pub.dartlang.org/packages/flutter_downloader)

A plugin for creating and managing download tasks. Supports iOS and Android.

This plugin is based on [`WorkManager`][1] in Android and [`NSURLSessionDownloadTask`][2] in iOS to run download tasks in the background.

## Setup

<details>

<summary>iOS</summary>

### Required configuration:

**Note:** following steps requires to open your `ios` project in Xcode.

* Enable background mode.

<img width="512" src="https://github.com/hnvn/flutter_downloader/blob/master/screenshot/enable_background_mode.png?raw=true"/>

* Add <kbd>sqlite</kbd> library.

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
       FlutterDownloaderPlugin.register(with: registry.registrar(forPlugin: "FlutterDownloaderPlugin"))
    }
}
```

### Optional configuration:

* **Support HTTP request:** If you want to download file via HTTP request, you need to disable Apple Transport Security (ATS). There are two options:

1. **Disable ATS for a specific domain only:** Add following codes to your `Info.plist` file.

```xml
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

2. **Completely disable ATS:** Add following codes to your `Info.plist` file.

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key><true/>
</dict>
```

* **Configure maximum number of concurrent tasks:** the plugin allows 3 `DownloadTask`s running simultaneously by default. If you enqueue more than 3 tasks, there're only 3 tasks running, other tasks are put in a pending state. You can change this number by adding the following code to your `Info.plist` file:

```xml
<!-- changes this number to configure the maximum number of concurrent tasks -->
<key>FDMaximumConcurrentTasks</key>
<integer>5</integer>
```

* **Localize notification messages:** The plugin will send a notification message to notify the user in case all files are downloaded while your application is not running in foreground. This message is in English by default. You can localize this message by adding and localizing the following message in `Info.plist` file. You can find the detail of `Info.plist` localization in this [link][3].

```xml
<key>FDAllFilesDownloadedMessage</key>
<string>All files have been downloaded</string>
```

**Note:** This plugin only supports saving files in `NSDocumentDirectory`.

</details>

<details>

<summary>Android</summary>

## Android integration

### Required configuration:

* If your project is running on Flutter versions prior v1.12, have a look at [this document](android_integration_note.md) to configure your Android project.

* From Flutter v1.12 with Android v2 embedding there's no additional configurations required to work with background isolation in Android, but you need to setup your project properly. See [upgrading pre 1.12 Android projects](https://github.com/flutter/flutter/wiki/Upgrading-pre-1.12-Android-projects).

* In order to handle notification clicks to open the downloaded file, you need to add some additional configurations. Add the following codes to your `AndroidManifest.xml`:

```xml
<provider
    android:name="vn.hunghd.flutterdownloader.DownloadedFileProvider"
    android:authorities="${applicationId}.flutter_downloader.provider"
    android:exported="false"
    android:grantUriPermissions="true">
    <meta-data
        android:name="android.support.FILE_PROVIDER_PATHS"
        android:resource="@xml/provider_paths"/>
</provider>
```

**Note:**
- You have to save your downloaded files in external storage, where the other applications have permission to read your files.
- The downloaded files can only be opened if your device has at least one application that can read these file types (mp3, pdf, etc).

### Optional configuration:

* **Configure maximum number of concurrent tasks:** The plugin depends on `WorkManager` library and `WorkManager` depends on the number of available processor to configure the maximum number of tasks running at a moment. You can setup a fixed number for this configuration by adding the following code to your `AndroidManifest.xml`:

```xml
 <provider
     android:name="androidx.work.impl.WorkManagerInitializer"
     android:authorities="${applicationId}.workmanager-init"
     tools:node="remove" />

 <provider
    android:name="vn.hunghd.flutterdownloader.FlutterDownloaderInitializer"
    android:authorities="${applicationId}.flutter-downloader-init"
    android:exported="false">
    <!-- changes this number to configure the maximum number of concurrent tasks -->
    <meta-data
        android:name="vn.hunghd.flutterdownloader.MAX_CONCURRENT_TASKS"
        android:value="5" />
</provider>
```

* **Localize notification messages:** you can localize notification messages of download progress by localizing following messages. You can find more details about string localization on Android [here][4].

```xml
<string name="flutter_downloader_notification_started">Download started</string>
<string name="flutter_downloader_notification_in_progress">Download in progress</string>
<string name="flutter_downloader_notification_canceled">Download canceled</string>
<string name="flutter_downloader_notification_failed">Download failed</string>
<string name="flutter_downloader_notification_complete">Download complete</string>
<string name="flutter_downloader_notification_paused">Download paused</string>
```

* **PackageInstaller:** In order to open APK files, your application needs `REQUEST_INSTALL_PACKAGES` permission. Add the following code in your `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />
```

* [Fix Cleartext Traffic Error in Android 9 Pie](https://medium.com/@son.rommer/fix-cleartext-traffic-error-in-android-9-pie-2f4e9e2235e6)

</details>

## Usage

At the beginning of your `main` method, initialize the package:

```dart
await FlutterDownloader.initialize();
```

Then, you can create new `DownloadTask`s anywhere in your app:

```dart
final task = await DownloadTask.create(
  url: 'https://...',
  downloadDirectory: await getExternalStorageDirectory(),
);
```

> Note: The `getExternalStorageDirectory` method used here is from the [<kbd>path_provider</kbd>](https://pub.dev/packages/path_provider) package.

Once you got a task, you can do stuff with it.

For example, you can wait until the download completed and then open the downloaded file:

```dart
await task.wait();
final wasSuccessfullyOpened = await task.openFile();
```

> *Note:* in Android, you can only open a downloaded file if it is placed in the external storage and there's at least one application that can read that file type on your device.

You can also listen for `taks.updates`, which is especially useful when showing progress to the user:

```dart
StreamBuilder<DownloadTask>(
  stream: task.updates,
  initialData: task,
  builder: (_, __) => LinearProgressIndicator(value: task.progress),
);
```

And there's so much more you can do: You can `pause` and `resume` tasks, `cancel` them and `retry` failed or canceled tasks.
For a demonstration of all of these, check out the [example](https://github.com/fluttercommunity/flutter_downloader/blob/master/example/lib/main.dart).

There's also some global methods under the `FlutterDownloader`, for example to load or cancel all tasks.

<details>

<summary>Advanced stuff</summary>

Internally, all `DownloadTask`s are stored in an SQL database.
You can directly query into this database:

```dart
final tasks = await FlutterDownloader.loadTasksWithRawQuery(query: 'SELECT * FROM task WHERE status=3');
```

> *Note:* This is the schema of the `task` table:
>
> ```SQL
> CREATE TABLE `task` (
>   `id` INTEGER PRIMARY KEY AUTOINCREMENT,
>   `task_id` VARCHAR ( 256 ),
>   `url` TEXT,
>   `status` INTEGER DEFAULT 0,
>   `progress` INTEGER DEFAULT 0,
>   `file_name` TEXT,
>   `saved_dir` TEXT,
>   `resumable` TINYINT DEFAULT 0,
>   `headers` TEXT,
>   `show_notification` TINYINT DEFAULT 0,
>   `open_file_from_notification` TINYINT DEFAULT 0,
>   `time_created` INTEGER DEFAULT 0
> );
> ```

## Bugs/PRs

If you encounter any problems or feel the library is missing a feature, feel free to [open an issue on GitHub](https://github.com/fluttercommunity/flutter_downloader/issues/new).

[1]: https://developer.android.com/topic/libraries/architecture/workmanager
[2]: https://developer.apple.com/documentation/foundation/nsurlsessiondownloadtask?language=objc
[3]: https://medium.com/@guerrix/info-plist-localization-ad5daaea732a
[4]: https://developer.android.com/training/basics/supporting-devices/languages
