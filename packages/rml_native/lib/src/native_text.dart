import 'dart:convert';
import 'dart:ffi';

String readNativeText(Pointer<Char> text) {
  final Pointer<Uint8> bytes = text.cast();
  int length = 0;
  while (bytes[length] != 0) {
    length++;
  }
  return utf8.decode(bytes.asTypedList(length), allowMalformed: true);
}
