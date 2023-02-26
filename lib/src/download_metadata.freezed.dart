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

  /// The url to download
  set url(String value) => throw _privateConstructorUsedError;

  /// The filename which should be used for the filesystem
  String? get filename => throw _privateConstructorUsedError;

  /// The filename which should be used for the filesystem
  set filename(String? value) => throw _privateConstructorUsedError;

  /// The [ETag](https://developer.mozilla.org/docs/Web/HTTP/Headers/ETag),
  /// if given, to resume the download.
  String? get etag => throw _privateConstructorUsedError;

  /// The [ETag](https://developer.mozilla.org/docs/Web/HTTP/Headers/ETag),
  /// if given, to resume the download.
  set etag(String? value) => throw _privateConstructorUsedError;

  /// The target of the download.
  DownloadTarget get target => throw _privateConstructorUsedError;

  /// The target of the download.
  set target(DownloadTarget value) => throw _privateConstructorUsedError;

  /// The final file size of the file to download.
  int? get contentLength => throw _privateConstructorUsedError;

  /// The final file size of the file to download.
  set contentLength(int? value) => throw _privateConstructorUsedError;

  /// `true` when the server supported ranges requests.
  bool get isResumable => throw _privateConstructorUsedError;

  /// `true` when the server supported ranges requests.
  set isResumable(bool value) => throw _privateConstructorUsedError;

  /// The request headers
  Map<String, String> get headers => throw _privateConstructorUsedError;

  /// The request headers
  set headers(Map<String, String> value) => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
}

/// @nodoc
@JsonSerializable()
class _$_DownloadMetadata extends _DownloadMetadata {
  _$_DownloadMetadata(
      {required this.url,
      this.filename,
      this.etag,
      required this.target,
      this.contentLength,
      this.isResumable = false,
      required Map<String, String> headers})
      : _headers = headers,
        super._();

  factory _$_DownloadMetadata.fromJson(Map<String, dynamic> json) =>
      _$$_DownloadMetadataFromJson(json);

  /// The url to download
  @override
  String url;

  /// The filename which should be used for the filesystem
  @override
  String? filename;

  /// The [ETag](https://developer.mozilla.org/docs/Web/HTTP/Headers/ETag),
  /// if given, to resume the download.
  @override
  String? etag;

  /// The target of the download.
  @override
  DownloadTarget target;

  /// The final file size of the file to download.
  @override
  int? contentLength;

  /// `true` when the server supported ranges requests.
  @override
  @JsonKey()
  bool isResumable;

  /// The request headers
  Map<String, String> _headers;

  /// The request headers
  @override
  Map<String, String> get headers {
    if (_headers is EqualUnmodifiableMapView) return _headers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_headers);
  }

  @override
  String toString() {
    return 'DownloadMetadata(url: $url, filename: $filename, etag: $etag, target: $target, contentLength: $contentLength, isResumable: $isResumable, headers: $headers)';
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
            (identical(other.contentLength, contentLength) ||
                other.contentLength == contentLength) &&
            (identical(other.isResumable, isResumable) ||
                other.isResumable == isResumable) &&
            const DeepCollectionEquality().equals(other._headers, _headers));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      url,
      filename,
      etag,
      target,
      contentLength,
      isResumable,
      const DeepCollectionEquality().hash(_headers));

  @override
  Map<String, dynamic> toJson() {
    return _$$_DownloadMetadataToJson(
      this,
    );
  }
}

abstract class _DownloadMetadata extends DownloadMetadata {
  factory _DownloadMetadata(
      {required String url,
      String? filename,
      String? etag,
      required DownloadTarget target,
      int? contentLength,
      bool isResumable,
      required Map<String, String> headers}) = _$_DownloadMetadata;
  _DownloadMetadata._() : super._();

  factory _DownloadMetadata.fromJson(Map<String, dynamic> json) =
      _$_DownloadMetadata.fromJson;

  @override

  /// The url to download
  String get url;

  /// The url to download
  set url(String value);
  @override

  /// The filename which should be used for the filesystem
  String? get filename;

  /// The filename which should be used for the filesystem
  set filename(String? value);
  @override

  /// The [ETag](https://developer.mozilla.org/docs/Web/HTTP/Headers/ETag),
  /// if given, to resume the download.
  String? get etag;

  /// The [ETag](https://developer.mozilla.org/docs/Web/HTTP/Headers/ETag),
  /// if given, to resume the download.
  set etag(String? value);
  @override

  /// The target of the download.
  DownloadTarget get target;

  /// The target of the download.
  set target(DownloadTarget value);
  @override

  /// The final file size of the file to download.
  int? get contentLength;

  /// The final file size of the file to download.
  set contentLength(int? value);
  @override

  /// `true` when the server supported ranges requests.
  bool get isResumable;

  /// `true` when the server supported ranges requests.
  set isResumable(bool value);
  @override

  /// The request headers
  Map<String, String> get headers;

  /// The request headers
  set headers(Map<String, String> value);
}
