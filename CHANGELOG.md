## 0.0.1

* initial release.

## 0.0.2

* correct README document

## 0.0.3

* support HTTP headers

## 0.0.4

* fix bug: Worker finished with FAILURE on Android API 26 and above

## 0.0.5

* update metadata

## 0.0.6

* upgrade WorkManager to v1.0.0-alpha03
* change default value of `showNotification` to `true` (it makes sense on Android 8.0 and above, it helps our tasks not to be killed by system when the app goes to background)

## 0.0.7

* upgrade WorkManager to v1.0.0-alpha04

## 0.0.8

* upgrade WorkManager to v1.0.0-alpha06
* fix bug: disable sound on notifications

## 0.0.9

* re-config to support Dart2

## 0.1.0

* add: handle click on notification to open downloaded file (for Android)

## 0.1.1

* fix bugs: SQLite leak
* new feature: support configuration of the maximum of concurrent download tasks
* upgrade WorkManager to v1.0.0-alpha08

## 1.0.0

* **NEW** features: initialize, loadTasksWithRawQuery, pause, resume, retry, open
* **IMPORTANT**: the plugin must be initialized by `initialize()` at first
* **BREAKING CHANGE**: `clickToOpenDownloadedFile` now renames to `openFileFromNotification` (to prevent confusing from `open` feature)
* full support SQLite on both Android and iOS side, the plugin now itself manages its states persistently and exposes `loadTasksWithRawQuery' api that helps developers to load tasks from SQLite database with customized conditions
* support localizing Android notification messages with `messages` parameter of `initialize()` method
* full support opening and previewing downloaded file with `open()` method   