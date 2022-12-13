import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_downloader_example/home_page.dart';

class DownloadListItem extends StatelessWidget {
  const DownloadListItem({
    super.key,
    required this.data,
    required this.onTap,
    required this.onActionTap,
    required this.onCancel,
  });

  final ItemHolder data;
  final Function(Download) onTap;
  final Function(ItemHolder) onActionTap;
  final Function(Download) onCancel;

  Widget? _buildTrailing(ItemHolder holder) {
    if (holder.download == null) {
      return IconButton(
        onPressed: () => onActionTap.call(holder),
        constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
        icon: const Icon(Icons.file_download),
        tooltip: 'Start',
      );
    } else if (holder.download?.status == DownloadStatus.running) {
      return Row(
        children: [
          Text('${holder.download?.progress}%'),
          IconButton(
            onPressed: () => onActionTap.call(holder),
            constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
            icon: const Icon(Icons.pause, color: Colors.yellow),
            tooltip: 'Pause',
          ),
        ],
      );
    } else if (holder.download?.status == DownloadStatus.paused) {
      return Row(
        children: [
          Text('${holder.download?.progress}%'),
          IconButton(
            onPressed: () => onActionTap.call(holder),
            constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
            icon: const Icon(Icons.play_arrow, color: Colors.green),
            tooltip: 'Resume',
          ),
          IconButton(
            onPressed: () => onCancel.call(holder.download!),
            constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
            icon: const Icon(Icons.cancel, color: Colors.red),
            tooltip: 'Cancel',
          ),
        ],
      );
    } else if (holder.download?.status == DownloadStatus.complete) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Text('Ready', style: TextStyle(color: Colors.green)),
          IconButton(
            onPressed: () => onActionTap.call(holder),
            constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
            icon: const Icon(Icons.delete),
            tooltip: 'Delete',
          )
        ],
      );
    } else if (holder.download?.status == DownloadStatus.canceled) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Text('Canceled', style: TextStyle(color: Colors.red)),
          IconButton(
            onPressed: () => onActionTap.call(holder),
            constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
            icon: const Icon(Icons.cancel),
            tooltip: 'Cancel',
          )
        ],
      );
    } else if (holder.download?.status == DownloadStatus.failed) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Text('Failed', style: TextStyle(color: Colors.red)),
          IconButton(
            onPressed: () => onActionTap.call(holder),
            constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
            icon: const Icon(Icons.refresh, color: Colors.green),
            tooltip: 'Refresh',
          )
        ],
      );
    //} else if (holder.download?.status == DownloadStatus.enqueued) {
    //  return const Text('Pending', style: TextStyle(color: Colors.orange));
    } else {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: data.download?.status == DownloadStatus.complete
          ? () {
              onTap(data.download!);
            }
          : null,
      child: Container(
        padding: const EdgeInsets.only(left: 16, right: 8),
        child: InkWell(
          child: Stack(
            children: [
              SizedBox(
                width: double.infinity,
                height: 64,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        data.metaInfo?.name ?? 'Err1',
                        maxLines: 1,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ValueListenableBuilder<Download?>(
                        valueListenable : data,
                        builder: (context, holder, child) => _buildTrailing(data)!,
                      ),
                    ),
                  ],
                ),
              ),
              if (data.download?.status == DownloadStatus.running ||
                  data.download?.status == DownloadStatus.paused)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LinearProgressIndicator(
                    value: data.download!.progress / 1000,
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }
}
