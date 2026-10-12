import 'package:flutter_test/flutter_test.dart';
import 'package:rml_launcher/features/studio/data/download/transfer_meter.dart';

void main() {
  test('speed and time left follow the bytes over time', () {
    DateTime now = DateTime.utc(2026, 10, 12);
    final TransferMeter meter = TransferMeter(
      total: 10 << 20,
      clock: () => now,
    );
    expect(meter.eta, isNull);
    now = now.add(const Duration(seconds: 1));
    meter.add(1 << 20);
    expect(meter.speed, closeTo(1 << 20, 1));
    now = now.add(const Duration(seconds: 1));
    meter.add(1 << 20);
    expect(meter.done, 2 << 20);
    expect(meter.speed, closeTo(1 << 20, 1));
    expect(meter.eta, const Duration(seconds: 8));
  });

  test('samples closer than 200 ms are folded into the next one', () {
    DateTime now = DateTime.utc(2026, 10, 12);
    final TransferMeter meter = TransferMeter(total: 100, clock: () => now);
    now = now.add(const Duration(milliseconds: 50));
    meter.add(10);
    expect(meter.speed, 0);
    now = now.add(const Duration(milliseconds: 950));
    meter.add(10);
    expect(meter.speed, closeTo(20, 0.001));
  });

  test('a restart takes bytes back without touching the speed', () {
    DateTime now = DateTime.utc(2026, 10, 12);
    final TransferMeter meter = TransferMeter(total: 100, clock: () => now);
    now = now.add(const Duration(seconds: 1));
    meter.add(40);
    meter.add(-40);
    expect(meter.done, 0);
    expect(meter.speed, closeTo(40, 0.001));
  });
}
