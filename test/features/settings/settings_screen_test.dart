import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rml_launcher/app.dart';
import 'package:rml_launcher/core/di/providers.dart';
import 'package:rml_launcher/design/theme/rml_theme.dart';
import 'package:rml_launcher/design/tokens/rml_colors.dart';
import 'package:rml_launcher/features/shell/view/app_shell.dart';
import 'package:rml_launcher/i18n/translations.g.dart';

import '../../support/fake_native_service.dart';
import '../../support/test_dependencies.dart';

void main() {
  tearDown(() => LocaleSettings.setLocale(AppLocale.en));

  Future<void> openSettings(
    WidgetTester tester, {
    FakeNativeService? native,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1180, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDependenciesProvider.overrideWithValue(
            testDependencies(native: native),
          ),
        ],
        child: TranslationProvider(child: const RmlApp()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
  }

  testWidgets('choosing a palette restyles the app', (
    WidgetTester tester,
  ) async {
    await openSettings(tester);
    await tester.tap(find.text('Stone and sand'));
    await tester.pumpAndSettle();
    expect(
      RmlTheme.of(tester.element(find.byType(AppShell))).palette,
      RmlPalette.stoneAndSand,
    );
  });

  testWidgets('choosing Portuguese translates the app', (
    WidgetTester tester,
  ) async {
    await openSettings(tester);
    await tester.tap(find.text('Português (Brasil)'));
    await tester.pumpAndSettle();
    expect(find.text('Configurações'), findsWidgets);
    expect(find.text('Aparência'), findsOneWidget);
  });

  testWidgets('shows the app version', (WidgetTester tester) async {
    await openSettings(tester);
    expect(find.text('RML Launcher 2.0.0-dev'), findsOneWidget);
  });

  testWidgets('shows the native library version', (WidgetTester tester) async {
    await openSettings(tester);
    expect(find.text('Native library 0.1.0'), findsOneWidget);
  });

  testWidgets('hides the native library version when it cannot be read', (
    WidgetTester tester,
  ) async {
    await openSettings(tester, native: FakeNativeService(version: null));
    expect(find.textContaining('Native library'), findsNothing);
  });
}
