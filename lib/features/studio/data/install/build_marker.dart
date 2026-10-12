import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:rml_launcher/core/storage/json_read.dart';
import 'package:rml_launcher/core/storage/json_store.dart';
import 'package:rml_launcher/features/studio/domain/studio_version.dart';

final class BuildMarker {
  const BuildMarker({
    required this.version,
    required this.binaryTarget,
    required this.installedAt,
    this.guid,
    this.channel = 'LIVE',
    this.publishedAt,
  });

  static const String fileName = 'rml-build.json';

  final StudioVersion version;
  final String binaryTarget;
  final DateTime installedAt;
  final String? guid;
  final String channel;
  final DateTime? publishedAt;

  static bool existsIn(String buildDir) =>
      File(p.join(buildDir, fileName)).existsSync();

  static Future<BuildMarker?> read(String buildDir) async {
    final File file = File(p.join(buildDir, fileName));
    if (!file.existsSync()) {
      return null;
    }
    try {
      return fromJson(jsonDecode(await file.readAsString()));
    } on FormatException {
      return null;
    }
  }

  static BuildMarker? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final Object? version = json['version'];
    final Object? target = json['binaryTarget'];
    final Object? guid = json['guid'];
    final Object? channel = json['channel'];
    final StudioVersion? parsed = version is String
        ? StudioVersion.tryParse(version)
        : null;
    final DateTime? installedAt = dateFrom(json['installedAt']);
    if (parsed == null || target is! String || installedAt == null) {
      return null;
    }
    return BuildMarker(
      version: parsed,
      binaryTarget: target,
      installedAt: installedAt,
      guid: guid is String ? guid : null,
      channel: channel is String ? channel : 'LIVE',
      publishedAt: dateFrom(json['publishedAt']),
    );
  }

  Future<void> write(String buildDir) => File(p.join(buildDir, fileName))
      .writeAsString(
        const JsonEncoder.withIndent('  ').convert(toJson()),
        flush: true,
      );

  JsonMap toJson() => <String, Object?>{
    'version': version.text,
    'guid': guid,
    'binaryTarget': binaryTarget,
    'channel': channel,
    'installedAt': isoDate(installedAt),
    if (publishedAt != null) 'publishedAt': isoDate(publishedAt!),
  };
}
