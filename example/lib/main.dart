import 'dart:math';

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

void main() async {
  await FlutterDownloader.initialize();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Downloader Example',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: StartScreen(),
    );
  }
}

class StartScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Downloader Example')),
      body: Center(child: Text("We're gonna download kitten pictures.")),
      floatingActionButton: ContinueButton(),
    );
  }
}

class ContinueButton extends StatelessWidget {
  Future<void> _continue(BuildContext context) async {
    if (Platform.isAndroid) {
      final handler = PermissionHandler();
      final permission =
          await handler.checkPermissionStatus(PermissionGroup.storage);
      if (permission != PermissionStatus.granted) {
        final permissions =
            await handler.requestPermissions([PermissionGroup.storage]);
        if (permissions[PermissionGroup.storage] != PermissionStatus.granted) {
          Scaffold.of(context).showSnackBar(SnackBar(
            content: Text('You need to grant storage permission so that we '
                'can download kitten pictures. 😇'),
          ));
          return;
        }
      }
    }

    // Permission granted.
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => DownloadList(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => _continue(context),
      label: Text('Continue'),
    );
  }
}

class DownloadList extends StatefulWidget {
  @override
  _DownloadListState createState() => _DownloadListState();
}

class _DownloadListState extends State<DownloadList> {
  List<DownloadTask> tasks = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Downloader Example')),
      body: ListView(
        children: <Widget>[
          for (final task in tasks) DownloadTaskWidget(task),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          var random = () => Random().nextInt(5000) + 1;
          final task = await DownloadTask.create(
            url: 'https://placekitten.com/${random()}/${random()}',
            downloadDirectory: Platform.isAndroid
                ? await getExternalStorageDirectory()
                : await getApplicationDocumentsDirectory(),
          );
          setState(() => tasks.add(task));
        },
        child: Icon(Icons.add),
      ),
    );
  }
}

class DownloadTaskWidget extends StatelessWidget {
  const DownloadTaskWidget(this.task);

  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DownloadTask>(
      stream: task.updates,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return ListTile(title: Text('Creating DownloadTask…'));
        }

        Widget trailing;
        if (task.isRunning) {
          trailing = IconButton(icon: Icon(Icons.pause), onPressed: task.pause);
        } else if (task.isPaused) {
          trailing =
              IconButton(icon: Icon(Icons.play_arrow), onPressed: task.resume);
        } else if (task.hasFailed || task.gotCanceled) {
          trailing =
              IconButton(icon: Icon(Icons.refresh), onPressed: task.retry);
        } else if (task.isCompleted) {
          trailing = IconButton(
              icon: Icon(Icons.open_in_new), onPressed: task.openFile);
        } else if (task.isEnqueued) {
          trailing = Icon(Icons.schedule);
        } else if (task.hasUndefinedStatus) {
          trailing = Icon(Icons.help_outline);
        }

        return ListTile(
          title: Text('${task.url}'),
          subtitle: Row(
            children: <Widget>[
              Text('${task.status}'),
              Expanded(child: LinearProgressIndicator(value: task.progress)),
            ],
          ),
          trailing: trailing ?? Container(),
        );
      },
    );
  }
}
