import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rml_launcher/design/theme/rml_theme.dart';
import 'package:rml_launcher/features/settings/data/app_settings.dart';
import 'package:rml_launcher/features/settings/settings_controller.dart';
import 'package:rml_launcher/i18n/translations.g.dart';
import 'package:rml_launcher/routing/app_router.dart';

class RmlApp extends ConsumerWidget {
  const RmlApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings = ref.watch(settingsControllerProvider);
    final GoRouter router = ref.watch(appRouterProvider);
    return WidgetsApp.router(
      routerConfig: router,
      title: 'RML Launcher',
      color: const Color(0xFF6E99CA),
      debugShowCheckedModeBanner: false,
      locale: TranslationProvider.of(context).flutterLocale,
      supportedLocales: AppLocaleUtils.supportedLocales,
      builder: (BuildContext context, Widget? child) {
        final RmlThemeData theme = RmlThemeData.resolve(
          palette: settings.palette,
          mode: settings.mode,
          reduceMotion: settings.reduceMotion,
          platformBrightness: MediaQuery.platformBrightnessOf(context),
          platformDisablesAnimations: MediaQuery.disableAnimationsOf(context),
        );
        return RmlTheme(
          data: theme,
          child: DefaultTextStyle(
            style: theme.typography.body.copyWith(color: theme.colors.text),
            child: ColoredBox(
              color: theme.colors.chrome,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}
