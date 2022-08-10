import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_downloader_example/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterDownloader.initialize(debug: true, ignoreSsl: true);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const _title = 'flutter_downloader demo';

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;

    return MaterialApp(
      title: _title,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: MyHomePage(
        title: _title,
        platform: platform,
      ),
    );
  }
}
