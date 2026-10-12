import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:rml_launcher/design/icons/rml_icons.dart';
import 'package:rml_launcher/design/theme/rml_theme.dart';
import 'package:rml_launcher/features/shell/view/drag_area.dart';
import 'package:rml_launcher/features/shell/view/nav_item.dart';
import 'package:rml_launcher/i18n/translations.g.dart';
import 'package:rml_launcher/routing/routes.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({required this.location, super.key});

  final String location;

  @override
  Widget build(BuildContext context) {
    final Translations t = context.t;
    final bool mac = defaultTargetPlatform == TargetPlatform.macOS;
    final Widget brand = _Brand(name: t.app.name);
    return SizedBox(
      width: 212,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (mac) ...<Widget>[
              const DragArea(child: SizedBox(height: 40)),
              brand,
            ] else
              DragArea(child: brand),
            const SizedBox(height: 8),
            _item(
              context,
              Routes.home,
              RmlIcons.house,
              RmlIcons.houseFill,
              t.nav.home,
            ),
            _item(
              context,
              Routes.library,
              RmlIcons.stack,
              RmlIcons.stackFill,
              t.nav.library,
            ),
            _item(
              context,
              Routes.store,
              RmlIcons.storefront,
              RmlIcons.storefrontFill,
              t.nav.store,
            ),
            _item(
              context,
              Routes.search,
              RmlIcons.magnifyingGlass,
              RmlIcons.magnifyingGlassFill,
              t.nav.search,
              trailing: t.nav.searchShortcut(modifier: mac ? '⌘' : 'Ctrl'),
            ),
            const Spacer(),
            _item(
              context,
              Routes.settings,
              RmlIcons.gearSix,
              RmlIcons.gearSixFill,
              t.nav.settings,
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context,
    String route,
    IconData icon,
    IconData selectedIcon,
    String label, {
    String? trailing,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: NavItem(
      icon: icon,
      selectedIcon: selectedIcon,
      label: label,
      selected: location.startsWith(route),
      trailing: trailing,
      onPressed: () => context.go(route),
    ),
  );
}

class _Brand extends StatelessWidget {
  const _Brand({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final RmlThemeData theme = RmlTheme.of(context);
    return SizedBox(
      height: 40,
      child: Row(
        children: <Widget>[
          const SizedBox(width: 10),
          Image.asset('assets/brand/rml-r.png', width: 20, height: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.bodyStrong.copyWith(
                color: theme.colors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
