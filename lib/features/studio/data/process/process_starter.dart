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
  const SystemProcessStarter({this.timeout = const Duration(seconds: 10)});

  final Duration timeout;

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
    final Process process;
    try {
      process = await Process.start(executable, arguments);
    } on ProcessException {
      return const ProcessOutput(exitCode: -1);
    }
    unawaited(process.stderr.drain<void>());
    try {
      final (int code, String out) = await (
        process.exitCode,
        process.stdout
            .transform(const Utf8Decoder(allowMalformed: true))
            .join(),
      ).wait.timeout(timeout);
      return ProcessOutput(exitCode: code, stdout: out);
    } on TimeoutException {
      process.kill();
      return const ProcessOutput(exitCode: -1);
    }
  }
}
