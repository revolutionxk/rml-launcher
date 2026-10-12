import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Set<String> keysOf(Map<String, Object?> map, [String prefix = '']) => <String>{
  for (final MapEntry<String, Object?> entry in map.entries)
    if (entry.value is Map<String, Object?>)
      ...keysOf(entry.value! as Map<String, Object?>, '$prefix${entry.key}.')
    else
      '$prefix${entry.key}',
};

Map<String, Object?> load(String name) =>
    jsonDecode(File('lib/i18n/$name.i18n.json').readAsStringSync())
        as Map<String, Object?>;

void main() {
  test('portuguese has exactly the english keys', () {
    expect(keysOf(load('pt-BR')), keysOf(load('en')));
  });

  test('no translation is empty', () {
    for (final String locale in <String>['en', 'pt-BR']) {
      final String text = File('lib/i18n/$locale.i18n.json').readAsStringSync();
      expect(
        text.contains('""'),
        isFalse,
        reason: '$locale has an empty value',
      );
    }
  });
}
