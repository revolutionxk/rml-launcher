import 'package:rml_launcher/core/storage/file_ops.dart';
import 'package:rml_launcher/features/studio/data/studio_layout.dart';
import 'package:rml_launcher/features/studio/domain/studio_build.dart';

Future<void> deleteManagedBuild(StudioLayout layout, StudioBuild build) async {
  final String dir = layout.buildDirOf(build);
  if (layout.owns(dir)) {
    await deleteQuietly(dir);
  }
}
