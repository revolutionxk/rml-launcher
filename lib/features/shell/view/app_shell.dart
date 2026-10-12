import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:rml_launcher/design/theme/rml_theme.dart';
import 'package:rml_launcher/design/tokens/rml_colors.dart';
import 'package:rml_launcher/features/shell/view/sidebar.dart';
import 'package:rml_launcher/features/shell/view/title_bar.dart';
import 'package:rml_launcher/routing/routes.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final RmlColors colors = RmlTheme.of(context).colors;
    final SingleActivator search = defaultTargetPlatform == TargetPlatform.macOS
        ? const SingleActivator(LogicalKeyboardKey.keyK, meta: true)
        : const SingleActivator(LogicalKeyboardKey.keyK, control: true);
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        search: () => context.go(Routes.search),
      },
      child: Focus(
        autofocus: true,
        child: ColoredBox(
          color: colors.chrome,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Sidebar(location: location),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const TitleBar(),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(10),
                        ),
                        child: ColoredBox(color: colors.panel, child: child),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
