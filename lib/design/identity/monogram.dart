import 'package:flutter/widgets.dart';

String monogramFor(String name) {
  final String trimmed = name.trim();
  if (trimmed.isEmpty) {
    return '?';
  }
  return trimmed.characters.first.toUpperCase();
}
