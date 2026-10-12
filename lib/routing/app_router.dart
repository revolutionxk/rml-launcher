import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rml_launcher/features/home/view/home_screen.dart';
import 'package:rml_launcher/features/library/view/library_screen.dart';
import 'package:rml_launcher/features/search/view/search_screen.dart';
import 'package:rml_launcher/features/settings/view/settings_screen.dart';
import 'package:rml_launcher/features/shell/view/app_shell.dart';
import 'package:rml_launcher/features/store/view/store_screen.dart';
import 'package:rml_launcher/routing/routes.dart';

part 'app_router.g.dart';

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final GoRouter router = GoRouter(
    initialLocation: Routes.home,
    routes: <RouteBase>[
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) =>
            AppShell(location: state.uri.path, child: child),
        routes: <RouteBase>[
          _page(Routes.home, const HomeScreen()),
          _page(Routes.library, const LibraryScreen()),
          _page(Routes.store, const StoreScreen()),
          _page(Routes.search, const SearchScreen()),
          _page(Routes.settings, const SettingsScreen()),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}

GoRoute _page(String path, Widget screen) => GoRoute(
  path: path,
  pageBuilder: (BuildContext context, GoRouterState state) =>
      NoTransitionPage<void>(key: state.pageKey, child: screen),
);
