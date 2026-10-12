import 'package:flutter_test/flutter_test.dart';
import 'package:rml_launcher/features/studio/domain/studio_version.dart';

void main() {
  test('parses dotted and comma separated versions', () {
    expect(StudioVersion.parse('0.690.0.6900613').text, '0.690.0.6900613');
    expect(StudioVersion.parse('0, 690, 0, 6900613').text, '0.690.0.6900613');
    expect(StudioVersion.parse(' 0.700.1 ').parts, <int>[0, 700, 1]);
  });

  test('rejects text that is not a version', () {
    expect(StudioVersion.tryParse(''), isNull);
    expect(StudioVersion.tryParse('7'), isNull);
    expect(StudioVersion.tryParse('0.abc'), isNull);
    expect(StudioVersion.tryParse('0.-2'), isNull);
    expect(() => StudioVersion.parse('version-1'), throwsFormatException);
  });

  test('compares numerically', () {
    expect(
      StudioVersion.parse('0.690.0.10') > StudioVersion.parse('0.690.0.9'),
      isTrue,
    );
    expect(
      StudioVersion.parse('0.689.0.99') < StudioVersion.parse('0.690.0.1'),
      isTrue,
    );
    expect(
      StudioVersion.parse('0.690').compareTo(StudioVersion.parse('0.690.0.0')),
      0,
    );
    expect(
      StudioVersion.parse('0.690.0.1'),
      StudioVersion.parse('0, 690, 0, 1'),
    );
  });

  test('exposes the major and short forms', () {
    final StudioVersion version = StudioVersion.parse('0.718.0.7181104');
    expect(version.major, 718);
    expect(version.short, '0.718');
    expect(version.toString(), '0.718.0.7181104');
  });
}
