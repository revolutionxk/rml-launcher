import 'dart:convert';

import 'package:rml_launcher/features/studio/domain/studio_version.dart';

final class DeployedBuild {
  const DeployedBuild({required this.version, required this.publishedAt});

  final StudioVersion version;
  final DateTime publishedAt;
}

final RegExp _timestamp = RegExp(
  r'^(\d{1,2})/(\d{1,2})/(\d{4}) (\d{1,2}):(\d{2}):(\d{2}) (AM|PM)$',
);

List<DeployedBuild> parseDeployHistory(String text, {required String product}) {
  final String prefix = 'New $product version-';
  final Set<String> seen = <String>{};
  final List<DeployedBuild> builds = <DeployedBuild>[];
  for (final String raw in const LineSplitter().convert(text).reversed) {
    final String line = raw.trim();
    if (!line.startsWith(prefix) || line.endsWith('Error!')) {
      continue;
    }
    final int at = line.indexOf(' at ');
    if (at < 0) {
      continue;
    }
    final String details = line.substring(at + ' at '.length);
    const String marker = ', file version: ';
    final int split = details.indexOf(marker);
    if (split < 0) {
      continue;
    }
    final DateTime? publishedAt = _parseTimestamp(details.substring(0, split));
    final StudioVersion? version = StudioVersion.tryParse(
      _rawVersion(details.substring(split + marker.length)),
    );
    if (publishedAt == null || version == null || !seen.add(version.text)) {
      continue;
    }
    builds.add(DeployedBuild(version: version, publishedAt: publishedAt));
  }
  return builds;
}

String _rawVersion(String text) {
  for (final String end in const <String>[', git hash:', '...']) {
    final int index = text.indexOf(end);
    if (index >= 0) {
      return text.substring(0, index).trim();
    }
  }
  return text.trim();
}

DateTime? _parseTimestamp(String text) {
  final RegExpMatch? match = _timestamp.firstMatch(text.trim());
  if (match == null) {
    return null;
  }
  final int hour12 = int.parse(match[4]!);
  final bool afternoon = match[7] == 'PM';
  final int hour = hour12 % 12 + (afternoon ? 12 : 0);
  return DateTime.utc(
    int.parse(match[3]!),
    int.parse(match[1]!),
    int.parse(match[2]!),
    hour,
    int.parse(match[5]!),
    int.parse(match[6]!),
  );
}
