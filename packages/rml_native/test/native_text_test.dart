import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:rml_native/src/native_text.dart';
import 'package:test/test.dart';

void main() {
  test('decodes utf-8 and replaces malformed bytes', () {
    final Pointer<Uint8> text = malloc<Uint8>(6);
    addTearDown(() => malloc.free(text));
    text.asTypedList(6).setAll(0, <int>[0x43, 0xC3, 0xA7, 0xFF, 0x21, 0x00]);
    expect(readNativeText(text.cast()), 'Cç�!');
  });
}
