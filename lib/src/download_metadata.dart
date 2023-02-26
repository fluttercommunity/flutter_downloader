import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'download_metadata.freezed.dart';
part 'download_metadata.g.dart';

/// The metadata of the file to download.
///
/// Each instance contains at least a [url] and a [target]. Optional are the
/// [filename] which will be detected from the response headers. In order to
/// resume the download a [etag] is recommended, see also
/// [MDN](https://developer.mozilla.org/docs/Web/HTTP/Headers/ETag) for details.
/// The [size] is required for calculating the progress and will be inferred
/// from the response headers ether.
@Freezed(
  fromJson: true,
  toJson: true,
  copyWith: false,
  when: FreezedWhenOptions.none,
)
// To update run `flutter pub run build_runner build`
// The documentation at the params are added by freezed to the properties
class DownloadMetadata with _$DownloadMetadata {
  /// Create new metadata with at least an [url] and a [target], the [headers]
  /// can be empty.
  const factory DownloadMetadata({
    /// The url to download
    required String url,

    /// The filename which should be used for the filesystem
    String? filename,

    /// The [ETag](https://developer.mozilla.org/docs/Web/HTTP/Headers/ETag),
    /// if given, to resume the download
    String? etag,

    /// The target of the download
    required DownloadTarget target,

    /// The final file size of the file to download
    int? size,

    /// The request headers
    required Map<String, String> headers,
  }) = _DownloadMetadata;

  /// Deserialize DownloadMetadata from a [json] map.
  factory DownloadMetadata.fromJson(Map<String, dynamic> json) =>
      _$DownloadMetadataFromJson(json);
}
