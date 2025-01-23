/// Provides the capability of creating and managing background download tasks.
///
/// This plugin depends on native APIs to run background tasks (WorkManager on
/// Android and NSURLSessionDownloadTask on iOS).
///
/// All information about download tasks is saved in an SQLite database. It
/// gives a Flutter application benefit of either getting rid of managing task
/// information manually or querying task data with SQL statements easily.
///
/// * author: hunghd
/// * email: hunghd.yb@gmail.com
library;

export 'src/downloader.dart';
export 'src/exceptions.dart';
export 'src/models.dart';
