import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:rml_launcher/core/native/native_service.dart';
import 'package:rml_launcher/core/platform/app_paths.dart';
import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/core/storage/file_ops.dart';
import 'package:rml_launcher/core/tasks/studio_task.dart';
import 'package:rml_launcher/core/tasks/task_center.dart';
import 'package:rml_launcher/features/studio/data/cdn/package_manifest.dart';
import 'package:rml_launcher/features/studio/data/cdn/studio_cdn.dart';
import 'package:rml_launcher/features/studio/data/download/downloader.dart';
import 'package:rml_launcher/features/studio/data/install/build_installer.dart';
import 'package:rml_launcher/features/studio/data/install/carry_over.dart';
import 'package:rml_launcher/features/studio/data/install/file_record.dart';
import 'package:rml_launcher/features/studio/data/install/install_progress.dart';
import 'package:rml_launcher/features/studio/data/install/windows_build_installer.dart';
import 'package:rml_launcher/features/studio/data/library_store.dart';
import 'package:rml_launcher/features/studio/data/studio_layout.dart';
import 'package:rml_launcher/features/studio/domain/studio_build.dart';
import 'package:rml_launcher/features/studio/domain/studio_hooks.dart';
import 'package:rml_launcher/features/studio/domain/studio_install.dart';
import 'package:rml_launcher/features/studio/domain/studio_library.dart';
import 'package:rml_launcher/features/studio/services/build_fetcher.dart';
import 'package:rml_launcher/features/studio/services/running_watcher.dart';

final class CheckReport {
  const CheckReport({
    this.repairedPackages = const <String>[],
    this.rewrittenFiles = const <String>[],
    this.reinstalled = false,
  });

  final List<String> repairedPackages;
  final List<String> rewrittenFiles;
  final bool reinstalled;

  bool get clean =>
      repairedPackages.isEmpty && rewrittenFiles.isEmpty && !reinstalled;
}

final class CheckFilesService {
  CheckFilesService({
    required this._library,
    required this._tasks,
    required this._fetcher,
    required this._downloader,
    required this._native,
    required this._layout,
    required this._running,
    required this._hooks,
  });

  final LibraryStore _library;
  final TaskCenter _tasks;
  final BuildFetcher _fetcher;
  final Downloader? _downloader;
  final NativeService _native;
  final StudioLayout _layout;
  final RunningWatcher _running;
  final StudioHooks _hooks;

  Future<Result<CheckReport>> check(String installId) async {
    final StudioInstall? install = _library.value.byId(installId);
    final StudioBuild? build = install?.current;
    if (install == null || build == null) {
      return const Result<CheckReport>.err(
        NotFoundFailure(what: 'Studio build'),
      );
    }
    final StudioCdn? cdn = _fetcher.cdn;
    final BuildInstaller? installer = _fetcher.installer;
    final Downloader? downloader = _downloader;
    if (!install.isManaged ||
        cdn == null ||
        installer == null ||
        downloader == null) {
      return const Result<CheckReport>.err(BuildFetcher.unavailable);
    }
    if (_running.isRunning(installId)) {
      return Result<CheckReport>.err(
        StudioRunningFailure(installId: installId),
      );
    }
    return _tasks.run<CheckReport>(
      TaskRequest(
        kind: TaskKind.checkFiles,
        installId: installId,
        version: build.version.text,
      ),
      (TaskControl control) => _layout.os == HostOs.macos
          ? _checkMac(installId, build, cdn, installer, control)
          : _checkWindows(installId, build, cdn, downloader, control),
    );
  }

  Future<Result<CheckReport>> _checkWindows(
    String installId,
    StudioBuild build,
    StudioCdn cdn,
    Downloader downloader,
    TaskControl control,
  ) async {
    if (_running.isRunning(installId)) {
      return Result<CheckReport>.err(
        StudioRunningFailure(installId: installId),
      );
    }
    control.phase(TaskPhase.resolving);
    final String? known = build.guid;
    final Result<String> resolved = known != null
        ? Result<String>.ok(known)
        : await cdn.resolveGuid(build.version);
    final String? guid = resolved.valueOrNull;
    if (guid == null) {
      return Result<CheckReport>.err(resolved.failureOrNull!);
    }
    final Result<List<PackageEntry>> manifest = await cdn.packageManifest(guid);
    final List<PackageEntry>? packages = manifest.valueOrNull;
    if (packages == null) {
      return Result<CheckReport>.err(manifest.failureOrNull!);
    }
    final String dir = build.path;
    FileRecord record = await FileRecord.read(dir);
    final List<PackageEntry> broken = packages
        .where(
          (PackageEntry entry) =>
              !_intact(dir, record.packages[entry.name], entry),
        )
        .toList();
    final List<String> rewritten = <String>[];
    try {
      for (final MapEntry<String, String> file
          in WindowsBuildInstaller.runtimeFiles(build.version, guid).entries) {
        final File target = File(
          p.joinAll(<String>[dir, ...file.key.split('/')]),
        );
        if (!target.existsSync() || target.readAsStringSync() != file.value) {
          await WindowsBuildInstaller.writeRuntimeFile(
            dir,
            file.key,
            file.value,
          );
          rewritten.add(file.key);
        }
      }
    } on FileSystemException catch (error, stackTrace) {
      return Result<CheckReport>.err(
        IoFailure(path: dir, cause: error, stackTrace: stackTrace),
      );
    }
    if (broken.isNotEmpty) {
      control.phase(TaskPhase.downloading);
      final String downloads = _layout.downloadsDir(build.version);
      final InstallProgress progress = InstallProgress(
        control,
        packed: broken.fold(0, (int sum, PackageEntry e) => sum + e.packedSize),
        unpacked: broken.fold(
          0,
          (int sum, PackageEntry e) => sum + e.unpackedSize,
        ),
      );
      for (final PackageEntry entry in broken) {
        final Result<PackageRecord> repaired = await _repair(
          entry,
          guid,
          build,
          downloads,
          cdn,
          downloader,
          control,
          progress,
        );
        final PackageRecord? fresh = repaired.valueOrNull;
        if (fresh == null) {
          await record.write(dir);
          return Result<CheckReport>.err(repaired.failureOrNull!);
        }
        record = record.withPackage(entry.name, fresh);
      }
      await deleteQuietly(downloads);
    }
    await record.write(dir);
    _progressDone(control);
    return Result<CheckReport>.ok(
      CheckReport(
        repairedPackages: broken.map((PackageEntry e) => e.name).toList(),
        rewrittenFiles: rewritten,
      ),
    );
  }

