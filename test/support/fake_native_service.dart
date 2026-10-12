import 'package:rml_launcher/core/native/native_service.dart';
import 'package:rml_launcher/core/result/result.dart';

final class FakeNativeService implements NativeService {
  FakeNativeService({this.osReducesMotion, this.version = '0.1.0'});

  @override
  final String? version;

  @override
  bool? osReducesMotion;

  @override
  Future<Result<String>> hashFile(HashAlgorithm algorithm, String path) async =>
      const Result<String>.ok('fake');
}
