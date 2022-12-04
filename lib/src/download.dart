import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_downloader/flutter_downloader.dart';

/// The current download status/progress
class Download extends ChangeNotifier {
  Download._({
    required Map<String, String> headers,
    required String url,
    required Target target,
    required HttpClient httpClient,
    required MethodChannel methodChannel,
  })  : _headers = headers,
        _url = url,
        _target = target,
        _httpClient = httpClient,
        _methodChannel = methodChannel {
    final urlHash = sha1.convert(utf8.encode(url));
    _cacheFile = File('$urlHash.part');
    _metadataFile = File('$urlHash.meta');
  }

  /// Create a new download
  static Future<Download> create({
    required String url,
    required MethodChannel methodChannel,
    Map<String, String> headers = const {},
    Target target = Target.internal,
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
  final Target _target;
  final HttpClient _httpClient;
  late final File _cacheFile;
  late final File _metadataFile;
  String? _filename;
  String? _etag;

  /// The url of the download
  String get url => _url;

  var _status = DownloadTaskStatus.paused;
  var _progress = 0;

  /// The state of the download
  DownloadTaskStatus get status => _status;

  /// The current progress in permille [0...1000]
  int get progress => _progress;

  Future<void> _updateMetaData() async {
    final writer = _metadataFile.openWrite()
      ..write('url=$_url\n')
      ..write('filename=${_filename ?? ''}\n')
      ..write('etag=${_etag ?? ''}\n')
      ..write('target=$_target\n')
      ..write('headers:');
    _headers.forEach((key, value) {
      writer.write('\n$key=$value');
    });
    await writer.close();
  }

  /// Continue the download, does nothing when status is running.
  Future<void> resume() async {
    _status = DownloadTaskStatus.running;
    notifyListeners();
    final request = await _httpClient.getUrl(Uri.parse(_url));
    _headers.forEach((key, value) {
      request.headers.add(key, value);
    });
    try {
      final response = await request.close();
      print('Response headers:');
      response.headers.forEach((name, values) {
        print('- $name: $values');
      });
      await response.pipe(_cacheFile.openWrite());
      print('Content written to cache file ${_cacheFile.absolute}');
      //print('Content:');
      //print(stringData);
    } finally {
      _httpClient.close();
    }
  }

  /// Pauses the download when running.
  Future<void> pause() async {}

  /// Cancel the download when running or paused
  Future<void> cancel() async {}

  /// Delete the download
  Future<void> delete() async {
    await _cacheFile.delete();
    await _metadataFile.delete();
  }
}
