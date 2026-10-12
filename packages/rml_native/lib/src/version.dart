import 'package:ffi/ffi.dart';
import 'package:rml_native/src/bindings.g.dart' as bindings;

String nativeVersion() => bindings.rml_version().cast<Utf8>().toDartString();
