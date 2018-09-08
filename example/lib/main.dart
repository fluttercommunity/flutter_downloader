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
    {
      'name': 'Learning Android Studio',
      'link': 'http://barbra-coco.dyndns.org/student/learning_android_studio.pdf'
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

  final _images = [
    {
      'name': 'Arches National Park',
      'link':
          'https://upload.wikimedia.org/wikipedia/commons/6/60/The_Organ_at_Arches_National_Park_Utah_Corrected.jpg'
    },
    {
      'name': 'Canyonlands National Park',
      'link':
          'https://upload.wikimedia.org/wikipedia/commons/7/78/Canyonlands_National_Park%E2%80%A6Needles_area_%286294480744%29.jpg'
    },
    {
      'name': 'Death Valley National Park',
      'link':
          'https://upload.wikimedia.org/wikipedia/commons/b/b2/Sand_Dunes_in_Death_Valley_National_Park.jpg'
    },
    {
      'name': 'Gates of the Arctic National Park and Preserve',
      'link':
          'https://upload.wikimedia.org/wikipedia/commons/e/e4/GatesofArctic.jpg'
    }
  ];

  final _videos = [
    {
      'name': 'Big Buck Bunny',
      'link':
          'https://www.sample-videos.com/video/mp4/720/big_buck_bunny_720p_30mb.mp4'
    },
    {
      'name': 'Star Trails',
      'link':
          'http://mirrors.standaloneinstaller.com/video-sample/star_trails.mp4'
    }
  ];

  List<_TaskInfo> _tasks;
  List<_ItemHolder> _items;
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
      body: Builder(
          builder: (context) => _isLoading
              ? new Center(
                  child: new CircularProgressIndicator(),
                )
              : new Container(
                  child: new ListView(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    children: _items
                        .map((item) => item.task == null
                            ? new Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 8.0),
                                child: Text(
                                  item.name,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                      fontSize: 18.0),
                                ),
                              )
                            : new Container(
                                padding: const EdgeInsets.only(
                                    left: 16.0, right: 8.0),
                                child: InkWell(
                                  onTap: item.task.status ==
                                          DownloadTaskStatus.complete
                                      ? () {
                                          _openDownloadedFile(item.task)
                                              .then((success) {
                                            if (!success) {
                                              Scaffold.of(context).showSnackBar(
                                                  SnackBar(
                                                      content: Text(
                                                          'Cannot open this file')));
                                            }
                                          });
                                        }
                                      : null,
                                  child: new Stack(
                                    children: <Widget>[
                                      new Container(
                                        width: double.infinity,
                                        height: 64.0,
                                        child: new Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: <Widget>[
                                            new Expanded(
                                              child: new Text(
                                                item.name,
                                                maxLines: 1,
                                                softWrap: true,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            new Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 8.0),
                                              child: _buildActionForTask(
                                                  item.task),
                                            ),
                                          ],
                                        ),
                                      ),
                                      item.task.status ==
                                                  DownloadTaskStatus.running ||
                                              item.task.status ==
                                                  DownloadTaskStatus.paused
                                          ? new Positioned(
                                              left: 0.0,
                                              right: 0.0,
                                              bottom: 0.0,
                                              child:
                                                  new LinearProgressIndicator(
                                                value: item.task.progress / 100,
                                              ),
                                            )
                                          : new Container()
                                    ].where((child) => child != null).toList(),
                                  ),
                                ),
                              ))
                        .toList(),
                  ),
                )),
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
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          new Text('Failed', style: new TextStyle(color: Colors.red)),
          RawMaterialButton(
            onPressed: () {
              _retryDownload(task);
            },
            child: Icon(
              Icons.refresh,
              color: Colors.green,
            ),
            shape: new CircleBorder(),
            constraints: new BoxConstraints(minHeight: 32.0, minWidth: 32.0),
          )
        ],
      );
    } else {
      return null;
    }
  }

  void _requestDownload(_TaskInfo task) async {
    task.taskId = await FlutterDownloader.enqueue(
        url: task.link,
        savedDir: _localPath,
        showNotification: true,
        openFileFromNotification: false);
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

  void _retryDownload(_TaskInfo task) async {
    String newTaskId = await FlutterDownloader.retry(taskId: task.taskId);
    task.taskId = newTaskId;
  }

  Future<bool> _openDownloadedFile(_TaskInfo task) {
    return FlutterDownloader.open(taskId: task.taskId);
  }

  Future<Null> _prepare() async {
    final tasks = await FlutterDownloader.loadTasks();

    final successTasks = await FlutterDownloader.loadTasksWithRawQuery(query: 'SELECT * FROM task WHERE status=3');

    int count = 0;
    _tasks = [];
    _items = [];

    _tasks.addAll(_documents.map((document) =>
        _TaskInfo(name: document['name'], link: document['link'])));

    _items.add(_ItemHolder(name: 'Documents'));
    for (int i = count; i < _tasks.length; i++) {
      _items.add(_ItemHolder(name: _tasks[i].name, task: _tasks[i]));
      count++;
    }

    _tasks.addAll(_images
        .map((image) => _TaskInfo(name: image['name'], link: image['link'])));

    _items.add(_ItemHolder(name: 'Images'));
    for (int i = count; i < _tasks.length; i++) {
      _items.add(_ItemHolder(name: _tasks[i].name, task: _tasks[i]));
      count++;
    }

    _tasks.addAll(_videos
        .map((video) => _TaskInfo(name: video['name'], link: video['link'])));

    _items.add(_ItemHolder(name: 'Videos'));
    for (int i = count; i < _tasks.length; i++) {
      _items.add(_ItemHolder(name: _tasks[i].name, task: _tasks[i]));
      count++;
    }

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

class _ItemHolder {
  final String name;
  final _TaskInfo task;

  _ItemHolder({this.name, this.task});
}
