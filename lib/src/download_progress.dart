import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart';

/// The current download status/progress
class Download extends ChangeNotifier {
  Download._({
    required Map<String, String> headers,
    required String url,
    required Target target,
    required HttpClient httpClient,
  })  : _headers = headers,
        _url = url,
        _target = target,
        _httpClient = httpClient {
    final urlHash = sha1.convert(utf8.encode(url));
    _cacheFile = File('$urlHash.part');
    _metadataFile = File('$urlHash.meta');
  }

  /// Create a new download
  static Future<Download> create({
    Map<String, String> headers = const {},
    required String url,
    Target target = Target.internal,
    HttpClient? customHttpClient,
  }) async {
    final download = Download._(
      headers: headers,
      url: url,
      target: target,
      httpClient: _createHttpClient(),
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

  final Map<String, String> _headers;
  final String _url;
  final Target _target;
  final HttpClient _httpClient;
  late final File _cacheFile;
  late final File _metadataFile;
  String? _filename;
  String? _etag;

  var _status = DownloadTaskStatus.paused;
  var _progress = 0;

  /// The state of the download
  DownloadTaskStatus get status => _status;

  /// The current progress in permille
  int get progress => _progress;

  Future<void> _updateMetaData() async {
    await _metadataFile.writeAsString(
        'url=$_url\nfilename=${_filename ?? ''}\netag=${_etag ?? ''}\ntarget=$_target\nheaders:\n${_headers.entries.map((e) => '${e.key}=${e.value}').join('\n')}'
            .trimRight());
  }

  /// Continue the download, does nothing when status is running.
  Future<void> resume() async {
    _status = DownloadTaskStatus.running;
    notifyListeners();
    await _cacheFile.writeAsString('some content');
    final request = await _httpClient.getUrl(Uri.parse(_url));
    _headers.forEach((key, value) {
      request.headers.add(key, value);
    });
    try {
      final response = await request.close();
      print("Response headers:");
      response.headers.forEach((name, values) {
        print("- $name: $values");
      });
      final stringData = await response.transform(utf8.decoder).join();
      print("Content:");
      print(stringData);
    } finally {
      _httpClient.close();
    }
    //final client = Client();
    //final response = _httpClient.close();
    //response;
  }

  /// Pauses the download when running.
  Future<void> pause() async {}

  /// Cancel the download when running or paused
  Future<void> cancel() async {}
}
