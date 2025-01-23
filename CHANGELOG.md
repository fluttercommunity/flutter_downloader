## 1.12.0

- Dependencies update (#990)
  - **Bump minimum Flutter to 3.27**
  - Update leancode_lint and fix all new warnings
  - Bump Gradle to 8.8
  - Bump Kotlin to 2.1.0

## 1.11.8

- Allow nullable Content-Yype (#966)
- Dependencies update (#952)
  - Gradle buildscripts on Android
  - Bump minimum Android SDK to 21
  - Bump minimum Flutter to 3.19

## 1.11.7

- Update dependencies (#946)
- Update CI workflows (#945)
- Bump `compileSdk` to 34 (#944)

## 1.11.6

- No release notes were provided

## 1.11.5

- Republish fixes for previous verison

## 1.11.4

- Fix for not working after upgrade to IOS 17 and Xcode 15 (#899)
- fix for Issue with Spaces and Parentheses in File Names (#904)

## 1.11.3

- Fix for file name not being saved (#894)

## 1.11.2

- Security update for iOS (#887)
- Support file store in any iOS directory (#829)

## 1.11.1

- Don't crash when `FlutterDownloader.registerCallback()` wasn't called (#879)

## 1.11.0

- Convert `DownloadTaskStatus` into an `enum` (#835)

## 1.10.7

- Override `operator ==` and `hashCode` for `DownloadTask` (#875)

## 1.10.6

- Fix `delete()` not working when file isn't saved to public storage (#871)
- Update CI workflows on GitHub Actions (#872)
- Bump native Android dependencies and Gradle (#873)
- Bump minimum Flutter version to 3.10 (#873)

## 1.10.5

- Make the project compile when the app not doesn't have dependency on Kotlin
  (#869)

## 1.10.4

- Fix Android build failing because of JVM and Kotlin target source
  compatibility (#862)
- Set upper Dart version constraint to `<4.0.0` (#863)

## 1.10.3

- Fix Android build failing when using Android Gradle Plugin v8 (#857)

## 1.10.2

- Correctly read the error/success codes (#766)
- Fix `allowCellular` error in iOS for `loadTasksWithRawQuery()` (#803)
- Fix example app crashing (#805)
- fix: apply tasks progress instead of computed progress on pause (#818)
- Fix create application support directory if it doesn't already exist (#815)
- Remove automatic call to `WidgetsFlutterBinding.ensureInitialized()` in
  `FlutterDownloader.initialize()` (#816)
- Fix send message by `int` on port (#817)

## 1.10.1+2

- Minor fix to `publish` GitHub Action (#801)

## 1.10.1+1

- Fix generation of link to release notes on GitHub Releases (#799)

## 1.10.1

- Fix crash when `allowCellular` is null on iOS (#774)

## 1.10.0

- Add `allowCellular` argument to `loadTasksWithRawQuery()` (#765)
- Fix database of download tasks being created in a public directory on iOS
  (#728)
- Add `allowCellular` argument to `DownloadCallback` (#754)

## 1.9.1

- Fix last download progress being wrong on Android (#752)
- Make HTTP timeout configurable on Android (#741)

## 1.9.0

- Migrate the Android part to Kotlin from Java (#719)
- iOS: fix wrong progress and status after pausing download (#743)
- Add missing comma in the README (#744)

## 1.8.4

- Fix `FlutterDownloader.open()` always returning false (#726)

## 1.8.3+2

- Populate `issue_tracker` field in pubspec (#717)

## 1.8.3+1

- Minor updates to README (#715)

## 1.8.3

- Android: revert possibility to set custom notification title introduced in
  #437. This fixes #705

## 1.8.2

- Fix crashing on Flutter 3.3 (#700)
- Improve README (#692)
- Android: make it possible to set custom notification title (#437)

## 1.8.1

- Add optional `step` argument to `FlutterDownloader.registerCallback()` (#435)
- Add `initialized` getter to `FlutterDownloader` (#436)
- Slightly refactor example app (#678 #680)
- iOS: fix unable to cancel task after terminating the app while downloading
  (#658)
- iOS: fix NSRangeException being thrown when columns in the database don't
  match (#661)
- iOS: migrate off deprecated method
  `stringByReplacingPercentEscapesUsingEncoding` (#652)
- Android: add SQLite migration from version 2 to 3 (#667)
- Improve README

## 1.8.0+1

- Fix broken images in README on pub.dev

## 1.8.0

- Bump minimum Flutter version to 3.0

- Bump minimum Dart version to 2.17

- Improve documentation

- Make it possible to disable logging using `FlutterDownloader.initialize(debug:
false)`

## 1.7.4

- fix bug SSL on Android
- merged PRs:
  [#635](https://github.com/fluttercommunity/flutter_downloader/pull/635),
  [#637](https://github.com/fluttercommunity/flutter_downloader/pull/637)

## 1.7.3

- fix bug
  [#614](https://github.com/fluttercommunity/flutter_downloader/issues/614)

## 1.7.2

- fix bug on Android
- upgrade Android dependencies (WorkerManager 2.7.1)

## 1.7.1

- fix bug resume download on Android
- upgrade Android dependencies (WorkerManager 2.7.0-rc01)

## 1.7.0

- support Android 11 (ScopedStorage, PackageVisibility)

## 1.6.1

- fix bug on Android: `getContentLength`
- upgrade Android dependencies (WorkerManager 2.5.0)

## 1.6.0

- Stable version of nullsafety

## 1.6.0-nullsafety.0

- Fix bugs
- Migrate to nullsafety

## 1.5.2

- Android: fix bug notification stuck in processing

## 1.5.1

- iOS: fix bug missing update download progress

## 1.5.0

- Update `pubspec` to new format
- Upgrade `AndroidWorkManager` to v2.4.0

## 1.4.4

- add `debug` (optional) parameter in `initialize()` method that supports
  disable logging to console

## 1.4.3

- iOS: fix bug on `remove` method

## 1.4.2

- add `timeCreated` in `DownloadTask` model
- iOS: fix bug MissingPluginException

## 1.4.1

- Android: fix bug `ensureInitializationComplete must be called after
startInitialization`
- clarify integration documents

## 1.4.0

- migrate to Android v2 embedding.

## 1.3.4

- fix bug stuck in Flutter v12.13
- fix bug on casting int to long value

## 1.3.3

- update document
- assert and make sure FlutterDownloader initialized one time.

## 1.3.2

- correct document and example codes about communication with background isolate

## 1.3.1

- assert the initialization of FlutterDownloader

## 1.3.0

- **BREAKING CHANGES**: the plugin has been refactored to support update
  download events with background isolate. In order to support background
  execution in Dart, the `callback`, that receives events from platform codes,
  now must be a static or top-level function. There's also an additional native
  configuration required on both of iOS and Android. See README for detail.
- Android: upgrade `WorkManager` to v2.2.0.
- Fix bug `SecurityException` when saving image/videos to internal storage in
  Android
- Fix bug cannot save videos in Android.

## 1.2.2

- Android: fix bugs

## 1.2.1

- Android: hot-fix unregister `BroadcastReceiver` in case using
  `FlutterFragmentActivity`

## 1.2.0

- Android: support `FlutterFragmentActivity`, fix bug downloaded image/video
  files not shown in Gallery application, improved HTTP redirection
  implementation, fix bug cannot open apk file in some cases

## 1.1.9

- Android: support HTTP redirection
- iOS: correct getting file name from HTTP response

## 1.1.8

- Fix bug in iOS: from iOS 8, absolute path to app's sandbox changes every time
  you relaunch the app, hence `savedDir` path is needed to truncate the changing
  part before saving it to DB and recreate the absolute path every time it
  loaded from DB. Currently, the plugin only supports save files in
  `NSDocumentDirectory`.
- Fix bug is iOS: setting wrong status of task in case that the application is
  terminated
- Android: upgrade dependencies

## 1.1.7

- Android: upgrade `WorkManager` to version 2.0.0 (AndroidX)

## 1.1.6

- Android: upgrade `WorkManager` to version 1.0.0-beta05
- Android: migrate to AndroidX

## 1.1.5

- Android: upgrade `WorkManager` to version 1.0.0-beta03
- fix bugs

## 1.1.4

- add `remove()` feature to delete task (in DB) and downloaded file as well
  (optional).
- support clean up callback by setting callback as `null` in
  `registerCallback()`
- Android: upgrade `WorkManager` to version 1.0.0-beta01

## 1.1.3

- Android: fix bug NullPointerException of `saveFilePath`

## 1.1.2

- Android: fix typo error
- iOS: catch HTTP status code in case of error

## 1.1.1

- correct `README` instruction

## 1.1.0

- Android: upgrade `WorkManager` library to version v1.0.0-alpha11
- **BREAKING CHANGE**: `initialize()` is removed (to deal with the change of the
  initialization of `WorkManager` in v1.0.0-alpha11). The plugin initializes
  itself with default configurations. If you would like to change the default
  configuration, you can follows the instruction in `README.md`

## 1.0.6

- fix bug related to `filename`

## 1.0.5

- Android: re-config dependencies

## 1.0.4

- Android: upgrade WorkManager to v1.0.0-alpha10

## 1.0.3

- Android: upgrade compile sdk version to 28

## 1.0.2

- Fixed Flutter Community badge.

## 1.0.1

- Moved package to [Flutter Community](https://github.com/fluttercommunity)

## 1.0.0

- **NEW** features: initialize, loadTasksWithRawQuery, pause, resume, retry,
  open
- **IMPORTANT**: the plugin must be initialized by `initialize()` at first
- **BREAKING CHANGE**: `clickToOpenDownloadedFile` now renames to
  `openFileFromNotification` (to prevent confusing from `open` feature). Static
  property `maximumConcurrentTask` has been removed, this configuration now
  moves into `initialize()` method.
- full support SQLite on both Android and iOS side, the plugin now itself
  manages its states persistently and exposes `loadTasksWithRawQuery` api that
  helps developers to load tasks from SQLite database with customized conditions
- support localizing Android notification messages with `messages` parameter of
  `initialize()` method
- full support opening and previewing downloaded file with `open()` method
- (iOS integration) no need to override
  `application:handleEventsForBackgroundURLSession:completionHandler:` manually
  anymore, the plugin now itself takes responsibility for handling it

## 0.1.1

- fix bugs: SQLite leak
- new feature: support configuration of the maximum of concurrent download tasks
- upgrade WorkManager to v1.0.0-alpha08

## 0.1.0

- add: handle click on notification to open downloaded file (for Android)

## 0.0.9

- re-config to support Dart2

## 0.0.8

- upgrade WorkManager to v1.0.0-alpha06
- fix bug: disable sound on notifications

## 0.0.7

- upgrade WorkManager to v1.0.0-alpha04

## 0.0.6

- upgrade WorkManager to v1.0.0-alpha03
- change default value of `showNotification` to `true` (it makes sense on
  Android 8.0 and above, it helps our tasks not to be killed by system when the
  app goes to background)

## 0.0.5

- update metadata

## 0.0.4

- fix bug: Worker finished with FAILURE on Android API 26 and above

## 0.0.3

- support HTTP headers

## 0.0.2

- correct README document

## 0.0.1

- initial release.
