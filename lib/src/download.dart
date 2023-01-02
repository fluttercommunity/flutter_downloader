import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_downloader/src/download_status.dart';

/// The current download status/progress
class Download extends ChangeNotifier implements DownloadProgress {
  Download._({
    required Map<String, String> headers,
    required String url,
    required DownloadTarget target,
    required HttpClient httpClient,
    required MethodChannel methodChannel,
  })  : _headers = headers,
        _url = url,
        _target = target,
        _httpClient = httpClient,
        _methodChannel = methodChannel {
    urlHash = sha1.convert(utf8.encode(url)).toString();
    _cacheFile = File('$urlHash.part');
    _metadataFile = File('$urlHash.meta');
  }

  /// For internal use only
  late final String urlHash;

  /// Create a new download
  static Future<Download> create({
    required String url,
    required MethodChannel methodChannel,
    Map<String, String> headers = const {},
    DownloadTarget target = DownloadTarget.internal,
    HttpClient? customHttpClient,
  }) async {
    final download = Download._(
      headers: headers,
      url: url,
      target: target,
      httpClient: _createHttpClient(),
      methodChannel: methodChannel,
    );
    if (download._metadataFile.existsSync()) {
      var parseHeaders = false;
      for (final row in await download._metadataFile.readAsLines()) {
        if (row == 'headers:') {
          parseHeaders = true;
        } else {
          final delimiter = row.indexOf('=');
          final key = row.substring(0, delimiter - 1);
          final value = row.substring(delimiter + 1);
          if (parseHeaders) {
            download._headers[key] = value;
          } else if (key == 'filename' && value.isNotEmpty) {
            download._filename = value;
          } else if (key == 'etag' && value.isNotEmpty) {
            download._etag = value;
          }
        }
      }
    } else {
      await download._updateMetaData();
    }
    return download;
  }

  static HttpClient _createHttpClient() {
    return HttpClient()..connectionTimeout = const Duration(seconds: 10);
  }

  final String _url;
  final MethodChannel _methodChannel;
  final Map<String, String> _headers;
  final DownloadTarget _target;
  HttpClient _httpClient;
  late final File _cacheFile;
  late final File _metadataFile;
  String? _filename;
  String? _etag;
  bool? _resumable;
  int? _finalSize;

  /// The url of the download
  String get url => _url;

  DownloadStatus _status = DownloadStatus.paused;
  int _progress = 0;

  @override
  DownloadStatus get status => _status;

  @override
  int get progress => _progress;

  Future<void> _updateMetaData() async {
    final writer = _metadataFile.openWrite();
    try {
      writer
        ..write('url=$_url\n')
        ..write('filename=${_filename ?? ''}\n')
        ..write('etag=${_etag ?? ''}\n')
        ..write('target=$_target\n')
        ..write('headers:');
      _headers.forEach((key, value) {
        writer.write('\n$key=$value');
      });
    } finally {
      await writer.close();
    }
  }

  /// Continue the download, does nothing when status is running.
  Future<void> resume() async {
    _status = DownloadStatus.running;
    notifyListeners();
    print('notifyListeners($_status)');
    final request = await _httpClient.getUrl(Uri.parse(_url));
    _headers.forEach((key, value) {
      request.headers.add(key, value);
    });
    IOSink? outStream;
    var hasError = false;
    try {
      final response = await request.close();
      print('Response headers:');
      response.headers.forEach((name, values) async {
        //print('- $name: $values');
        if (name == 'etag') {
          _etag = values.first;
          notifyListeners();
          //print('notifyListeners($_status)');
          await _updateMetaData();
        } else if (name == 'accept-ranges') {
          print('can be continued!');
          _resumable = true;
        } else if (name == 'content-length') {
          print('${values.first} to download');
          _finalSize = int.parse(values.first);
        }
      });
      //Future<void>.delayed(const Duration(milliseconds: 500), () {
      //  _httpClient.close(force: true);
      //  _httpClient = _createHttpClient();
      //  //print('### close called!');
      //});
      outStream = _cacheFile.openWrite(encoding: Encoding.getByName('l1')!);
      var saved = 0;
      final counter = StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (data, sink) {
          sink.add(data);
          saved += data.length;
          if (_finalSize != null) {
            final progress = (saved * 1000) ~/ _finalSize!;
            if (progress != _progress) {
              _progress = progress;
              notifyListeners();
              //print('$_progress‰');
            }
          }
        },
        handleDone: (sink) async {
          print('Saved $saved bytes to cache file ${_cacheFile.absolute}');
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
          _status = _resumable == true ? DownloadStatus.paused : DownloadStatus.failed;
          notifyListeners();
        },
      );
      await response.transform(counter).pipe(outStream!);
    } on HttpException catch (e, trace) {
      //print('### error: $e');
      _status = _resumable == true ? DownloadStatus.paused : DownloadStatus.failed;
      notifyListeners();
    }
  }

  /// Pauses the download when running.
  void pause() {
    _httpClient.close(force: true);
  }

  /// Cancel the download when running or paused
  Future<void> cancel() async {
    _httpClient.close(force: true);
    await delete();
    _status = DownloadStatus.canceled;
    notifyListeners();
  }

  /// Delete the download
  Future<void> delete() async {
    await _cacheFile.delete();
    await _metadataFile.delete();
    _status = DownloadStatus.canceled;
    _progress = 0;
    notifyListeners();
  }
}

class _ObservablePipe extends StreamConsumer<List<int>> {
  _ObservablePipe(this.base);

  final IOSink base;
  late StreamSubscription<List<int>> _subscription;

  @override
  Future addStream(Stream<List<int>> stream) {
    _subscription = stream.listen((data) {
      print('Write ${data.length}bytes');
      try {
        base.writeAll(data);
      } catch (e) {
        base.close();
        _subscription.cancel();
        print('closed');
      }
    });
    //return _subscription;
    return base.addStream(stream);
  }

  @override
  Future close() {
    return base.close();
  }
}
