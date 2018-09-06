import 'package:flutter/material.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'dart:convert';
import 'dart:io';

void main() {
  FlutterDownloader.initialize(maxConcurrentTasks: 3);
  runApp(new MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Flutter Demo',
      theme: new ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: new MyHomePage(title: 'Downloader'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => new _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  final _documents = [
//    {
//      'name': 'Beginning Android Application Development',
//      'link': 'http://www.kmvportal.co.in/Course/MAD/Android%20Book.pdf'
//    },
    {
      'name': 'Android Programming Cookbook',
      'link':
      'http://enos.itcollege.ee/~jpoial/allalaadimised/reading/Android-Programming-Cookbook.pdf'
    },
    {
      'name': 'iOS Programming Guide',
      'link':
      'http://darwinlogic.com/uploads/education/iOS_Programming_Guide.pdf'
    },
    {
      'name': 'Objective-C Programming (Pre-Course Workbook',
      'link':
      'https://www.bignerdranch.com/documents/objective-c-prereading-assignment.pdf'
    }
  ];

  List<_TaskInfo> _tasks;
  bool _isLoading;
  String _localPath;

  @override
  void initState() {
    super.initState();

    FlutterDownloader.registerCallback((id, status, progress) {
      print(
          'Download task ($id) is in status ($status) and process ($progress)');
      final task = _tasks.firstWhere((task) => task.taskId == id);
      setState(() {
        task?.status = status;
        task?.progress = progress;
      });
    });

    _isLoading = true;
    _prepare();
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text(widget.title),
      ),
      body: _isLoading
          ? new Center(
        child: new CircularProgressIndicator(),
      )
          : new Container(
        child: new ListView(
          children: _tasks
              .map((task) =>
          new Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: new Stack(
              children: <Widget>[
                new Container(
                  width: double.infinity,
                  height: 64.0,
                  child: new Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      new Expanded(
                        child: new Text(
                          task.name,
                          maxLines: 1,
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      new Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: _buildActionForTask(task),
                      ),
                    ],
                  ),
                ),
                task.status == DownloadTaskStatus.running ||
                    task.status == DownloadTaskStatus.paused
                    ? new Positioned(
                  left: 0.0,
                  right: 0.0,
                  bottom: 0.0,
                  child: new LinearProgressIndicator(
                    value: task.progress / 100,
                  ),
                )
                    : new Container()
              ].where((child) => child != null).toList(),
            ),
          ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildActionForTask(_TaskInfo task) {
    if (task.status == DownloadTaskStatus.undefined) {
      return new RawMaterialButton(
        onPressed: () {
          _requestDownload(task);
        },
        child: new Icon(Icons.file_download),
        shape: new CircleBorder(),
        constraints: new BoxConstraints(minHeight: 32.0, minWidth: 32.0),
      );
    } else if (task.status == DownloadTaskStatus.running) {
      return new RawMaterialButton(
        onPressed: () {
          _pauseDownload(task);
        },
        child: new Icon(
          Icons.pause,
          color: Colors.red,
        ),
        shape: new CircleBorder(),
        constraints: new BoxConstraints(minHeight: 32.0, minWidth: 32.0),
      );
    } else if (task.status == DownloadTaskStatus.paused) {
      return new RawMaterialButton(
        onPressed: () {
          _resumeDownload(task);
        },
        child: new Icon(
          Icons.play_arrow,
          color: Colors.green,
        ),
        shape: new CircleBorder(),
        constraints: new BoxConstraints(minHeight: 32.0, minWidth: 32.0),
      );
    } else if (task.status == DownloadTaskStatus.complete) {
      return new Text(
        'Ready',
        style: new TextStyle(color: Colors.green),
      );
    } else if (task.status == DownloadTaskStatus.canceled) {
      return new Text('Canceled', style: new TextStyle(color: Colors.red));
    } else if (task.status == DownloadTaskStatus.failed) {
      return new Text('Failed', style: new TextStyle(color: Colors.red));
    } else {
      return null;
    }
  }

  void _requestDownload(_TaskInfo task) async {
    task.taskId = await FlutterDownloader.enqueue(
        url: task.link,
        savedDir: _localPath,
        showNotification: true,
        clickToOpenDownloadedFile: false);
  }

  void _cancelDownload(_TaskInfo task) async {
    await FlutterDownloader.cancel(taskId: task.taskId);
  }

  void _pauseDownload(_TaskInfo task) async {
    await FlutterDownloader.pause(taskId: task.taskId);
  }

  void _resumeDownload(_TaskInfo task) async {
    String newTaskId = await FlutterDownloader.resume(taskId: task.taskId);
    task.taskId = newTaskId;
  }

  Future<Null> _prepare() async {
    final tasks = await FlutterDownloader.loadTasks();

    _tasks = _documents
        .map((document) =>
        _TaskInfo(name: document['name'], link: document['link']))
        .toList();
    tasks?.forEach((task) {
      for (_TaskInfo info in _tasks) {
        if (info.link == task.url) {
          info.taskId = task.taskId;
          info.status = task.status;
          info.progress = task.progress;
        }
      }
    });

    _localPath = await _findLocalPath();

    setState(() {
      _isLoading = false;
    });
  }

}

Future<String> _findLocalPath() async {
  final directory = await getApplicationDocumentsDirectory();
  return directory.path;
}

class _TaskInfo {
  final String name;
  final String link;

  String taskId;
  int progress = 0;
  DownloadTaskStatus status = DownloadTaskStatus.undefined;

  _TaskInfo({this.name, this.link});
}
