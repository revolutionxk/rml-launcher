import 'dart:convert';

import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/core/storage/json_store.dart';

final class MemoryJsonStore implements JsonStore {
  final Map<String, String> documents = <String, String>{};
  final List<AppFailure> readFailures = <AppFailure>[];
  int reads = 0;
  int writes = 0;

  @override
  Future<Result<JsonMap?>> read(String name) async {
    reads++;
    if (readFailures.isNotEmpty) {
      return Result<JsonMap?>.err(readFailures.removeAt(0));
    }
    final String? text = documents[name];
    if (text == null) {
      return const Result<JsonMap?>.ok(null);
    }
    return Result<JsonMap?>.ok(jsonDecode(text) as JsonMap);
  }

  @override
  Future<Result<void>> write(String name, JsonMap value) async {
    writes++;
    documents[name] = jsonEncode(value);
    return const Result<void>.ok(null);
  }
}
