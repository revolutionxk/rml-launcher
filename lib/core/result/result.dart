import 'package:rml_launcher/core/result/app_failure.dart';

sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>;

  const factory Result.err(AppFailure failure) = Err<T>;

  bool get isOk => this is Ok<T>;

  bool get isErr => this is Err<T>;

  T? get valueOrNull => switch (this) {
    Ok<T>(:final T value) => value,
    Err<T>() => null,
  };

  AppFailure? get failureOrNull => switch (this) {
    Ok<T>() => null,
    Err<T>(:final AppFailure failure) => failure,
  };

  R fold<R>({
    required R Function(T value) onOk,
    required R Function(AppFailure failure) onErr,
  }) => switch (this) {
    Ok<T>(:final T value) => onOk(value),
    Err<T>(:final AppFailure failure) => onErr(failure),
  };

  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Ok<T>(:final T value) => Ok<R>(transform(value)),
    Err<T>(:final AppFailure failure) => Err<R>(failure),
  };

  Future<Result<R>> flatMap<R>(
    Future<Result<R>> Function(T value) transform,
  ) async => switch (this) {
    Ok<T>(:final T value) => await transform(value),
    Err<T>(:final AppFailure failure) => Err<R>(failure),
  };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;

  @override
  String toString() => 'Ok($value)';
}

final class Err<T> extends Result<T> {
  const Err(this.failure);

  final AppFailure failure;

  @override
  String toString() => 'Err($failure)';
}

extension ResultUnwrap<T> on Result<T> {
  T unwrap() => switch (this) {
    Ok<T>(:final T value) => value,
    Err<T>(:final AppFailure failure) => throw failure,
  };
}
