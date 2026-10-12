import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_native/rml_native.dart' as rml;

export 'package:rml_native/rml_native.dart'
    show
        ExecutableInfo,
        ExtractProgress,
        ExtractedArchive,
        ExtractedFile,
        HashAlgorithm,
        NativeProcess;

abstract interface class NativeService {
  String? get version;

  bool? get osReducesMotion;

  Future<Result<String>> hashFile(rml.HashAlgorithm algorithm, String path);

  Future<Result<rml.ExtractedArchive>> extractZip(
    String archive,
    String destination, {
    rml.ExtractProgress? onProgress,
  });

  Result<int> diskFree(String path);

  Result<List<rml.NativeProcess>> findProcesses(String executableName);

  Result<void> closeProcess(int pid);

  Result<void> killProcess(int pid);

  Result<rml.ExecutableInfo> executableInfo(String path);
}

final class FfiNativeService implements NativeService {
  const FfiNativeService();

  @override
  String? get version {
    try {
      return rml.nativeVersion();
    } catch (_) {
      return null;
    }
  }

  @override
  bool? get osReducesMotion {
    try {
      return rml.osReduceMotion();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Result<String>> hashFile(rml.HashAlgorithm algorithm, String path) =>
      _callAsync(() => rml.hashFile(algorithm, path));

  @override
  Future<Result<rml.ExtractedArchive>> extractZip(
    String archive,
    String destination, {
    rml.ExtractProgress? onProgress,
  }) => _callAsync(
    () => rml.extractZip(archive, destination, onProgress: onProgress),
  );

  @override
  Result<int> diskFree(String path) => _call(() => rml.diskFree(path));

  @override
  Result<List<rml.NativeProcess>> findProcesses(String executableName) =>
      _call(() => rml.findProcesses(executableName));

  @override
  Result<void> closeProcess(int pid) => _call(() => rml.closeProcess(pid));

  @override
  Result<void> killProcess(int pid) => _call(() => rml.killProcess(pid));

  @override
  Result<rml.ExecutableInfo> executableInfo(String path) =>
      _call(() => rml.executableInfo(path));

  static Result<T> _call<T>(T Function() body) {
    try {
      return Result<T>.ok(body());
    } on rml.NativeException catch (error, stackTrace) {
      return Result<T>.err(_failure(error, stackTrace));
    } catch (error, stackTrace) {
      return Result<T>.err(
        UnknownFailure(cause: error, stackTrace: stackTrace),
      );
    }
  }

  static Future<Result<T>> _callAsync<T>(Future<T> Function() body) async {
    try {
      return Result<T>.ok(await body());
    } on rml.NativeException catch (error, stackTrace) {
      return Result<T>.err(_failure(error, stackTrace));
    } catch (error, stackTrace) {
      return Result<T>.err(
        UnknownFailure(cause: error, stackTrace: stackTrace),
      );
    }
  }

  static NativeFailure _failure(
    rml.NativeException error,
    StackTrace stackTrace,
  ) => NativeFailure(
    code: error.code,
    message: error.message,
    cause: error,
    stackTrace: stackTrace,
  );
}
