# flutter_downloader

A plugin for creating and managing download tasks. Supports iOS and Android. 

This plugin is based on [`WorkManager`][1] in Android and [`NSURLSessionDownloadTask`][2] in iOS to run download task in background mode.


## iOS integration

Open Xcode. Enable background mode.

<img width="50% src="./screenshot/enable_background_mode.png?raw=true"/>

**Note:** If you want to download file with HTTP request, you need to disable Apple Transport Security (ATS) feature.
* Disable ATS for a specific domain only: (add following codes to the end of your `Info.plist` file)
````
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

````
<key>NSAppTransportSecurity</key>  
<dict>  
    <key>NSAllowsArbitraryLoads</key><true/>  
</dict>
````

## Usage

````
import 'package:flutter_downloader/flutter_downloader.dart';
````

To create new download task:

````
final taskId = await FlutterDownloader.enqueue(
  url: `your download link`, 
  savedDir: `the path of directory where you want to save downloaded files`, 
  showNotification: true // show download progress in status bar (for Android)
);
````

To update download progress:

````
FlutterDownloader.registerCallback((id, status, progress) {
  // code to update your UI
});
````

To load the status of download tasks:

````
final tasks = await FlutterDownloader.loadTasks();
````

To cancel a task:

````
FlutterDownloader.cancel(taskId: taskId);
````

To cancel all tasks:

````
FlutterDownloader.cancelAll();
````


[1]: https://developer.android.com/topic/libraries/architecture/workmanager
[2]: https://developer.apple.com/documentation/foundation/nsurlsessiondownloadtask?language=objc