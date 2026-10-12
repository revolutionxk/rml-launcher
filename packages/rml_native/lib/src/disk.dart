import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:rml_native/src/bindings.g.dart' as bindings;
import 'package:rml_native/src/native_json.dart';

int diskFree(String path) => using((Arena arena) {
  final Pointer<Uint64> out = arena<Uint64>();
  checkStatus(
    bindings.rml_disk_free(path.toNativeUtf8(allocator: arena).cast(), out),
  );
  return out.value;
});
