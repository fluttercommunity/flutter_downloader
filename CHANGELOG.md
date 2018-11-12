## 1.1.0 - 12.11.2018

* Android: upgrade `WorkManager` library to version v1.0.0-alpha11
* **BREAKING CHANGE**: `initialize()` is removed (to deal with the change of the initialization of `WorkManager` in v1.0.0-alpha11). The plugin initializes itself with default configurations. If you would like to change the default configuration, you can follows the instruction in `README.md`

## 1.0.6 - 28.10.2018

* fix bug related to `filename`

## 1.0.5 - 22.10.2018

* Android: re-config dependencies

## 1.0.4 - 20.10.2018

* Android: upgrade WorkManager to v1.0.0-alpha10

## 1.0.3 - 29.09.2018

* Android: upgrade compile sdk version to 28

## 1.0.2 - 20.09.2018

* Fixed Flutter Community badge.

## 1.0.1 - 20.09.2018

* Moved package to [Flutter Community](https://github.com/fluttercommunity)

## 1.0.0 - 09.09.2018

* **NEW** features: initialize, loadTasksWithRawQuery, pause, resume, retry, open
* **IMPORTANT**: the plugin must be initialized by `initialize()` at first
* **BREAKING CHANGE**: `clickToOpenDownloadedFile` now renames to `openFileFromNotification` (to prevent confusing from `open` feature). Static property `maximumConcurrentTask` has been removed, this configuration now moves into `initialize()` method.
* full support SQLite on both Android and iOS side, the plugin now itself manages its states persistently and exposes `loadTasksWithRawQuery` api that helps developers to load tasks from SQLite database with customized conditions
* support localizing Android notification messages with `messages` parameter of `initialize()` method
* full support opening and previewing downloaded file with `open()` method
* (iOS integration) no need to override `application:handleEventsForBackgroundURLSession:completionHandler:` manually anymore, the plugin now itself takes responsibility for handling it

## 0.1.1 - 29.08.2018

* fix bugs: SQLite leak
* new feature: support configuration of the maximum of concurrent download tasks
* upgrade WorkManager to v1.0.0-alpha08

## 0.1.0 - 12.08.2018

* add: handle click on notification to open downloaded file (for Android)

## 0.0.9 - 10.08.2018

* re-config to support Dart2

## 0.0.8 - 10.08.2018

* upgrade WorkManager to v1.0.0-alpha06
* fix bug: disable sound on notifications

## 0.0.7 - 28.06.2018

* upgrade WorkManager to v1.0.0-alpha04

## 0.0.6 - 28.06.2018

* upgrade WorkManager to v1.0.0-alpha03
* change default value of `showNotification` to `true` (it makes sense on Android 8.0 and above, it helps our tasks not to be killed by system when the app goes to background)

## 0.0.5 - 22.06.2018

* update metadata

## 0.0.4 - 15.06.2018

* fix bug: Worker finished with FAILURE on Android API 26 and above

## 0.0.3 - 11.06.2018

* support HTTP headers

## 0.0.2 - 08.06.2018

* correct README document

## 0.0.1 - 07.06.2018

* initial release.
