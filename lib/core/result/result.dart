import '../errors/failure.dart';

sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is FailureResult<T>;

  T? get data => switch (this) {
        Success<T>(value: final v) => v,
        _ => null,
      };

  Failure? get error => switch (this) {
        FailureResult<T>(failure: final f) => f,
        _ => null,
      };
}

class Success<T> extends Result<T> {
  const Success({required this.value});

  final T value;
}

class FailureResult<T> extends Result<T> {
  const FailureResult({required this.failure});

  final Failure failure;
}

