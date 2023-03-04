// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_metadata.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_DownloadMetadata _$$_DownloadMetadataFromJson(Map<String, dynamic> json) =>
    _$_DownloadMetadata(
      url: json['url'] as String,
      filename: json['filename'] as String?,
      etag: json['etag'] as String?,
      target: $enumDecode(_$DownloadTargetEnumMap, json['target']),
      contentLength: json['contentLength'] as int?,
      isResumable: json['isResumable'] as bool? ?? false,
      headers: Map<String, String>.from(json['headers'] as Map),
    );

Map<String, dynamic> _$$_DownloadMetadataToJson(_$_DownloadMetadata instance) =>
    <String, dynamic>{
      'url': instance.url,
      'filename': instance.filename,
      'etag': instance.etag,
      'target': _$DownloadTargetEnumMap[instance.target]!,
      'contentLength': instance.contentLength,
      'isResumable': instance.isResumable,
      'headers': instance.headers,
    };

const _$DownloadTargetEnumMap = {
  DownloadTarget.downloadsFolder: 'downloadsFolder',
  DownloadTarget.desktopFolder: 'desktopFolder',
  DownloadTarget.internal: 'internal',
};