sealed class AppFailure implements Exception {
  const AppFailure({this.cause, this.stackTrace});

  final Object? cause;
  final StackTrace? stackTrace;
}

final class IoFailure extends AppFailure {
  const IoFailure({required this.path, super.cause, super.stackTrace});

  final String path;
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure({
    this.isTimeout = false,
    this.statusCode,
    super.cause,
    super.stackTrace,
  });

  final bool isTimeout;
  final int? statusCode;
}

final class IntegrityFailure extends AppFailure {
  const IntegrityFailure({
    required this.expected,
    required this.actual,
    super.cause,
    super.stackTrace,
  });

  final String expected;
  final String actual;
}

final class NativeFailure extends AppFailure {
  const NativeFailure({
    required this.code,
    required this.message,
    super.cause,
    super.stackTrace,
  });

  final int code;
  final String message;
}

final class ValidationFailure extends AppFailure {
  const ValidationFailure({
    required this.message,
    super.cause,
    super.stackTrace,
  });

  final String message;
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure({required this.what, super.cause, super.stackTrace});

  final String what;
}

final class CancelledFailure extends AppFailure {
  const CancelledFailure({super.cause, super.stackTrace});
}

final class UnknownFailure extends AppFailure {
  const UnknownFailure({super.cause, super.stackTrace});
}

final class InsufficientSpaceFailure extends AppFailure {
  const InsufficientSpaceFailure({
    required this.neededBytes,
    required this.freeBytes,
    required this.volume,
    super.cause,
    super.stackTrace,
  });

  final int neededBytes;
  final int freeBytes;
  final String volume;
}

final class StudioRunningFailure extends AppFailure {
  const StudioRunningFailure({
    required this.installId,
    super.cause,
    super.stackTrace,
  });

  final String installId;
}

final class TaskBusyFailure extends AppFailure {
  const TaskBusyFailure({
    required this.installId,
    super.cause,
    super.stackTrace,
  });

  final String installId;
}

final class UpdateBlockedFailure extends AppFailure {
  const UpdateBlockedFailure({
    required this.blockers,
    super.cause,
    super.stackTrace,
  });

  final List<String> blockers;
}

final class UnsupportedFailure extends AppFailure {
  const UnsupportedFailure({
    required this.reason,
    super.cause,
    super.stackTrace,
  });

  final String reason;
}

extension AppFailureCode on AppFailure {
  String get code => switch (this) {
    IoFailure() => 'io',
    NetworkFailure() => 'network',
    IntegrityFailure() => 'integrity',
    NativeFailure() => 'native',
    ValidationFailure() => 'validation',
    NotFoundFailure() => 'notFound',
    CancelledFailure() => 'cancelled',
    InsufficientSpaceFailure() => 'insufficientSpace',
    StudioRunningFailure() => 'studioRunning',
    TaskBusyFailure() => 'taskBusy',
    UpdateBlockedFailure() => 'updateBlocked',
    UnsupportedFailure() => 'unsupported',
    UnknownFailure() => 'unknown',
  };
}
