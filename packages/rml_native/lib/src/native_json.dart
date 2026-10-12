import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:rml_native/src/bindings.g.dart' as bindings;
import 'package:rml_native/src/native_exception.dart';
import 'package:rml_native/src/native_text.dart';

void checkStatus(int status) {
  if (status != 0) {
    throw NativeException.last(status);
  }
}

String jsonResult(int Function(Pointer<Pointer<Char>> out) call) =>
    using((Arena arena) {
      final Pointer<Pointer<Char>> out = arena<Pointer<Char>>();
      checkStatus(call(out));
      try {
        return readNativeText(out.value);
      } finally {
        bindings.rml_free(out.value.cast());
      }
    });
