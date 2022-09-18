import 'dart:io';

import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('example test', () async {
    var testDir = await Directory.systemTemp.createTemp('test');
    Directory.current = testDir;
    print(Directory.current.path);
    const sampleUrl = 'https://www.example.com';
    const sampleUrlHash = '740e7397907c0b004010d92b33d283e98f74063d';
    try {
      final example = await FlutterDownloader().startDownload(sampleUrl);
      final metaFile = File('${testDir.path}/$sampleUrlHash.meta');
      assert(metaFile.existsSync());
    } finally {
      Directory.current = testDir.parent;
      await testDir.delete(recursive: true);
    }
  });
}
