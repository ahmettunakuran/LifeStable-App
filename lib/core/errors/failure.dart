class Failure {
  Failure(this.message, {this.cause, this.stackTrace});

  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => 'Failure(message: $message, cause: $cause)';
}

class NetworkFailure extends Failure {
  NetworkFailure(super.message, {super.cause, super.stackTrace});
}

class UnauthorizedFailure extends Failure {
  UnauthorizedFailure(super.message, {super.cause, super.stackTrace});
}

class UnexpectedFailure extends Failure {
  UnexpectedFailure(super.message, {super.cause, super.stackTrace});
}

