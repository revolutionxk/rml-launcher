import 'dart:io';

import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';

final class ProcessOutput {
  const ProcessOutput({required this.exitCode, this.stdout = ''});

  final int exitCode;
  final String stdout;
}

abstract interface class ProcessStarter {
  Future<Result<void>> startDetached(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  });

  Future<ProcessOutput> run(String executable, List<String> arguments);
}

final class SystemProcessStarter implements ProcessStarter {
  const SystemProcessStarter();

  @override
  Future<Result<void>> startDetached(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    try {
      await Process.start(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        mode: ProcessStartMode.detached,
      );
      return const Result<void>.ok(null);
    } on ProcessException catch (error, stackTrace) {
      return Result<void>.err(
        IoFailure(path: executable, cause: error, stackTrace: stackTrace),
      );
    }
  }

  @override
  Future<ProcessOutput> run(String executable, List<String> arguments) async {
    try {
      final ProcessResult result = await Process.run(executable, arguments);
      final Object? out = result.stdout;
      return ProcessOutput(
        exitCode: result.exitCode,
        stdout: out is String ? out : '',
      );
    } on ProcessException {
      return const ProcessOutput(exitCode: -1);
    }
  }
}
