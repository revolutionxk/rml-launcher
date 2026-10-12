import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/features/studio/data/cdn/cdn_platform.dart';
import 'package:rml_launcher/features/studio/data/cdn/deploy_history.dart';
import 'package:rml_launcher/features/studio/data/cdn/package_manifest.dart';
import 'package:rml_launcher/features/studio/data/cdn/studio_cdn.dart';
import 'package:rml_launcher/features/studio/domain/studio_version.dart';

final class FakeStudioCdn implements StudioCdn {
  FakeStudioCdn({this.platform = CdnPlatform.windows});

  @override
  final CdnPlatform platform;

  LiveVersion? live;
  final Map<String, String> guids = <String, String>{};
  int liveRequests = 0;

  static const UnsupportedFailure _notFaked = UnsupportedFailure(
    reason: 'not faked',
  );

  @override
  Future<Result<LiveVersion>> liveVersion() async {
    liveRequests++;
    final LiveVersion? current = live;
    return current == null
        ? const Result<LiveVersion>.err(NetworkFailure())
        : Result<LiveVersion>.ok(current);
  }

  @override
  Future<Result<String>> resolveGuid(StudioVersion version) async {
    final LiveVersion? current = live;
    if (current != null && current.version == version) {
      return Result<String>.ok(current.guid);
    }
    final String? guid = guids[version.text];
    return guid == null
        ? const Result<String>.err(_notFaked)
        : Result<String>.ok(guid);
  }

  @override
  Future<Result<List<DeployedBuild>>> deployHistory() async =>
      const Result<List<DeployedBuild>>.err(_notFaked);

  @override
  Future<Result<List<PackageEntry>>> packageManifest(String guid) async =>
      const Result<List<PackageEntry>>.err(_notFaked);

  @override
  Future<Result<List<DeployedBuild>>> availableBuilds({
    Set<StudioVersion> keep = const <StudioVersion>{},
  }) async => const Result<List<DeployedBuild>>.err(_notFaked);

  @override
  Uri packageUrl(String guid, String name) =>
      Uri.parse('http://cdn.invalid/$guid-$name');

  @override
  Uri macAppUrl(String guid) => Uri.parse('http://cdn.invalid/$guid.zip');

  @override
  Future<Result<RemoteFile>> head(Uri url) async =>
      const Result<RemoteFile>.err(_notFaked);
}
