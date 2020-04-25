## 2.0.0 - 26-04-2020

* Completely redesign the API to be more intuitive.

## 1.4.4 - 18.04.2020

* Add `debug` (optional) parameter in `initialize()` method that supports disabling logging to console.

## 1.4.3 - 09.04.2020

* iOS: Fix bug in `remove` method.

## 1.4.2 - 02.04.2020

* Add `timeCreated` in `DownloadTask` model.
* iOS: Fix: `MissingPluginException`

## 1.4.1 - 30.01.2020

* Android: fix bug `ensureInitializationComplete must be called after startInitialization`.
* Clarify integration documents.

## 1.4.0 - 12.01.2020

* Migrate to Android v2 embedding.

## 1.3.4 - 21.12.2019

* Fix: No longer stuck in Flutter v12.13.
* Fix bug when casting int to long value.

## 1.3.3 - 03.11.2019

* Update document.
* Assert and make sure `FlutterDownloader` is initialized one time.

## 1.3.2 - 24.10.2019

* Correct document and example codes about communication with background isolate.

## 1.3.1 - 18.09.2019

* `assert` the initialization of `FlutterDownloader`.

## 1.3.0 - 16.09.2019

* **BREAKING CHANGES**: The plugin has been refactored to support update download events with background isolate. In order to support background execution in Dart, the `callback` that receives events from platform codes, now must be a static or top-level function. There's also an additional native configuration required on both iOS and Android. See the readme for more details.
* Android: Upgrade `WorkManager` to v2.2.0.
* Android: Fix: `SecurityException` no longer occurs when saving image/videos to internal storage.
* Android: Fix: Videos can now be saved.

## 1.2.2 - 19.09.2019

* Android: Fix bugs.

## 1.2.1 - 27.08.2019

* Android: Hot-fix unregister `BroadcastReceiver` in case of using `FlutterFragmentActivity`.

## 1.2.0 - 27.08.2019

* Android: Support `FlutterFragmentActivity`, fix bug where the downloaded image/video files were not shown in the gallery. Improved HTTP redirection implementation, fix the bug "cannot open apk file" in some cases.

## 1.1.9 - 18.07.2019

* Android: Support HTTP redirection.
* iOS: Fix getting the file name from the HTTP response.

## 1.1.8 - 16.07.2019

* Fix bug on iOS: Since iOS 8, the absolute path to the app's sandbox changes every time you relaunch the app, hence `savedDir` path is needed to truncate the changing part before saving it to DB and recreate the absolute path every time it loaded from DB. Currently, the plugin only supports save files in `NSDocumentDirectory`.
* iOS: Set correct status of task in case the application is terminated.
* Android: Upgrade dependencies.

## 1.1.7 - 24.03.2019

* Android: Upgrade `WorkManager` to version 2.0.0 (AndroidX).

## 1.1.6 - 09.02.2019

* Android: Upgrade `WorkManager` to version 1.0.0-beta05.
* Android: Migrate to AndroidX.

## 1.1.5 - 27.01.2019

* Android: Upgrade `WorkManager` to version 1.0.0-beta03.
* Fix several minor bugs.

## 1.1.4 - 06.01.2019

* Add `remove()` feature to delete task (in DB) and downloaded file as well (optional).
* Support clean up callback by setting callback as `null` in `registerCallback()`.
* Android: Upgrade `WorkManager` to version 1.0.0-beta01.

## 1.1.3 - 18.11.2018

* Android: Fix bug `NullPointerException` of `saveFilePath`.

## 1.1.2 - 14.11.2018

* Android: Fix typo error.
* iOS: Catch HTTP status code in case of error.

## 1.1.1 - 12.11.2018

* Correct readme instructions.

## 1.1.0 - 12.11.2018

* Android: upgrade `WorkManager` library to version v1.0.0-alpha11
* **BREAKING CHANGE**: Removed `initialize()` to deal with the change of the initialization of `WorkManager` in v1.0.0-alpha11. The plugin initializes itself with default configurations. If you would like to change the default configuration, you can follows the instruction in the readme.

## 1.0.6 - 28.10.2018

* Fix bug related to `filename`.

## 1.0.5 - 22.10.2018

* Android: Reconfigure dependencies.

## 1.0.4 - 20.10.2018

* Android: Upgrade WorkManager to v1.0.0-alpha10.

## 1.0.3 - 29.09.2018

* Android: Upgrade compile sdk version to 28.

## 1.0.2 - 20.09.2018

* Fixed Flutter Community badge.

## 1.0.1 - 20.09.2018

* Moved package to [Flutter Community](https://github.com/fluttercommunity)

## 1.0.0 - 09.09.2018

* Add `initialize`, `loadTasksWithRawQuery`, `pause`, `resume`, `retry`, `open`.
* **IMPORTANT:** The plugin has to be initialized by calling `initialize()` at first.
* **BREAKING CHANGE:** Rename `clickToOpenDownloadedFile` to `openFileFromNotification` (to prevent confusing from `open` feature). Static property `maximumConcurrentTask` has been removed, this configuration now moves into `initialize()` method.
* Full support of SQLite on both Android and iOS side, the plugin now itself manages its states persistently and exposes a `loadTasksWithRawQuery` API that helps developers to load tasks from SQLite database with customized conditions.
* Support localizing Android notification messages with `messages` parameter of `initialize()` method.
* Full support for opening and previewing downloaded file with `open()` method.
* On iOS, there's no need to override `application:handleEventsForBackgroundURLSession:completionHandler:` manually anymore, the plugin takes responsibility for that itself.

## 0.1.1 - 29.08.2018

* Fix SQLite leak.
* Support configuration of the maximum number of concurrent download tasks.
* Upgrade WorkManager to v1.0.0-alpha08.

## 0.1.0 - 12.08.2018

* Handle click on notification to open downloaded file (for Android).

## 0.0.9 - 10.08.2018

* Re-configure to support Dart 2.

## 0.0.8 - 10.08.2018

* Upgrade WorkManager to v1.0.0-alpha06.
* Fix: Disable notification sound.

## 0.0.7 - 28.06.2018

* Upgrade WorkManager to v1.0.0-alpha04.

## 0.0.6 - 28.06.2018

* Upgrade WorkManager to v1.0.0-alpha03.
* Change default value of `showNotification` to `true` (it makes sense on Android 8.0 and above as it helps our tasks not to be killed by system when the app goes to background).

## 0.0.5 - 22.06.2018

* Update package metadata.

## 0.0.4 - 15.06.2018

* Fix: Worker finished with FAILURE on Android API 26 and above.

## 0.0.3 - 11.06.2018

* Support providing custom HTTP headers.

## 0.0.2 - 08.06.2018

* Correct readme.

## 0.0.1 - 07.06.2018

* Initial release.
