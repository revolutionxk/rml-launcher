import 'package:flutter_test/flutter_test.dart';
import 'package:rml_launcher/core/state/value_hub.dart';

void main() {
  test('watch starts with the current value and follows changes', () async {
    final ValueHub<int> hub = ValueHub<int>(1);
    addTearDown(hub.close);
    final List<int> seen = <int>[];
    final Stream<int> stream = hub.watch();
    final Future<void> done = stream.take(3).forEach(seen.add);
    await Future<void>.delayed(Duration.zero);
    hub
      ..value = 2
      ..value = 3;
    await done;
    expect(seen, <int>[1, 2, 3]);
  });

  test('changes only carry new values', () async {
    final ValueHub<String> hub = ValueHub<String>('a');
    addTearDown(hub.close);
    final Future<String> next = hub.changes.first;
    hub.value = 'b';
    expect(await next, 'b');
    expect(hub.value, 'b');
  });
}