  Future<Result<PackageRecord>> _repair(
    PackageEntry entry,
    String guid,
    StudioBuild build,
    String downloads,
    StudioCdn cdn,
    Downloader downloader,
    TaskControl control,
    InstallProgress progress,
  ) async {
    final String archive = p.join(downloads, entry.name);
    final Result<void> downloaded = await downloader.download(
      DownloadRequest(
        url: cdn.packageUrl(guid, entry.name),
        path: archive,
        size: entry.packedSize,
        md5: entry.md5,
      ),
      abort: control.abort,
      onBytes: progress.downloaded,
    );
    if (downloaded.failureOrNull case final AppFailure failure) {
      return Result<PackageRecord>.err(failure);
    }
    final String root = extractionRoot(entry.stem, build.version.major);
    final String destination = root.isEmpty
        ? build.path
        : p.joinAll(<String>[build.path, ...root.split('/')]);
    final Result<ExtractedArchive> extracted = await _native.extractZip(
      archive,
      destination,
      onProgress: (int done, int total) =>
          progress.extracted(entry.name, done, total),
    );
    return extracted.map(
      (ExtractedArchive files) => PackageRecord(
        md5: entry.md5,
        files: <String, int>{
          for (final ExtractedFile file in files.files)
            root.isEmpty ? file.path : '$root/${file.path}': file.size,
        },
      ),
    );
  }

  Future<Result<CheckReport>> _checkMac(
    String installId,
    StudioBuild build,
    StudioCdn cdn,
    BuildInstaller installer,
    TaskControl control,
  ) async {
    if (File(_layout.studioExecutable(build)).existsSync()) {
      return const Result<CheckReport>.ok(CheckReport());
    }
    if (_running.isRunning(installId)) {
      return Result<CheckReport>.err(
        StudioRunningFailure(installId: installId),
      );
    }
    control.phase(TaskPhase.resolving);
    final Result<LiveVersion> live = await cdn.liveVersion();
    final LiveVersion? latest = live.valueOrNull;
    if (latest == null) {
      return Result<CheckReport>.err(live.failureOrNull!);
    }
    if (latest.version != build.version) {
      return Result<CheckReport>.err(
        UnsupportedFailure(
          reason:
              'Roblox only publishes Studio ${latest.version.short} for macOS, so ${build.version.short} cannot be repaired.',
        ),
      );
    }
    final Result<InstalledBuild> reinstalled = await installer.install(
      BuildRequest(
        installId: installId,
        version: build.version,
        guid: latest.guid,
      ),
      control,
    );
    final InstalledBuild? fresh = reinstalled.valueOrNull;
    if (fresh == null) {
      return Result<CheckReport>.err(reinstalled.failureOrNull!);
    }
    final String? old = fresh.replacedDir;
    if (old != null) {
      final Result<List<String>> moved = await moveCarryOver(
        _hooks.carryOver,
        from: p.join(old, StudioLayout.appBundle, 'Contents', 'MacOS'),
        to: _layout.payloadDir(fresh.build),
      );
      if (moved.failureOrNull case final AppFailure failure) {
        return Result<CheckReport>.err(failure);
      }
      if (_layout.owns(old)) {
        await deleteQuietly(old);
      }
    }
    await _library.update((StudioLibrary library) {
      final StudioInstall? install = library.byId(installId);
      return install == null
          ? library
          : library.upsert(install.copyWith(current: fresh.build));
    });
    return const Result<CheckReport>.ok(CheckReport(reinstalled: true));
  }

  static void _progressDone(TaskControl control) =>
      control.report(const TaskProgress(fraction: 1));

  static bool _intact(String dir, PackageRecord? record, PackageEntry entry) {
    if (record == null || record.md5 != entry.md5) {
      return false;
    }
    for (final MapEntry<String, int> file in record.files.entries) {
      final File target = File(
        p.joinAll(<String>[dir, ...file.key.split('/')]),
      );
      if (!target.existsSync() || target.lengthSync() != file.value) {
        return false;
      }
    }
    return true;
  }
}
