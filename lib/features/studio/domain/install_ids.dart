import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:rml_launcher/features/studio/domain/studio_install.dart';

const int _maxIdLength = 40;

final Set<String> _deviceNames = <String>{
  'con',
  'prn',
  'aux',
  'nul',
  for (int index = 1; index <= 9; index++) ...<String>[
    'com$index',
    'lpt$index',
  ],
};

String installIdFor(String name, Iterable<String> taken) {
  String base = name
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (base.length > _maxIdLength) {
    base = base.substring(0, _maxIdLength).replaceAll(RegExp(r'-+$'), '');
  }
  if (base.isEmpty) {
    base = 'studio';
  }
  if (_deviceNames.contains(base)) {
    base = '$base-studio';
  }
  final Set<String> used = taken.toSet();
  String candidate = base;
  for (int suffix = 2; used.contains(candidate); suffix++) {
    candidate = '$base-$suffix';
  }
  return candidate;
}

String foundInstallId(
  InstallSource source,
  String root, {
  bool ignoreCase = false,
}) {
  final String normal = p.normalize(root);
  int hash = 0x811c9dc5;
  for (final int byte in utf8.encode(
    ignoreCase ? normal.toLowerCase() : normal,
  )) {
    hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
  }
  return '${source.slug}-${hash.toRadixString(16).padLeft(8, '0')}';
}
