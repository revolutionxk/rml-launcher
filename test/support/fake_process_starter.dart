import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/features/studio/data/process/process_starter.dart';

final class StartedProcess {
  const StartedProcess(this.executable, this.arguments, this.workingDirectory);

  final String executable;
  final List<String> arguments;
  final String? workingDirectory;
}

final class FakeProcessStarter implements ProcessStarter {
  final List<StartedProcess> started = <StartedProcess>[];
  final Map<String, ProcessOutput> outputs = <String, ProcessOutput>{};
  AppFailure? startFailure;

  @override
  Future<Result<void>> startDetached(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    final AppFailure? failure = startFailure;
    if (failure != null) {
      return Result<void>.err(failure);
    }
    started.add(StartedProcess(executable, arguments, workingDirectory));
    return const Result<void>.ok(null);
  }

  @override
  Future<ProcessOutput> run(String executable, List<String> arguments) async =>
      outputs['$executable ${arguments.join(' ')}'] ??
      const ProcessOutput(exitCode: 1);
}
