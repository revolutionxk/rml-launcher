import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rml_launcher/core/di/providers.dart';
import 'package:rml_launcher/core/platform/os_reduce_motion.dart';

import '../../support/fake_native_service.dart';
import '../../support/test_dependencies.dart';

void main() {
  testWidgets('reads the OS setting again when the app resumes', (
    WidgetTester tester,
  ) async {
    final FakeNativeService native = FakeNativeService(osReducesMotion: false);
    final ProviderContainer container = ProviderContainer.test(
      overrides: [
        appDependenciesProvider.overrideWithValue(
          testDependencies(native: native),
        ),
      ],
    );
    expect(container.read(osReduceMotionProvider), isFalse);

    native.osReducesMotion = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    expect(container.read(osReduceMotionProvider), isTrue);
  });
}
