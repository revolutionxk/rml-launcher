import 'package:rml_native/src/bindings.g.dart' as bindings;

bool? osReduceMotion() => switch (bindings.rml_os_reduce_motion()) {
  1 => true,
  0 => false,
  _ => null,
};
