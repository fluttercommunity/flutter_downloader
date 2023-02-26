// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'download_metadata.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

DownloadMetadata _$DownloadMetadataFromJson(Map<String, dynamic> json) {
  return _DownloadMetadata.fromJson(json);
}

/// @nodoc
mixin _$DownloadMetadata {
  /// The url to download
  String get url => throw _privateConstructorUsedError;

  /// The filename which should be used for the filesystem
  String? get filename => throw _privateConstructorUsedError;

  /// The [ETag](https://developer.mozilla.org/docs/Web/HTTP/Headers/ETag),
  /// if given, to resume the download
  String? get etag => throw _privateConstructorUsedError;

  /// The target of the download
  DownloadTarget get target => throw _privateConstructorUsedError;

  /// The final file size of the file to download
  int? get size => throw _privateConstructorUsedError;

  /// The request headers
  Map<String, String> get headers => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
}

/// @nodoc
@JsonSerializable()
class _$_DownloadMetadata implements _DownloadMetadata {
  const _$_DownloadMetadata(
      {required this.url,
      this.filename,
      this.etag,
      required this.target,
      this.size,
      required final Map<String, String> headers})
      : _headers = headers;

  factory _$_DownloadMetadata.fromJson(Map<String, dynamic> json) =>
      _$$_DownloadMetadataFromJson(json);

  /// The url to download
  @override
  final String url;

  /// The filename which should be used for the filesystem
  @override
  final String? filename;

  /// The [ETag](https://developer.mozilla.org/docs/Web/HTTP/Headers/ETag),
  /// if given, to resume the download
  @override
  final String? etag;

  /// The target of the download
  @override
  final DownloadTarget target;

  /// The final file size of the file to download
  @override
  final int? size;

  /// The request headers
  final Map<String, String> _headers;

  /// The request headers
  @override
  Map<String, String> get headers {
    if (_headers is EqualUnmodifiableMapView) return _headers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_headers);
  }

  @override
  String toString() {
    return 'DownloadMetadata(url: $url, filename: $filename, etag: $etag, target: $target, size: $size, headers: $headers)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_DownloadMetadata &&
            (identical(other.url, url) || other.url == url) &&
            (identical(other.filename, filename) ||
                other.filename == filename) &&
            (identical(other.etag, etag) || other.etag == etag) &&
            (identical(other.target, target) || other.target == target) &&
            (identical(other.size, size) || other.size == size) &&
            const DeepCollectionEquality().equals(other._headers, _headers));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, url, filename, etag, target,
      size, const DeepCollectionEquality().hash(_headers));

  @override
  Map<String, dynamic> toJson() {
    return _$$_DownloadMetadataToJson(
      this,
    );
  }
}

abstract class _DownloadMetadata implements DownloadMetadata {
  const factory _DownloadMetadata(
      {required final String url,
      final String? filename,
      final String? etag,
      required final DownloadTarget target,
      final int? size,
      required final Map<String, String> headers}) = _$_DownloadMetadata;

  factory _DownloadMetadata.fromJson(Map<String, dynamic> json) =
      _$_DownloadMetadata.fromJson;

  @override

  /// The url to download
  String get url;
  @override

  /// The filename which should be used for the filesystem
  String? get filename;
  @override

  /// The [ETag](https://developer.mozilla.org/docs/Web/HTTP/Headers/ETag),
  /// if given, to resume the download
  String? get etag;
  @override

  /// The target of the download
  DownloadTarget get target;
  @override

  /// The final file size of the file to download
  int? get size;
  @override

  /// The request headers
  Map<String, String> get headers;
}
