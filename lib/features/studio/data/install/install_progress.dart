import 'package:rml_launcher/core/tasks/studio_task.dart';
import 'package:rml_launcher/core/tasks/task_center.dart';
import 'package:rml_launcher/features/studio/data/download/transfer_meter.dart';

final class InstallProgress {
  InstallProgress(
    this._control, {
    required this.packed,
    this.unpacked = 0,
    DateTime Function()? clock,
  }) : _meter = TransferMeter(total: packed, clock: clock);

  final TaskControl _control;
  final int packed;
  final int unpacked;
  final TransferMeter _meter;
  final Map<String, int> _extracted = <String, int>{};
  final Map<String, int> _extractTotals = <String, int>{};
  bool _extracting = false;

  void downloaded(int delta) {
    _meter.add(delta);
    _report();
  }

  void extracted(String package, int done, int total) {
    _extracted[package] = done;
    _extractTotals[package] = total;
    _report();
  }

  void finish() => _control.report(
    TaskProgress(fraction: 1, bytesDone: packed, bytesTotal: packed),
  );

  void _report() {
    if (!_extracting && packed > 0 && _meter.done >= packed) {
      _extracting = true;
      _control.phase(TaskPhase.extracting);
    }
    final int extractedBytes = _extracted.values.fold(
      0,
      (int sum, int bytes) => sum + bytes,
    );
    final int extractTotal = unpacked > 0
        ? unpacked
        : _extractTotals.values.fold(0, (int sum, int bytes) => sum + bytes);
    final double download = packed == 0 ? 1 : _meter.done / packed;
    final double extract = extractTotal == 0
        ? 0
        : extractedBytes / extractTotal;
    final double fraction = 0.8 * download + 0.2 * extract;
    _control.report(
      TaskProgress(
        fraction: fraction < 0.99 ? fraction : 0.99,
        bytesDone: _meter.done,
        bytesTotal: packed,
        speed: _meter.speed,
        eta: _meter.eta,
      ),
    );
  }
}
