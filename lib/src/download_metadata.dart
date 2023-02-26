import 'dart:convert';
import 'dart:io';

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
  addImplicitFinal: false,
  when: FreezedWhenOptions.none,
)
// To update run `flutter pub run build_runner build`
// The documentation at the params are added by freezed to the properties
class DownloadMetadata with _$DownloadMetadata {
  const DownloadMetadata._();

  /// Create new metadata with at least an [url] and a [target], the [headers]
  /// can be empty.
  factory DownloadMetadata({
    /// The url to download
    required String url,

    /// The filename which should be used for the filesystem
    String? filename,

    /// The [ETag](https://developer.mozilla.org/docs/Web/HTTP/Headers/ETag),
    /// if given, to resume the download.
    String? etag,

    /// The target of the download.
    required DownloadTarget target,

    /// The file size of the file to download.
    int? contentLength,

    /// `true` when the server supported ranges requests.
    @Default(false) bool isResumable,

    /// The request headers
    required Map<String, String> headers,
  }) = _DownloadMetadata;

  /// Deserialize DownloadMetadata from a [json] map.
  factory DownloadMetadata.fromJson(Map<String, dynamic> json) =>
      _$DownloadMetadataFromJson(json);

  /// Read the meta data from a [metadataFile].
  static Future<DownloadMetadata> fromFile(File metadataFile) async {
    final data = await metadataFile.readAsString();
    final json = jsonDecode(data) as Map<String, dynamic>;
    return DownloadMetadata.fromJson(json);
  }

  /// Write this meta data to a [metadataFile].
  Future<void> writeTo(File metadataFile) async {
    final writer = metadataFile.openWrite();
    final json = jsonEncode(toJson());
    try {
      writer.write(json);
    } finally {
      await writer.close();
    }
  }
}
