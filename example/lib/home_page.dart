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

  Widget _buildDownloadList() => ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          for (final item in _items)
            item.headline != null
                ? _buildListSectionHeading(item.headline!)
                : DownloadListItem(
                    data: item,
                    onTap: (task) async {
                      final success = await _openDownloadedFile(task);
                      if (!success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cannot open this file'),
                          ),
                        );
                      }
                    },
                    onActionTap: (item) async {
                      if (item.download == null) {
                        item.download = await widget.downloader.startDownload(item.metaInfo!.url);
                      } else if (item.download?.status == DownloadTaskStatus.undefined ||
                          item.download?.status == DownloadTaskStatus.paused ||
                          item.download?.status == DownloadTaskStatus.failed) {
                        await item.download?.resume();
                      } else if (item.download?.status ==
                              DownloadTaskStatus.complete ||
                          item.download?.status == DownloadTaskStatus.canceled) {
                        await item.download?.delete();
                      } else if (item.download?.status ==
                          DownloadTaskStatus.running) {
                        await item.download?.pause();
                      }
                    },
                    onCancel: (download) async {
                      await download.delete();
                    },
                  ),
        ],
      );

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
    _items = [
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
          _items.firstWhereOrNull((item) => item.metaInfo?.url == download.url);
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

          return _permissionReady
              ? _buildDownloadList()
              : _buildNoPermissionWarning();
        },
      ),
    );
  }
}

class ItemHolder {
  ItemHolder.download(this.metaInfo) : headline = null;

  ItemHolder.group(this.headline) : metaInfo = null;

  final String? headline;
  final DownloadItem? metaInfo;
  Download? download;

  @override
  String toString() => 'ItemHolder{headline: $headline, metaInfo: $metaInfo, download: $download}';
}
