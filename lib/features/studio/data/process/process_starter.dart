import 'dart:async';
import 'dart:convert';
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

  static const Duration _runTimeout = Duration(seconds: 10);

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
    Process process;
    try {
      process = await Process.start(executable, arguments);
    } on ProcessException {
      return const ProcessOutput(exitCode: -1);
    }
    try {
      final Future<String> out = process.stdout
          .transform(const Utf8Decoder())
          .join();
      unawaited(process.stderr.drain<void>());
      final int code = await process.exitCode.timeout(_runTimeout);
      return ProcessOutput(exitCode: code, stdout: await out);
    } on TimeoutException {
      process.kill();
      return const ProcessOutput(exitCode: -1);
    } on FormatException {
      process.kill();
      return const ProcessOutput(exitCode: -1);
    }
  }
}
