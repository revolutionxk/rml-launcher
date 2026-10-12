import 'package:rml_launcher/core/result/result.dart';
import 'package:rml_launcher/features/studio/domain/studio_install.dart';
import 'package:rml_launcher/features/studio/domain/studio_version.dart';

typedef PreLaunchHook = Future<Result<void>> Function(StudioInstall install);

typedef UpdateGate = Future<UpdateReview> Function(
  StudioInstall install,
  StudioVersion candidate,
);

final class UpdateReview {
  const UpdateReview({
    this.blockers = const <String>[],
    this.warnings = const <String>[],
  });

  final List<String> blockers;
  final List<String> warnings;

  bool get blocked => blockers.isNotEmpty;
}

final class StudioHooks {
  StudioHooks({UpdateGate? updateGate}) : updateGate = updateGate ?? _openGate;

  final List<PreLaunchHook> preLaunch = <PreLaunchHook>[];
  final Set<String> carryOver = <String>{'ClientSettings'};
  UpdateGate updateGate;

  static Future<UpdateReview> _openGate(
    StudioInstall install,
    StudioVersion candidate,
  ) async => const UpdateReview();
}
