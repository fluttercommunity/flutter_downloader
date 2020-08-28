import 'dart:async';
import 'dart:io';

import 'package:black_hole_flutter/black_hole_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

const debug = true;

/// The concept of a file in this app.
/// Don't confuse this with dart:io's File.
class File {
  File(this.name, this.url)
      : assert(name != null),
        assert(url != null);

  final String name;
  final String url;
  DownloadTask task; // Represents a download. Is mutable and null by default.
}

/// A list of example files that can be downloaded by this app.
final _files = [
  File('Learning Android Studio',
      'http://barbra-coco.dyndns.org/student/learning_android_studio.pdf'),
  File('Android Programming Cookbook',
      'http://enos.itcollege.ee/~jpoial/allalaadimised/reading/Android-Programming-Cookbook.pdf'),
  File('iOS Programming Guide',
      'http://darwinlogic.com/uploads/education/iOS_Programming_Guide.pdf'),
  File('Objective-C Programming (Pre-Course Workbook)',
      'https://www.bignerdranch.com/documents/objective-c-prereading-assignment.pdf'),
  File('Arches National Park',
      'https://upload.wikimedia.org/wikipedia/commons/6/60/The_Organ_at_Arches_National_Park_Utah_Corrected.jpg'),
  File('Canyonlands National Park',
      'https://upload.wikimedia.org/wikipedia/commons/7/78/Canyonlands_National_Park%E2%80%A6Needles_area_%286294480744%29.jpg'),
  File('Death Valley National Park',
      'https://upload.wikimedia.org/wikipedia/commons/b/b2/Sand_Dunes_in_Death_Valley_National_Park.jpg'),
  File('Gates of the Arctic National Park and Preserve',
      'https://upload.wikimedia.org/wikipedia/commons/e/e4/GatesofArctic.jpg'),
  File('Big Buck Bunny',
      'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4'),
  File('Elephant Dream',
      'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4'),
];

void main() async {
  await FlutterDownloader.initialize(debug: debug);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Downloader Example',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: StartPage(),
    );
  }
}

/// This page introduces the user into the concept of the app.
class StartPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Downloader Example')),
      body: Center(child: Text("We're gonna download some files.")),
      floatingActionButton: ContinueButton(),
    );
  }
}

class ContinueButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      label: Text('Continue'),
      onPressed: () => _onClick(context),
    );
  }

  Future<void> _onClick(BuildContext context) async {
    // Ensure that the storage permission is granted on Android.
    if (Platform.isAndroid && !await Permission.storage.request().isGranted) {
      context.scaffold.showSnackBar(SnackBar(
        content: Text('You need to grant storage permission so that we '
            'can download files. 😇'),
      ));
      return;
    }

    // Load the existing tasks from the DB and bind matching [File]s to them.
    for (final existingTask in await FlutterDownloader.loadTasks()) {
      // Find the [File] that corresponds to the task. If there is one, set its
      // tasks to the already existing one.
      final task = _files.singleWhere((task) => task.url == existingTask.url,
          orElse: () => null);
      task?.task = existingTask;
    }

    // Push the new page.
    // Note: The new page also uses the [_files]. In production, you probably
    // don't want to solve this with global state, but rather pass an array of
    // files or something similar to the other widget.
    context.navigator.pushReplacement(MaterialPageRoute(
      builder: (_) => DownloadList(),
    ));
  }
}

/// This page shows the downloadable files.
class DownloadList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Downloader Example')),
      body: ListView(children: _files.map((file) => FileWidget(file)).toList()),
    );
  }
}

/// Widget that shows a [File] in the list.
class FileWidget extends StatefulWidget {
  const FileWidget(this.file);

  final File file;

  @override
  _FileWidgetState createState() => _FileWidgetState();
}

class _FileWidgetState extends State<FileWidget> {
  File get file => widget.file;
  DownloadTask get task => file.task;

  @override
  void initState() {
    super.initState();
    // Update this widget whenever the download task's status updates.
    task?.updates?.listen((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    Widget trailing;
    if (task == null) {
      trailing = IconButton(
        icon: Icon(Icons.file_download),
        onPressed: () async {
          file.task = await DownloadTask.create(
            url: file.url,
            downloadDirectory: Platform.isAndroid
                ? await getExternalStorageDirectory()
                : await getApplicationDocumentsDirectory(),
          );
          // Update this widget when the task status updates.
          task?.updates?.listen((_) => setState(() {}));
        },
      );
    } else if (task.isRunning) {
      trailing = IconButton(icon: Icon(Icons.pause), onPressed: task.pause);
    } else if (task.isPaused) {
      trailing =
          IconButton(icon: Icon(Icons.play_arrow), onPressed: task.resume);
    } else if (task.hasFailed || task.gotCanceled) {
      trailing = IconButton(icon: Icon(Icons.refresh), onPressed: task.retry);
    } else if (task.isCompleted) {
      trailing =
          IconButton(icon: Icon(Icons.open_in_new), onPressed: task.openFile);
    } else if (task.isEnqueued) {
      trailing = Icon(Icons.schedule);
    } else if (task.hasUndefinedStatus) {
      trailing = Icon(Icons.help_outline);
    }

    return ListTile(
      title: Text(file.name),
      subtitle: task == null
          ? Text(file.url)
          : task.isRunning || task.isPaused
              ? LinearProgressIndicator(value: task.progress)
              : Text(task.hasFailed
                  ? 'failed'
                  : task.gotCanceled ? 'canceled' : file.url),
      trailing: trailing ?? Container(),
    );
  }
}
