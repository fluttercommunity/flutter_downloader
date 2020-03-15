## Android integration

### Required configuration:

* Configure `Application`:

Java: 
```java
// MyApplication.java (create this file if it doesn't exist in your project)

import io.flutter.app.FlutterApplication;
import io.flutter.plugin.common.PluginRegistry;
import io.flutter.plugins.GeneratedPluginRegistrant;
import vn.hunghd.flutterdownloader.FlutterDownloaderPlugin;

public class MyApplication extends FlutterApplication implements PluginRegistry.PluginRegistrantCallback {
    @Override
    public void registerWith(PluginRegistry registry) {
        //
        // Integration note:
        //
        // In Flutter, in order to work in background isolate, plugins need to register with
        // a special instance of `FlutterEngine` that serves for background execution only.
        // Hence, all (and only) plugins that require background execution feature need to 
        // call `registerWith` in this method. 
        //
        // The default `GeneratedPluginRegistrant` will call `registerWith` of all plugins
        // integrated in your application. Hence, if you are using `FlutterDownloaderPlugin`
        // along with other plugins that need UI manipulation, you should register
        // `FlutterDownloaderPlugin` and any 'background' plugins explicitly like this:
        //   
        // if (!registry.hasPlugin("vn.hunghd.flutterdownloader.FlutterDownloaderPlugin")) {
        //    FlutterDownloaderPlugin.registerWith(registry.registrarFor("vn.hunghd.flutterdownloader.FlutterDownloaderPlugin"));
        // }
        //
        GeneratedPluginRegistrant.registerWith(registry);
    }
}
```

Or Kotlin:
```kotlin
// MyApplication.kt (create this file if it doesn't exist in your project)

import io.flutter.app.FlutterApplication
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugins.GeneratedPluginRegistrant
import vn.hunghd.flutterdownloader.FlutterDownloaderPlugin

internal class MyApplication : FlutterApplication(), PluginRegistry.PluginRegistrantCallback {
    override fun registerWith(registry: PluginRegistry) {
        //
        // Integration note:
        //
        // In Flutter, in order to work in background isolate, plugins need to register with
        // a special instance of `FlutterEngine` that serves for background execution only.
        // Hence, all (and only) plugins that require background execution feature need to 
        // call `registerWith` in this method. 
        //
        // The default `GeneratedPluginRegistrant` will call `registerWith` of all plugins
        // integrated in your application. Hence, if you are using `FlutterDownloaderPlugin`
        // along with other plugins that need UI manipulation, you should register
        // `FlutterDownloaderPlugin` and any 'background' plugins explicitly like this:
        // 
        // if (!registry.hasPlugin("vn.hunghd.flutterdownloader.FlutterDownloaderPlugin")) {
        //    FlutterDownloaderPlugin.registerWith(registry.registrarFor("vn.hunghd.flutterdownloader.FlutterDownloaderPlugin"))
        // }
        //
        GeneratedPluginRegistrant.registerWith(registry)
    }
}
```

And update `AndroidManifest.xml`
```xml
<!-- AndroidManifest.xml -->
<application
        android:name=".MyApplication"
        ....>
```

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
