import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_cmake/native_toolchain_cmake.dart';

Future<void> main(List<String> args) async {
  await build(args, (BuildInput input, BuildOutputBuilder output) async {
    if (!input.config.buildCodeAssets) {
      return;
    }
    final Logger logger = Logger('rml_native')
      ..onRecord.listen((LogRecord record) => stderr.writeln(record.message));
    final Uri installDir = input.outputDirectory.resolve('install/');
    final CMakeBuilder builder = CMakeBuilder.create(
      name: 'rml_native',
      sourceDir: input.packageRoot,
      defines: <String, String>{
        'CMAKE_INSTALL_PREFIX': installDir.toFilePath(),
        'RML_NATIVE_TESTS': 'OFF',
      },
      targets: <String>['install'],
      logger: logger,
    );
    await builder.run(input: input, output: output, logger: logger);
    output.dependencies.addAll(_sources(input.packageRoot));
    await output.findAndAddCodeAssets(
      input,
      names: <String, String>{
        r'(lib)?rml_native\.(dll|so|dylib)': 'src/bindings.g.dart',
      },
      outDir: installDir,
      logger: logger,
      regExp: true,
    );
  });
}

Iterable<Uri> _sources(Uri root) sync* {
  yield root.resolve('CMakeLists.txt');
  for (final String folder in <String>['cmake/', 'include/', 'src/']) {
    final Directory directory = Directory.fromUri(root.resolve(folder));
    yield directory.uri;
    yield* directory
        .listSync(recursive: true)
        .map((FileSystemEntity entity) => entity.uri);
  }
}
