import 'package:flutter/material.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'dart:convert';
import 'dart:io';

void main() => runApp(new MyApp());

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
    {
      'name': 'Beginning Android Application Development',
      'link': 'http://www.kmvportal.co.in/Course/MAD/Android%20Book.pdf'
    },
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

    WidgetsBinding.instance.addObserver(this);

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

    _loadTasks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('AppLifecycleState changed: $state');
    if (state == AppLifecycleState.paused) {
      _saveDocuments();
    }
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
                    .map((task) => new Container(
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
                              task.status == DownloadTaskStatus.running
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
          _cancelDownload(task);
        },
        child: new Icon(
          Icons.stop,
          color: Colors.red,
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
    );
  }

  void _cancelDownload(_TaskInfo task) async {
    await FlutterDownloader.cancel(taskId: task.taskId);
  }

  Future<String> _findLocalPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<Null> _loadTasks() async {
    final path = _localPath ?? await _findLocalPath();
    _localPath = path;
    final file = new File('$path/tasks.json');
    final fileExisted = await file.exists();
    if (fileExisted) {
      final taskJson = await file.readAsString();
      final List<dynamic> array = json.decode(taskJson);
      if (array != null) {
        _tasks = array.map((item) => new _TaskInfo.fromJson(item)).toList();
        final tasks = await FlutterDownloader.loadTasks();
        for (final task in tasks) {
          _tasks.firstWhere((item) => item.taskId == task.taskId)
            ..status = task.status
            ..progress = task.progress;
        }
      } else {
        _tasks = _documents
            .map((document) =>
                _TaskInfo(name: document['name'], link: document['link']))
            .toList();
      }
    } else {
      _tasks = _documents
          .map((document) =>
              _TaskInfo(name: document['name'], link: document['link']))
          .toList();
    }
    setState(() {
      _isLoading = false;
    });
  }

  _saveDocuments() {
    final path = _localPath;
    final file = new File('$path/tasks.json');
    final fileExisted = file.existsSync();
    if (!fileExisted) {
      file.createSync();
    }
    file.writeAsStringSync(json.encode(_tasks));
  }
}

class _TaskInfo {
  final String name;
  final String link;

  String taskId;
  int progress = 0;
  DownloadTaskStatus status = DownloadTaskStatus.undefined;

  _TaskInfo({this.name, this.link});

  _TaskInfo.fromJson(Map<String, dynamic> json)
      : name = json['name'],
        link = json['link'],
        taskId = json['task_id'],
        progress = json['progress'] ?? 0,
        status = DownloadTaskStatus.from(json['status'] ?? 0);

  Map<String, dynamic> toJson() => {
        'name': name,
        'link': link,
        'task_id': taskId,
        'progress': progress,
        'status': status.value
      };
}
