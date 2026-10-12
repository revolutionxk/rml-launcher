import 'package:window_manager/window_manager.dart';

abstract interface class WindowChrome {
  Future<void> startDragging();

  Future<void> minimize();

  Future<void> toggleMaximize();

  Future<void> close();
}

final class WindowManagerChrome implements WindowChrome {
  const WindowManagerChrome();

  @override
  Future<void> startDragging() => windowManager.startDragging();

  @override
  Future<void> minimize() => windowManager.minimize();

  @override
  Future<void> toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  @override
  Future<void> close() => windowManager.close();
}
