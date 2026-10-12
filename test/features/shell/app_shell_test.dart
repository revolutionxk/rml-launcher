import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rml_launcher/app.dart';
import 'package:rml_launcher/core/di/providers.dart';
import 'package:rml_launcher/design/theme/theme.dart';
import 'package:rml_launcher/design/theme/theme_settings.dart';
import 'package:rml_launcher/features/settings/data/app_settings.dart';
import 'package:rml_launcher/features/shell/view/app_shell.dart';
import 'package:rml_launcher/i18n/translations.g.dart';

import '../../support/fake_native_service.dart';
import '../../support/fake_window_chrome.dart';
import '../../support/test_dependencies.dart';

void main() {
  late FakeWindowChrome chrome;

  setUp(() => chrome = FakeWindowChrome());

  Future<void> pumpApp(
    WidgetTester tester, {
    AppSettings settings = AppSettings.defaults,
    FakeNativeService? native,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1180, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDependenciesProvider.overrideWithValue(
            testDependencies(
              settings: settings,
              windowChrome: chrome,
              native: native,
            ),
          ),
        ],
        child: TranslationProvider(child: const LauncherApp()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opens on Home and navigates from the sidebar', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Home'), findsNWidgets(2));
    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    expect(find.text('Library'), findsNWidgets(2));
  });

  Future<void> pressK(WidgetTester tester, LogicalKeyboardKey modifier) async {
    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(modifier);
    await tester.pumpAndSettle();
  }

  testWidgets('control K opens Search', (WidgetTester tester) async {
    await pumpApp(tester);
    await pressK(tester, LogicalKeyboardKey.metaLeft);
    expect(find.text('Search'), findsOneWidget);
    await pressK(tester, LogicalKeyboardKey.controlLeft);
    expect(find.text('Search'), findsNWidgets(2));
  });

  testWidgets('command K opens Search on macOS', (WidgetTester tester) async {
    await pumpApp(tester);
    await pressK(tester, LogicalKeyboardKey.controlLeft);
    expect(find.text('Search'), findsOneWidget);
    await pressK(tester, LogicalKeyboardKey.metaLeft);
    expect(find.text('Search'), findsNWidgets(2));
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('window buttons drive the window on Windows', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.bySemanticsLabel('Minimize'));
    await tester.tap(find.bySemanticsLabel('Maximize'));
    await tester.tap(find.bySemanticsLabel('Close'));
    expect(chrome.minimizes, 1);
    expect(chrome.maximizes, 1);
    expect(chrome.closes, 1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('macOS leaves the window buttons to the system', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    expect(find.bySemanticsLabel('Close'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('mode System follows the OS while the app runs', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await pumpApp(tester);
    expect(
      Theme.of(tester.element(find.byType(AppShell))).brightness,
      Brightness.light,
    );
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(AppShell))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('reduce motion System follows the OS setting', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, native: FakeNativeService(osReducesMotion: true));
    expect(
      Theme.of(tester.element(find.byType(AppShell))).motion.reduced,
      isTrue,
    );
  });

  testWidgets('reduce motion Off ignores the OS setting', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      settings: AppSettings.defaults.copyWith(
        reduceMotion: ReduceMotionSetting.off,
      ),
      native: FakeNativeService(osReducesMotion: true),
    );
    expect(
      Theme.of(tester.element(find.byType(AppShell))).motion.reduced,
      isFalse,
    );
  });
}
