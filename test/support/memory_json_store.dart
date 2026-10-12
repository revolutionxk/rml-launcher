import 'dart:convert';

import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/core/storage/json_store.dart';

final class MemoryJsonStore implements JsonStore {
  final Map<String, String> documents = <String, String>{};

  @override
  Future<Result<JsonMap?>> read(String name) async {
    final String? text = documents[name];
    if (text == null) {
      return const Result<JsonMap?>.ok(null);
    }
    return Result<JsonMap?>.ok(jsonDecode(text) as JsonMap);
  }

  @override
  Future<Result<void>> write(String name, JsonMap value) async {
    documents[name] = jsonEncode(value);
    return const Result<void>.ok(null);
  }
}
