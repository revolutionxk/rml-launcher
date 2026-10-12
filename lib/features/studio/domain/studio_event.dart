import 'dart:async';

import 'package:rml_launcher/features/studio/domain/running_studio.dart';
import 'package:rml_launcher/features/studio/domain/studio_build.dart';
import 'package:rml_launcher/features/studio/domain/studio_version.dart';

sealed class StudioEvent {
  const StudioEvent();
}

final class InstallAdded extends StudioEvent {
  const InstallAdded(this.installId);

  final String installId;
}

final class InstallRemoved extends StudioEvent {
  const InstallRemoved(this.installId);

  final String installId;
}

final class BuildInstalled extends StudioEvent {
  const BuildInstalled({required this.installId, required this.version});

  final String installId;
  final StudioVersion version;
}

final class UpdateReady extends StudioEvent {
  const UpdateReady({required this.installId, required this.version});

  final String installId;
  final StudioVersion version;
}

final class UpdateApplied extends StudioEvent {
  const UpdateApplied({
    required this.installId,
    required this.from,
    required this.to,
  });

  final String installId;
  final StudioVersion from;
  final StudioVersion to;
}

final class RolledBack extends StudioEvent {
  const RolledBack({
    required this.installId,
    required this.from,
    required this.to,
  });

  final String installId;
  final StudioVersion from;
  final StudioVersion to;
}

final class FoundBuildChanged extends StudioEvent {
  const FoundBuildChanged({
    required this.installId,
    required this.from,
    required this.to,
  });

  final String installId;
  final StudioBuild from;
  final StudioBuild to;
}

final class StudioStarted extends StudioEvent {
  const StudioStarted(this.studio);

  final RunningStudio studio;
}

final class StudioExited extends StudioEvent {
  const StudioExited(this.studio);

  final RunningStudio studio;
}

final class StudioEvents {
  final StreamController<StudioEvent> _controller =
      StreamController<StudioEvent>.broadcast();

  Stream<StudioEvent> get stream => _controller.stream;

  void emit(StudioEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  Future<void> close() => _controller.close();
}
