import 'package:flutter_test/flutter_test.dart';
import 'package:rml_launcher/core/async/abort_signal.dart';

void main() {
  test('aborting completes whenAborted once', () async {
    final AbortSignal signal = AbortSignal();
    expect(signal.isAborted, isFalse);
    signal
      ..abort()
      ..abort();
    await signal.whenAborted;
    expect(signal.isAborted, isTrue);
  });

  test('a linked signal follows its parent but not the other way', () async {
    final AbortSignal parent = AbortSignal();
    final AbortSignal child = AbortSignal.linkedTo(parent);
    final AbortSignal sibling = AbortSignal.linkedTo(parent);
    child.abort();
    expect(parent.isAborted, isFalse);
    parent.abort();
    await sibling.whenAborted;
    expect(sibling.isAborted, isTrue);
    expect(AbortSignal.linkedTo(parent).isAborted, isTrue);
  });
}
