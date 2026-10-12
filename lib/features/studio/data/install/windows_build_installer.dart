import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:rml_launcher/core/async/abort_signal.dart';
import 'package:rml_launcher/core/native/native_service.dart';
import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/core/tasks/studio_task.dart';
import 'package:rml_launcher/core/tasks/task_center.dart';
import 'package:rml_launcher/features/studio/data/cdn/package_manifest.dart';
import 'package:rml_launcher/features/studio/data/cdn/runtime_files.dart';
import 'package:rml_launcher/features/studio/data/cdn/studio_cdn.dart';
import 'package:rml_launcher/features/studio/data/download/downloader.dart';
import 'package:rml_launcher/features/studio/data/install/build_installer.dart';
import 'package:rml_launcher/features/studio/data/install/build_marker.dart';
import 'package:rml_launcher/features/studio/data/install/file_record.dart';
import 'package:rml_launcher/features/studio/data/install/install_progress.dart';
import 'package:rml_launcher/features/studio/data/install/staging_area.dart';
import 'package:rml_launcher/features/studio/data/studio_layout.dart';
import 'package:rml_launcher/features/studio/domain/studio_version.dart';

final class WindowsBuildInstaller implements BuildInstaller {
  WindowsBuildInstaller({
    required this._cdn,
    required this._downloader,
    required this._native,
    required this._layout,
    required this._staging,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  static const String binaryTarget = 'WindowsStudio64';

  final StudioCdn _cdn;
  final Downloader _downloader;
  final NativeService _native;
  final StudioLayout _layout;
  final StagingArea _staging;
  final DateTime Function() _clock;

  static Map<String, String> runtimeFiles(StudioVersion version, String guid) =>
      <String, String>{
        'AppSettings.xml': RuntimeFiles.appSettingsXml,
        'ApplicationConfig/OAuth2Config.json': RuntimeFiles.oauth2ConfigJson,
        'version.txt': version.text,
        'version-guid.txt': guid,
      };

  static Future<void> writeRuntimeFile(
    String buildDir,
    String relative,
    String content,
  ) async {
    final File file = File(
      p.joinAll(<String>[buildDir, ...relative.split('/')]),
    );
    await file.parent.create(recursive: true);
    await file.writeAsString(content, flush: true);
  }

  @override
  Future<Result<InstalledBuild>> install(
    BuildRequest request,
    TaskControl control,
  ) async {
    control.phase(TaskPhase.resolving);
    final Result<List<PackageEntry>> manifest = await _cdn.packageManifest(
      request.guid,
    );
    final List<PackageEntry>? packages = manifest.valueOrNull;
    if (packages == null) {
      return Result<InstalledBuild>.err(manifest.failureOrNull!);
    }
    final String downloads = _layout.downloadsDir(request.version);
    final int packed = packages.fold(
      0,
      (int sum, PackageEntry entry) => sum + entry.packedSize,
    );
    final int unpacked = packages.fold(
      0,
      (int sum, PackageEntry entry) => sum + entry.unpackedSize,
    );
    final Result<void> space = _staging.ensureSpace(
      ((packed - _bytesOnDisk(downloads, packages) + unpacked) * 1.1).ceil(),
    );
    if (space.failureOrNull case final AppFailure failure) {
      return Result<InstalledBuild>.err(failure);
    }
    final Result<String> prepared = await _staging.prepare(
      request.installId,
      request.version,
    );
    final String? staging = prepared.valueOrNull;
    if (staging == null) {
      return Result<InstalledBuild>.err(prepared.failureOrNull!);
    }
    final InstallProgress progress = InstallProgress(
      control,
      packed: packed,
      unpacked: unpacked,
      clock: _clock,
    );
    control.phase(TaskPhase.downloading);
    final AbortSignal abort = AbortSignal.linkedTo(control.abort);
    final List<Result<MapEntry<String, PackageRecord>>> results =
        await Future.wait(
          packages.map(
            (PackageEntry entry) => _installPackage(
              entry,
              request,
              downloads,
              staging,
              abort,
              progress,
            ),
          ),
        );
    final AppFailure? failure = _firstFailure(results, control.abort);
    if (failure != null) {
      await _staging.discard(staging);
      return Result<InstalledBuild>.err(failure);
    }
    control.phase(TaskPhase.finalizing);
    try {
      for (final MapEntry<String, String> file in runtimeFiles(
        request.version,
        request.guid,
      ).entries) {
        await writeRuntimeFile(staging, file.key, file.value);
      }
      await FileRecord(
        Map<String, PackageRecord>.fromEntries(
          results.map(
            (Result<MapEntry<String, PackageRecord>> result) =>
                result.valueOrNull!,
          ),
        ),
      ).write(staging);
    } on FileSystemException catch (error, stackTrace) {
      await _staging.discard(staging);
      return Result<InstalledBuild>.err(
        IoFailure(path: staging, cause: error, stackTrace: stackTrace),
      );
    }
    final Result<InstalledBuild> committed = await _staging.commit(
      installId: request.installId,
      staging: staging,
      marker: BuildMarker(
        version: request.version,
        guid: request.guid,
        binaryTarget: binaryTarget,
        installedAt: _clock(),
        publishedAt: request.publishedAt,
      ),
    );
    if (committed.isErr) {
      await _staging.discard(staging);
    } else {
      progress.finish();
    }
    return committed;
  }

  Future<Result<MapEntry<String, PackageRecord>>> _installPackage(
    PackageEntry entry,
    BuildRequest request,
    String downloads,
    String staging,
    AbortSignal abort,
    InstallProgress progress,
  ) async {
    final String archive = p.join(downloads, entry.name);
    final Result<void> downloaded = await _downloader.download(
      DownloadRequest(
        url: _cdn.packageUrl(request.guid, entry.name),
        path: archive,
        size: entry.packedSize,
        md5: entry.md5,
      ),
      abort: abort,
      onBytes: progress.downloaded,
    );
    if (downloaded.failureOrNull case final AppFailure failure) {
      abort.abort();
      return Result<MapEntry<String, PackageRecord>>.err(failure);
    }
    if (abort.isAborted) {
      return const Result<MapEntry<String, PackageRecord>>.err(
        CancelledFailure(),
      );
    }
    final String root = extractionRoot(entry.stem, request.version.major);
    final String destination = root.isEmpty
        ? staging
        : p.joinAll(<String>[staging, ...root.split('/')]);
    final Result<ExtractedArchive> extracted = await _native.extractZip(
      archive,
      destination,
      onProgress: (int done, int total) =>
          progress.extracted(entry.name, done, total),
    );
    final ExtractedArchive? files = extracted.valueOrNull;
    if (files == null) {
      abort.abort();
      return Result<MapEntry<String, PackageRecord>>.err(
        extracted.failureOrNull!,
      );
    }
    progress.extracted(entry.name, files.bytes, files.bytes);
    return Result<MapEntry<String, PackageRecord>>.ok(
      MapEntry<String, PackageRecord>(
        entry.name,
        PackageRecord(
          md5: entry.md5,
          files: <String, int>{
            for (final ExtractedFile file in files.files)
              root.isEmpty ? file.path : '$root/${file.path}': file.size,
          },
        ),
      ),
    );
  }

  static int _bytesOnDisk(String downloads, List<PackageEntry> packages) {
    int total = 0;
    for (final PackageEntry entry in packages) {
      final File done = File(p.join(downloads, entry.name));
      final File partial = File('${done.path}.partial');
      if (done.existsSync()) {
        total += done.lengthSync();
      } else if (partial.existsSync()) {
        total += partial.lengthSync();
      }
    }
    return total;
  }

  static AppFailure? _firstFailure<T>(
    List<Result<T>> results,
    AbortSignal abort,
  ) {
    if (abort.isAborted) {
      return const CancelledFailure();
    }
    AppFailure? first;
    for (final Result<T> result in results) {
      final AppFailure? failure = result.failureOrNull;
      if (failure != null && failure is! CancelledFailure) {
        return failure;
      }
      first ??= failure;
    }
    return first;
  }
}
