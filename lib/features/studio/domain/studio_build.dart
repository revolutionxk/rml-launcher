import 'package:rml_launcher/core/storage/json_read.dart';
import 'package:rml_launcher/core/storage/json_store.dart';
import 'package:rml_launcher/features/studio/domain/studio_version.dart';

final class StudioBuild {
  const StudioBuild({
    required this.version,
    required this.path,
    required this.installedAt,
    this.guid,
    this.publishedAt,
  });

  final StudioVersion version;
  final String path;
  final DateTime installedAt;
  final String? guid;
  final DateTime? publishedAt;

  static StudioBuild? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final Object? version = json['version'];
    final Object? path = json['path'];
    final Object? guid = json['guid'];
    final StudioVersion? parsed = version is String
        ? StudioVersion.tryParse(version)
        : null;
    final DateTime? installedAt = dateFrom(json['installedAt']);
    if (parsed == null || path is! String || installedAt == null) {
      return null;
    }
    return StudioBuild(
      version: parsed,
      path: path,
      installedAt: installedAt,
      guid: guid is String ? guid : null,
      publishedAt: dateFrom(json['publishedAt']),
    );
  }

  JsonMap toJson() => <String, Object?>{
    'version': version.text,
    'guid': guid,
    'path': path,
    'installedAt': isoDate(installedAt),
    'publishedAt': publishedAt == null ? null : isoDate(publishedAt!),
  };

  @override
  bool operator ==(Object other) =>
      other is StudioBuild &&
      other.version == version &&
      other.path == path &&
      other.installedAt == installedAt &&
      other.guid == guid &&
      other.publishedAt == publishedAt;

  @override
  int get hashCode =>
      Object.hash(version, path, installedAt, guid, publishedAt);
}
