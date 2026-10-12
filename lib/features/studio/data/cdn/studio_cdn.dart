import 'dart:convert';
import 'dart:io';

import 'package:rml_launcher/core/net/http.dart';
import 'package:rml_launcher/core/net/retry.dart';
import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/features/studio/data/cdn/cdn_platform.dart';
import 'package:rml_launcher/features/studio/data/cdn/deploy_history.dart';
import 'package:rml_launcher/features/studio/data/cdn/package_manifest.dart';
import 'package:rml_launcher/features/studio/domain/studio_version.dart';

export 'package:rml_launcher/core/net/http.dart' show RemoteFile;

final class LiveVersion {
  const LiveVersion({required this.version, required this.guid});

  final StudioVersion version;
  final String guid;
}

abstract interface class StudioCdn {
  CdnPlatform get platform;

  Future<Result<LiveVersion>> liveVersion();

  Future<Result<List<DeployedBuild>>> deployHistory();

  Future<Result<String>> resolveGuid(StudioVersion version);

  Future<Result<List<PackageEntry>>> packageManifest(String guid);

  Future<Result<List<DeployedBuild>>> availableBuilds({
    Set<StudioVersion> keep,
  });

  Uri packageUrl(String guid, String name);

  Uri macAppUrl(String guid);

  Future<Result<RemoteFile>> head(Uri url);
}

final class RobloxCdn implements StudioCdn {
  RobloxCdn({
    required this._client,
    required this.platform,
    CdnEndpoints? endpoints,
    this._retry = RetryPolicy.standard,
    this._readTimeout = readTimeout,
  }) : _endpoints = endpoints ?? CdnEndpoints.roblox;

  @override
  final CdnPlatform platform;

  final HttpClient _client;
  final CdnEndpoints _endpoints;
  final RetryPolicy _retry;
  final Duration _readTimeout;
  Map<String, String>? _ledgerCache;

  Future<Result<String>> _text(Uri url) =>
      fetchText(_client, url, retry: _retry, readTimeout: _readTimeout);

  @override
  Future<Result<LiveVersion>> liveVersion() async {
    final Result<String> text = await _text(
      _endpoints.clientSettings.resolve(
        '${platform.binaryTarget}/channel/LIVE',
      ),
    );
    return text.flatMap((String body) async {
      final Object? json = _decode(body);
      if (json case {
        'version': final String version,
        'clientVersionUpload': final String guid,
      }) {
        final StudioVersion? parsed = StudioVersion.tryParse(version);
        if (parsed != null) {
          return Result<LiveVersion>.ok(
            LiveVersion(version: parsed, guid: guid),
          );
        }
      }
      return const Result<LiveVersion>.err(
        ValidationFailure(message: 'Unexpected client version response'),
      );
    });
  }

  @override
  Future<Result<List<DeployedBuild>>> deployHistory() async {
    final Result<String> text = await _text(
      _endpoints.setup.resolve('${platform.folder}DeployHistory.txt'),
    );
    return text.map(
      (String body) => parseDeployHistory(body, product: platform.product),
    );
  }

  @override
  Future<Result<String>> resolveGuid(StudioVersion version) async {
    final LiveVersion? live = (await liveVersion()).valueOrNull;
    if (live != null && live.version == version) {
      return Result<String>.ok(live.guid);
    }
    final Result<String> missing = Result<String>.err(
      UnsupportedFailure(
        reason: "Roblox doesn't publish a download for Studio ${version.text}.",
      ),
    );
    if (platform.isMac) {
      return missing;
    }
    final Result<Map<String, String>> ledger = await _ledger();
    return ledger.flatMap((Map<String, String> guids) async {
      final String? guid = guids[version.text];
      return guid == null ? missing : Result<String>.ok(guid);
    });
  }

  @override
  Future<Result<List<PackageEntry>>> packageManifest(String guid) async {
    final Result<String> text = await _text(
      _endpoints.setup.resolve('$guid-rbxPkgManifest.txt'),
    );
    return text.flatMap((String body) async => parsePackageManifest(body));
  }

  @override
  Future<Result<List<DeployedBuild>>> availableBuilds({
    Set<StudioVersion> keep = const <StudioVersion>{},
  }) async {
    final Result<List<DeployedBuild>> history = await deployHistory();
    final List<DeployedBuild>? builds = history.valueOrNull;
    if (builds == null || platform.isMac) {
      return history;
    }
    final Map<String, String>? ledger = (await _ledger()).valueOrNull;
    if (ledger == null) {
      return history;
    }
    final StudioVersion? live = (await liveVersion()).valueOrNull?.version;
    return Result<List<DeployedBuild>>.ok(
      builds
          .where(
            (DeployedBuild build) =>
                ledger.containsKey(build.version.text) ||
                keep.contains(build.version) ||
                build.version == live,
          )
          .toList(),
    );
  }

  @override
  Uri packageUrl(String guid, String name) =>
      _endpoints.setup.resolve('$guid-$name');

  @override
  Uri macAppUrl(String guid) =>
      _endpoints.setup.resolve('${platform.folder}$guid-RobloxStudioApp.zip');

  @override
  Future<Result<RemoteFile>> head(Uri url) =>
      fetchHead(_client, url, retry: _retry, readTimeout: _readTimeout);

  Future<Result<Map<String, String>>> _ledger() async {
    final Map<String, String>? cached = _ledgerCache;
    if (cached != null) {
      return Result<Map<String, String>>.ok(cached);
    }
    final Result<String> text = await _text(_endpoints.ledger);
    return text.map((String body) {
      final Object? json = _decode(body);
      final Map<String, String> guids = <String, String>{
        if (json is Map<String, Object?>)
          for (final MapEntry<String, Object?> entry in json.entries)
            if (entry.value case final String guid) entry.key: guid,
      };
      _ledgerCache = guids;
      return guids;
    });
  }

  static Object? _decode(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }
}
