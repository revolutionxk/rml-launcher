import 'dart:io';

import 'package:ffigen/ffigen.dart';

Future<void> main() async {
  final Uri root = Platform.script.resolve('../');
  bool ours(String name) => name.startsWith('rml_');
  final FfiGenerator generator = FfiGenerator(
    input: Input(entryPoints: <Uri>[root.resolve('include/rml/rml.h')]),
    output: Output(
      dart: DartOutput(path: root.resolve('lib/src/bindings.g.dart')),
      style: const NativeExternalBindings(
        assetId: 'package:rml_native/src/bindings.g.dart',
      ),
    ),
    visitors: <Visitor>[
      Visitor(
        func: (Func node) => node.isIncluded = ours(node.name),
        enumClass: (EnumClass node) => node.isIncluded = ours(node.name),
        typealias: (Typealias node) => node.isIncluded = ours(node.name)
            ? TypealiasInclude.ifUsed
            : TypealiasInclude.never,
      ),
    ],
  );
  await generator.generate();
}
