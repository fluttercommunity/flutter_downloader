import 'dart:io';

import 'package:android_path_provider/android_path_provider.dart';
import 'package:collection/collection.dart';
import 'package:device_info/device_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_downloader_example/data.dart';
import 'package:flutter_downloader_example/download_list_item.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:windows_taskbar/windows_taskbar.dart';

class MyHomePage extends StatefulWidget with WidgetsBindingObserver {
  MyHomePage({super.key, required this.title, required this.platform});

  final TargetPlatform? platform;

  final String title;

  final downloader = FlutterDownloader();

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<ItemHolder> _items = [];
  late bool _loading;
  late bool _permissionReady;
  late String _localPath;

  @override
  void initState() {
    super.initState();

    _loading = true;
    _permissionReady = Platform.isWindows;

    _prepare();
  }

  Widget _buildDownloadList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: _items.length,
      itemBuilder: (context, index) => _items[index].headline != null
          ? _buildListSectionHeading(_items[index].headline!)
          : DownloadListItem(
              data: _items[index],
              onTap: (task) async {
                final success = await _openDownloadedFile(task);
                if (!success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cannot open this file')),
                  );
                }
              },
              onActionTap: (item) async {
                if (item.download == null) {
                  item.download =
                      await widget.downloader.startDownload(item.metaInfo!.url);
                  item.download?.addListener(() {
                    if (Platform.isWindows) {
                      switch (item.download!.status) {
                        case DownloadStatus.running:
                          WindowsTaskbar.setProgressMode(
                            TaskbarProgressMode.indeterminate,
                          );
                          break;
                        case DownloadStatus.paused:
                          WindowsTaskbar.setProgressMode(
                            TaskbarProgressMode.paused,
                          );
                          break;
                        case DownloadStatus.canceled:
                          WindowsTaskbar.setProgressMode(
                            TaskbarProgressMode.error,
                          );
                          break;
                        default:
                      }
                    }
                  });
                  //item.download!.addListener(() {
                  //  item.notifyListeners();
                  //});
                } else if (item.download!.status == DownloadStatus.paused ||
                    item.download?.status == DownloadStatus.canceled ||
                    item.download?.status == DownloadStatus.failed) {
                  print('Should resume at dart...');
                  await item.download?.resume();
                } else if (item.download?.status == DownloadStatus.complete ||
                    item.download?.status == DownloadStatus.canceled) {
                  print('Should delete at dart...');
                  await item.download?.delete();
                } else if (item.download?.status == DownloadStatus.running) {
                  print('Should pause at dart...');
                  await item.download?.pause();
                }
              },
              onCancel: (download) async {
                await download.delete();
              },
            ),
    );
  }

  Widget _buildListSectionHeading(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.blue,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildNoPermissionWarning() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Grant storage permission to continue',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.blueGrey, fontSize: 18),
            ),
          ),
          const SizedBox(height: 32),
          TextButton(
            onPressed: _retryRequestPermission,
            child: const Text(
              'Retry',
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          )
        ],
      ),
    );
  }

  Future<void> _retryRequestPermission() async {
    final hasGranted = await _checkPermission();

    if (hasGranted) {
      await _prepareSaveDir();
    }

    setState(() {
      _permissionReady = hasGranted;
    });
  }

  Future<bool> _openDownloadedFile(Download download) async {
    return false;
    //return FlutterDownloader.open(taskId: task.taskId!);
  }

  Future<bool> _checkPermission() async {
    if (Platform.isIOS || Platform.isWindows) {
      return true;
    }

    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    if (widget.platform == TargetPlatform.android &&
        androidInfo.version.sdkInt <= 28) {
      final status = await Permission.storage.status;
      if (status != PermissionStatus.granted) {
        final result = await Permission.storage.request();
        if (result == PermissionStatus.granted) {
          return true;
        }
      } else {
        return true;
      }
    } else {
      return true;
    }
    return false;
  }

  Future<void> _prepare() async {
    final items = [
      ItemHolder.group('Documents'),
      ...DownloadItems.documents.map(ItemHolder.download),
      ItemHolder.group('Images'),
      ...DownloadItems.images.map(ItemHolder.download),
      ItemHolder.group('Videos'),
      ...DownloadItems.videos.map(ItemHolder.download),
      ItemHolder.group('APKs'),
      ...DownloadItems.apks.map(ItemHolder.download),
    ];

    for (final download in await widget.downloader.getDownloads()) {
      final item =
          items.firstWhereOrNull((item) => item.metaInfo?.url == download.url);
      item?.download = download;
    }
    //for(final item in _items) {
    //  if(item.metaInfo != null && item.download != null) {
    //    item.download = widget.downloader.
    //  }
    //}

    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _prepareSaveDir() async {
    _localPath = (await _findLocalPath())!;
    final savedDir = Directory(_localPath);
    final hasExisted = savedDir.existsSync();
    if (!hasExisted) {
      await savedDir.create();
    }
  }

  Future<String?> _findLocalPath() async {
    String? externalStorageDirPath;
    if (Platform.isAndroid) {
      try {
        externalStorageDirPath = await AndroidPathProvider.downloadsPath;
      } catch (e) {
        final directory = await getExternalStorageDirectory();
        externalStorageDirPath = directory?.path;
      }
    } else if (Platform.isIOS) {
      externalStorageDirPath =
          (await getApplicationDocumentsDirectory()).absolute.path;
    } else if (Platform.isWindows) {
      externalStorageDirPath = (await getDownloadsDirectory())?.path;
    }
    return externalStorageDirPath;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (Platform.isIOS)
            PopupMenuButton<Function>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  onTap: () => exit(0),
                  child: const ListTile(
                    title: Text(
                      'Simulate App Backgrounded',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ),
              ],
            )
        ],
      ),
      body: Builder(
        builder: (context) {
          if (_loading) {
            return const Center(child: CircularProgressIndicator());
          }

          return _buildDownloadList();
          //return _permissionReady
          //    ? _buildDownloadList()
          //    : _buildNoPermissionWarning();
        },
      ),
    );
  }
}

class ItemHolder extends ValueNotifier<Download?> {
  ItemHolder.download(this.metaInfo)
      : headline = null,
        super(null);

  ItemHolder.group(this.headline)
      : metaInfo = null,
        super(null);

  final String? headline;
  final DownloadItem? metaInfo;
  Download? _download;

  Download? get download => _download;

  set download(Download? download) {
    _download = download;
    value = download;
    download?.addListener(notifyListeners);
  }

  @override
  String toString() => 'ItemHolder{headline: $headline, metaInfo: $metaInfo, '
      'download: $_download}';
}
