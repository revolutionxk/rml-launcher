import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:rml_native/src/bindings.g.dart' as bindings;
import 'package:rml_native/src/native_json.dart';

final class ExecutableInfo {
  const ExecutableInfo({this.version, this.identifier, this.executable});

  final String? version;
  final String? identifier;
  final String? executable;
}

ExecutableInfo executableInfo(String path) => using((Arena arena) {
  final Pointer<Char> nativePath = path.toNativeUtf8(allocator: arena).cast();
  final Object? decoded = jsonDecode(
    jsonResult(
      (Pointer<Pointer<Char>> out) =>
          bindings.rml_executable_info(nativePath, out),
    ),
  );
  final Map<String, Object?> json = decoded is Map<String, Object?>
      ? decoded
      : const <String, Object?>{};
  return ExecutableInfo(
    version: json['version'] as String?,
    identifier: json['identifier'] as String?,
    executable: json['executable'] as String?,
  );
});
