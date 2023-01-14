import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart';

/// Factory interface
typedef CustomHttpClientFactory = HttpClient Function();

// ignore_for_file: use_if_null_to_convert_nulls_to_bools
/// The current download status/progress
class DartDownload extends Download {
  /// Create a new DartDownload
  @protected
  DartDownload({
    required String baseDir,
    required this.headers,
    required String url,
    required DownloadTarget target,
  })  : _url = url,
        _target = target {
    urlHash = sha1.convert(utf8.encode(url)).toString();
    cacheFile = File('$baseDir/$urlHash.part');
    metadataFile = File('$baseDir/$urlHash.meta');
  }

  /// For internal use only
  late final String urlHash;
  final String _url;
  final DownloadTarget _target;
  HttpClient? _httpClient;

  /// The request headers
  @protected
  final Map<String, String> headers;

  /// The cache file of the (partial) download
  @protected
  late final File cacheFile;

  /// The persisted meta data file
  @protected
  late final File metadataFile;

  /// The filename which should be used for the filesystem
  @protected
  String? filename;

  /// The etag if given to resume the download
  @protected
  String? etag;

  /// True when the server supports resuming
  @protected
  bool? resumable;

  /// The file size of the file to download
  @protected
  int? finalSize;

  static HttpClient _createHttpClient() {
    return FlutterDownloader.customHttpClientFactory?.call() ?? HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
  }

  /// The url of the download
  @override
  String get url => _url;

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
  Future<void> updateMetaData() async {
    final writer = metadataFile.openWrite();
    try {
      writer
        ..write('url=$_url\n')
        ..write('target=${_target.name}\n');
      if (filename?.isNotEmpty == true) {
        writer.write('filename=$filename\n');
      }
      if (etag?.isNotEmpty == true) {
        writer.write('etag=$etag\n');
      }
      if (finalSize != null && finalSize! > 0) {
        writer.write('size=$finalSize\n');
      }
      if (resumable != null) {
        writer.write('resumable=$resumable\n');
      }
      writer.write('headers:');
      headers.forEach((key, value) {
        writer.write('\n$key=$value');
      });
    } finally {
      await writer.close();
    }
  }

  /// Continue the download, does nothing when status is running.
  @override
  Future<void> resume() async {
    status = DownloadStatus.running;
    _httpClient = _createHttpClient();
    final request = await _httpClient!.getUrl(Uri.parse(_url));
    headers.forEach((key, value) {
      request.headers.add(key, value);
    });
    //print('Cachefile: ${_cacheFile.absolute.path}');
    var saved = 0;
    if (resumable == true && finalSize != null && cacheFile.existsSync()) {
      final alreadyDownloaded = await cacheFile.length();
      if (etag != null) {
        request.headers.add('If-Match', etag!);
      }
      request.headers.add('Range', 'bytes=$alreadyDownloaded-$finalSize');
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
            etag = values.first;
            //print('has etag');
            await updateMetaData();
          } else if (name == 'accept-ranges') {
            //print('can be continued!');
            resumable = true;
          } else if (name == 'content-length') {
            //print('${values.first} to download');
            finalSize = int.parse(values.first);
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
          if (finalSize != null) {
            progress = (saved * 1000) ~/ finalSize!;
          }
        },
        handleDone: (sink) async {
          print('Saved $saved bytes to cache file ${cacheFile.absolute}');
          if (!hasError) {
            _status = DownloadStatus.complete;
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
          _status =
              resumable == true ? DownloadStatus.paused : DownloadStatus.failed;
          notifyListeners();
        },
      );
      await response.transform(counter).pipe(outStream!);
    } on HttpException catch (e, trace) {
      //print('### error: $e');
      _status =
          resumable == true ? DownloadStatus.paused : DownloadStatus.failed;
      notifyListeners();
    }
  }

  /// Pauses the download when running.
  @override
  Future<void> pause() async {
    _httpClient?.close(force: true);
  }

  /// Cancel the download when running or paused
  @override
  Future<void> cancel() async {
    _httpClient?.close(force: true);
    await delete();
    _status = DownloadStatus.canceled;
    notifyListeners();
  }

  /// Delete the download
  @override
  Future<bool> delete() async {
    var success = true;
    try {
      if (status == DownloadStatus.running) {
        await pause();
      }
      await cacheFile.delete();
      await metadataFile.delete();
    } catch (_) {
      success = false;
    }
    _status = DownloadStatus.canceled;
    _progress = 0;
    notifyListeners();
    return success;
  }
}
