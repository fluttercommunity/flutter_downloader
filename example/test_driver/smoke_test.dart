import 'dart:async';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart';

void main() {
  group('Smoke test', () {
    FlutterDriver driver;

    setUpAll(() async {
      driver = await FlutterDriver.connect();
    });

    tearDownAll(() async {
      if (driver != null) {
        driver.close();
      }
    });

    test('Download', () async {
      await driver.waitFor(find.byValueKey('download-iOS Programming Guide'));
      await driver.tap(find.byValueKey('download-iOS Programming Guide'));
      await Future.delayed(Duration(milliseconds: 500));
    });

    test('Pause', () async {
      await driver.waitFor(find.byValueKey('pause-iOS Programming Guide'));
      await driver.tap(find.byValueKey('pause-iOS Programming Guide'));
      await Future.delayed(Duration(milliseconds: 500));
    });

    test('Resume', () async {
      await driver.waitFor(find.byValueKey('resume-iOS Programming Guide'));
      await driver.tap(find.byValueKey('resume-iOS Programming Guide'));
      await Future.delayed(Duration(milliseconds: 500));
    });

    test('Ready', () async {
      await driver.waitFor(find.byValueKey('ready-iOS Programming Guide'),
          timeout: Duration(seconds: 30));
    });

    test('Auth header', () async {
      await driver.waitFor(find.byValueKey('download-Authentication Test'));
      await driver.tap(find.byValueKey('download-Authentication Test'));
      await driver.waitFor(find.byValueKey('ready-Authentication Test'));
    });

    test('Wrong auth header', () async {
      await driver
          .waitFor(find.byValueKey('download-Authentication Test - wrong pw'));
      await driver
          .tap(find.byValueKey('download-Authentication Test - wrong pw'));
      await driver
          .waitFor(find.byValueKey('failed-Authentication Test - wrong pw'));
    });
  });
}
