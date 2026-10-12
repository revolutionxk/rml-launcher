import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rml_launcher/features/studio/data/cdn/runtime_files.dart';

void main() {
  test('AppSettings.xml is the exact 111 bytes', () {
    expect(utf8.encode(RuntimeFiles.appSettingsXml), hasLength(111));
    expect(RuntimeFiles.appSettingsXml, startsWith('<Settings>\n    <Content'));
    expect(RuntimeFiles.appSettingsXml, endsWith('</Settings>\n'));
  });

  test('OAuth2Config.json is the exact 642 bytes of valid json', () {
    expect(utf8.encode(RuntimeFiles.oauth2ConfigJson), hasLength(642));
    expect(RuntimeFiles.oauth2ConfigJson, endsWith('}\n'));
    final Map<String, Object?> json =
        jsonDecode(RuntimeFiles.oauth2ConfigJson) as Map<String, Object?>;
    expect((json['distributors']! as Map<String, Object?>).keys, <String>[
      'vanilla',
      'Global',
      'cjv',
      'ChinaJointVenture',
    ]);
  });
}
