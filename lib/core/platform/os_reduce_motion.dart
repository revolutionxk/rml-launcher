import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rml_launcher/core/di/providers.dart';

part 'os_reduce_motion.g.dart';

@Riverpod(keepAlive: true)
class OsReduceMotion extends _$OsReduceMotion {
  @override
  bool? build() {
    final AppLifecycleListener listener = AppLifecycleListener(
      onResume: _refresh,
    );
    ref.onDispose(listener.dispose);
    return _read();
  }

  bool? _read() => ref.read(nativeServiceProvider).osReducesMotion;

  void _refresh() => state = _read();
}
