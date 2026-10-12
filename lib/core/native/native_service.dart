import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_native/rml_native.dart' as rml;

export 'package:rml_native/rml_native.dart' show HashAlgorithm;

abstract interface class NativeService {
  String get version;

  bool? get osReducesMotion;

  Future<Result<String>> hashFile(rml.HashAlgorithm algorithm, String path);
}

final class RmlNativeService implements NativeService {
  const RmlNativeService();

  @override
  String get version => rml.nativeVersion();

  @override
  bool? get osReducesMotion {
    try {
      return rml.osReduceMotion();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Result<String>> hashFile(
    rml.HashAlgorithm algorithm,
    String path,
  ) async {
    try {
      return Result<String>.ok(await rml.hashFile(algorithm, path));
    } on rml.RmlNativeException catch (error, stackTrace) {
      return Result<String>.err(
        NativeFailure(
          code: error.code,
          message: error.message,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}
