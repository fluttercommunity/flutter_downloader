import 'dart:io';

import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('example.com download', isolated((testDir) async {
    const sampleUrl = 'https://www.example.com';
    const sampleUrlHash = '740e7397907c0b004010d92b33d283e98f74063d';
      await FlutterDownloader().startDownload(sampleUrl);
      final metaFile = File('${testDir.path}/$sampleUrlHash.meta');
      assert(metaFile.existsSync());
  }),);
}

/// Run a test in a temp directory, which will be deleted after the execution.
dynamic Function() isolated(Future<dynamic> Function(Directory testDir) body) {
  return () async {
    final originalDirectory = Directory.current;
    final testDir = await Directory.systemTemp.createTemp('test');
    Directory.current = testDir;
    try {
      return await body(testDir);
    } finally {
      Directory.current = originalDirectory;
      await testDir.delete(recursive: true);
    }
  };
}
