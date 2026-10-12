import 'dart:math';

final class StudioVersion implements Comparable<StudioVersion> {
  StudioVersion(Iterable<int> parts) : parts = List<int>.unmodifiable(parts);

  factory StudioVersion.parse(String text) {
    final StudioVersion? version = tryParse(text);
    if (version == null) {
      throw FormatException('Not a Studio version', text);
    }
    return version;
  }

  static final RegExp _separator = RegExp('[,.]');

  final List<int> parts;

  static StudioVersion? tryParse(String text) {
    final List<int> parts = <int>[];
    for (final String piece in text.split(_separator)) {
      final String trimmed = piece.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final int? value = int.tryParse(trimmed);
      if (value == null || value < 0) {
        return null;
      }
      parts.add(value);
    }
    return parts.length < 2 ? null : StudioVersion(parts);
  }

  int get major => parts[1];

  String get short => '${parts[0]}.${parts[1]}';

  String get text => parts.join('.');

  bool operator >(StudioVersion other) => compareTo(other) > 0;

  bool operator <(StudioVersion other) => compareTo(other) < 0;

  @override
  int compareTo(StudioVersion other) {
    final int length = max(parts.length, other.parts.length);
    for (int index = 0; index < length; index++) {
      final int left = index < parts.length ? parts[index] : 0;
      final int right = index < other.parts.length ? other.parts[index] : 0;
      if (left != right) {
        return left.compareTo(right);
      }
    }
    return 0;
  }

  @override
  bool operator ==(Object other) =>
      other is StudioVersion && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => text;
}
