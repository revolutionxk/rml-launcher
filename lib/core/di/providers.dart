import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rml_launcher/core/di/app_dependencies.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
AppDependencies appDependencies(Ref ref) =>
    throw UnimplementedError('appDependencies must be overridden at startup');
