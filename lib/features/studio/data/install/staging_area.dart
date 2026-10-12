import 'dart:io';

import 'package:rml_launcher/core/native/native_service.dart';
import 'package:rml_launcher/core/result/app_failure.dart';
import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/core/storage/file_ops.dart';
import 'package:rml_launcher/features/studio/data/install/build_installer.dart';
import 'package:rml_launcher/features/studio/data/install/build_marker.dart';
import 'package:rml_launcher/features/studio/data/studio_layout.dart';
import 'package:rml_launcher/features/studio/domain/studio_build.dart';
import 'package:rml_launcher/features/studio/domain/studio_version.dart';

final class StagingArea {
  StagingArea({required this._layout, required this._native});

  final StudioLayout _layout;
  final NativeService _native;

  Result<void> ensureSpace(int neededBytes) {
    final Result<int> free = _native.diskFree(_layout.root);
    final int? available = free.valueOrNull;
    if (available == null) {
      return Result<void>.err(free.failureOrNull!);
    }
    if (available >= neededBytes) {
      return const Result<void>.ok(null);
    }
    return Result<void>.err(
      InsufficientSpaceFailure(
        neededBytes: neededBytes,
        freeBytes: available,
        volume: _layout.volume,
      ),
    );
  }

  Future<Result<String>> prepare(
    String installId,
    StudioVersion version,
  ) async {
    final String staging = _layout.stagingDir(installId, version);
    try {
      await deleteQuietly(staging);
      if (FileSystemEntity.typeSync(staging, followLinks: false) !=
          FileSystemEntityType.notFound) {
        return Result<String>.err(IoFailure(path: staging));
      }
      await Directory(staging).create(recursive: true);
      return Result<String>.ok(staging);
    } on FileSystemException catch (error, stackTrace) {
      return Result<String>.err(
        IoFailure(path: staging, cause: error, stackTrace: stackTrace),
      );
    }
  }

  Future<Result<InstalledBuild>> commit({
    required String installId,
    required String staging,
    required BuildMarker marker,
  }) async {
    final String target = _layout.buildDir(installId, marker.version);
    final String replaced = _layout.replacedDir(installId, marker.version);
    try {
      await marker.write(staging);
    } on FileSystemException catch (error, stackTrace) {
      return Result<InstalledBuild>.err(
        IoFailure(path: staging, cause: error, stackTrace: stackTrace),
      );
    }
    String? moved;
    try {
      if (Directory(target).existsSync()) {
        await deleteQuietly(replaced);
        await renameWithRetry(Directory(target), replaced);
        moved = replaced;
      }
      await renameWithRetry(Directory(staging), target);
      return Result<InstalledBuild>.ok(
        InstalledBuild(
          build: StudioBuild(
            version: marker.version,
            guid: marker.guid,
            path: _layout.buildPathIn(target),
            installedAt: marker.installedAt,
            publishedAt: marker.publishedAt,
          ),
          replacedDir: moved,
        ),
      );
    } on FileSystemException catch (error, stackTrace) {
      if (moved != null) {
        try {
          await renameWithRetry(Directory(moved), target);
        } on FileSystemException {
          return Result<InstalledBuild>.err(
            IoFailure(path: target, cause: error, stackTrace: stackTrace),
          );
        }
      }
      return Result<InstalledBuild>.err(
        IoFailure(path: target, cause: error, stackTrace: stackTrace),
      );
    }
  }

  Future<void> discard(String staging) => deleteQuietly(staging);
}
