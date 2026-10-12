import 'package:flutter_test/flutter_test.dart';
import 'package:rml_launcher/core/result/app_failure.dart';

void main() {
  test('every failure has a distinct code', () {
    const List<AppFailure> failures = <AppFailure>[
      IoFailure(path: '/a'),
      NetworkFailure(statusCode: 503),
      IntegrityFailure(expected: 'a', actual: 'b'),
      NativeFailure(code: 2, message: 'io'),
      ValidationFailure(message: 'bad'),
      NotFoundFailure(what: 'Studio'),
      CancelledFailure(),
      InsufficientSpaceFailure(neededBytes: 2, freeBytes: 1, volume: 'C:'),
      StudioRunningFailure(installId: 'main'),
      TaskBusyFailure(installId: 'main'),
      UpdateBlockedFailure(blockers: <String>['Tracy']),
      UnsupportedFailure(reason: 'Linux'),
      UnknownFailure(),
    ];
    final Set<String> codes = failures
        .map((AppFailure failure) => failure.code)
        .toSet();
    expect(codes, hasLength(failures.length));
    expect(const NetworkFailure(statusCode: 404).code, 'network');
  });
}
