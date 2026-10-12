import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rml_launcher/core/di/providers.dart';
import 'package:rml_launcher/core/platform/window_chrome.dart';

class DragArea extends ConsumerWidget {
  const DragArea({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final WindowChrome chrome = ref.watch(windowChromeProvider);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (DragStartDetails details) => chrome.startDragging(),
      onDoubleTap: chrome.toggleMaximize,
      child: child,
    );
  }
}
