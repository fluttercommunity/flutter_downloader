import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_downloader/src/download_metadata.dart';

/// Factory interface
typedef CustomHttpClientFactory = HttpClient Function();

// ignore_for_file: use_if_null_to_convert_nulls_to_bools
/// The current download status/progress
class DesktopPlatformDownload extends Download {
  /// Create a new DesktopPlatformDownload from a [baseDir], an [id] and its [metadata].
  @protected
  DesktopPlatformDownload({
    required String baseDir,
    required this.id,
    required this.metadata,
  })  : _metadataFile = File('$baseDir/$id.meta'),
        cacheFile = File('$baseDir/$id.part');

  /// Create a new DesktopPlatformDownload from its saved metadata.
  static Future<DesktopPlatformDownload> fromDirectory(
    String baseDir,
    String id,
  ) async =>
      DesktopPlatformDownload(
        baseDir: baseDir,
        id: id,
        metadata: await DownloadMetadata.fromFile(File('$baseDir/$id.meta')),
      );

  /// The sha1 hash of the url used as internal id of the Download
  final String id;
  HttpClient? _httpClient;

  /// The metadata of the download
  @protected
  late final DownloadMetadata metadata;

  final File _metadataFile;

  /// The cache file of the (partial) download
  @protected
  final File cacheFile;

  static HttpClient _createHttpClient() {
    return FlutterDownloader.customHttpClientFactory?.call() ?? HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
  }

  /// The url of the download
  @override
  String get url => metadata.url;

  DownloadStatus _status = DownloadStatus.paused;
  int _progress = 0;

  @override
  DownloadStatus get status => _status;

  // Internal usage only
  @protected
  set status(DownloadStatus status) {
    if (_status != status) {
      _status = status;
      notifyListeners();
    }
  }

  @override
  int get progress => _progress;

  // Internal usage only
  set progress(int permill) {
    if (_progress != permill) {
      _progress = permill;
      notifyListeners();
    }
  }

  /// Persist meta data
  @protected
  Future<void> updateMetaData() => metadata.writeTo(_metadataFile);

  /// Continue the download, does nothing when status is running.
  @override
  Future<void> resume() async {
    status = DownloadStatus.running;
    _httpClient = _createHttpClient();
    final request = await _httpClient!.getUrl(Uri.parse(url));
    metadata.headers.forEach((key, value) {
      request.headers.add(key, value);
    });
    //print('Cachefile: ${_cacheFile.absolute.path}');
    var saved = 0;
    if (metadata.isResumable == true &&
        metadata.contentLength != null &&
        cacheFile.existsSync()) {
      final alreadyDownloaded = await cacheFile.length();
      if (metadata.etag != null) {
        request.headers.add('If-Match', metadata.etag!);
      }
      request.headers.add(
        'Range',
        'bytes=$alreadyDownloaded-${metadata.contentLength}',
      );
      saved = alreadyDownloaded;
    }
    IOSink? outStream;
    var hasError = false;
    try {
      final response = await request.close();
      //print('Response headers:');
      if (response.statusCode == 200) {
        response.headers.forEach((name, values) async {
          //print('- $name: $values');
          if (name == 'etag') {
            metadata.etag = values.first;
            //print('has etag');
            await updateMetaData();
          } else if (name == 'accept-ranges') {
            //print('can be continued!');
            metadata.isResumable = true;
          } else if (name == 'content-length') {
            //print('${values.first} to download');
            metadata.contentLength = int.parse(values.first);
          }
        });
      }
      // Cancel download after timeout for testing:
      //Future<void>.delayed(const Duration(milliseconds: 500), () {
      //  _httpClient.close(force: true);
      //  _httpClient = _createHttpClient();
      //  //print('### close called!');
      //});
      final mode =
          response.statusCode == 206 ? FileMode.append : FileMode.write;
      outStream =
          cacheFile.openWrite(mode: mode, encoding: Encoding.getByName('l1')!);
      final counter = StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (data, sink) {
          sink.add(data);
          saved += data.length;
          if (metadata.contentLength != null) {
            progress = (saved * 1000) ~/ metadata.contentLength!;
          }
        },
        handleDone: (sink) async {
          print('Saved $saved bytes to cache file ${cacheFile.absolute}');
          if (!hasError) {
            _status = DownloadStatus.completed;
          }
          notifyListeners();
          await outStream?.flush();
          await outStream?.close();
          outStream = null;
        },
        handleError: (e, trace, sink) async {
          print('Error: $e');
          sink.close();
          await outStream?.flush();
          await outStream?.close();
          outStream = null;
          hasError = true;
          _status = metadata.isResumable == true
              ? DownloadStatus.paused
              : DownloadStatus.failed;
          notifyListeners();
        },
      );
      await response.transform(counter).pipe(outStream!);
    } on HttpException catch (e, trace) {
      //print('### error: $e');
      _status = metadata.isResumable == true
          ? DownloadStatus.paused
          : DownloadStatus.failed;
      notifyListeners();
    }
  }

  /// Pauses the download when running.
  @override
  Future<void> pause() async {
    print('paused called on DartDownload');
    _httpClient?.close(force: true);
  }

  /// Cancels this download when it's running or paused.
  @override
  Future<void> cancel() async {
    await pause();
    await delete();
    _status = DownloadStatus.canceled;
    notifyListeners();
  }

  /// Deletes this download.
  @override
  Future<bool> delete() async {
    var success = true;
    try {
      if (status == DownloadStatus.running) {
        await pause();
      }
      await cacheFile.delete();
      await _metadataFile.delete();
    } catch (_) {
      success = false;
    }
    _status = DownloadStatus.canceled;
    _progress = 0;
    notifyListeners();
    return success;
  }
}
