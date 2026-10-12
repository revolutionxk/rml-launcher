import 'package:rml_launcher/core/native/native_service.dart';
import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';

final class FakeNativeService implements NativeService {
  FakeNativeService({
    this.osReducesMotion,
    this.version = '0.1.0',
    this.freeBytes = 1 << 40,
    this.realFiles = false,
  });

  static const FfiNativeService _real = FfiNativeService();

  @override
  final String? version;

  @override
  bool? osReducesMotion;

  final bool realFiles;
  int freeBytes;
  List<NativeProcess> processes = <NativeProcess>[];
  AppFailure? processFailure;
  final Map<String, ExecutableInfo> executables = <String, ExecutableInfo>{};
  final List<int> closed = <int>[];
  final List<int> killed = <int>[];

  @override
  Future<Result<String>> hashFile(HashAlgorithm algorithm, String path) async =>
      realFiles
      ? _real.hashFile(algorithm, path)
      : const Result<String>.ok('fake');

  @override
  Future<Result<ExtractedArchive>> extractZip(
    String archive,
    String destination, {
    ExtractProgress? onProgress,
  }) async => realFiles
      ? _real.extractZip(archive, destination, onProgress: onProgress)
      : const Result<ExtractedArchive>.err(
          NativeFailure(code: 3, message: 'not faked'),
        );

  @override
  Result<int> diskFree(String path) => Result<int>.ok(freeBytes);

  @override
  Result<List<NativeProcess>> findProcesses(String executableName) {
    final AppFailure? failure = processFailure;
    return failure == null
        ? Result<List<NativeProcess>>.ok(List<NativeProcess>.of(processes))
        : Result<List<NativeProcess>>.err(failure);
  }

  @override
  Result<void> closeProcess(int pid) {
    closed.add(pid);
    return const Result<void>.ok(null);
  }

  @override
  Result<void> killProcess(int pid) {
    killed.add(pid);
    processes = processes
        .where((NativeProcess process) => process.pid != pid)
        .toList();
    return const Result<void>.ok(null);
  }

  @override
  Result<ExecutableInfo> executableInfo(String path) {
    final ExecutableInfo? info = executables[path];
    if (info == null) {
      return const Result<ExecutableInfo>.err(
        NativeFailure(code: 2, message: 'Not a Windows executable'),
      );
    }
    return Result<ExecutableInfo>.ok(info);
  }
}
