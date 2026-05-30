import 'package:equatable/equatable.dart';

/// Base failure class for the LendLoop application.
/// All domain errors are represented as typed Failure subclasses.

abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

/// Network / API errors
class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

/// Firebase Authentication errors
class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

/// Domain restriction error
class DomainRestrictionFailure extends Failure {
  const DomainRestrictionFailure()
      : super('Access restricted to @vit.ac.in and @vitstudent.ac.in email addresses only.');
}

/// Local cache errors
class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

/// Validation errors
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// Not found
class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message);
}

/// Unauthorized
class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure() : super('You are not authorized to perform this action.');
}

/// QR errors
class QRFailure extends Failure {
  const QRFailure(super.message);
}
