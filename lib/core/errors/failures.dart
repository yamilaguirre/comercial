import 'package:equatable/equatable.dart';

/// Clase base para todas las fallas del sistema
abstract class Failure extends Equatable {
  const Failure([List properties = const <dynamic>[]]);

  @override
  List<Object> get props => [];
}

/// Fallas de servidor (500, 502, etc)
class ServerFailure extends Failure {
  final String message;

  const ServerFailure([this.message = 'Server Error']);

  @override
  List<Object> get props => [message];
}

/// Fallas de caché (datos locales)
class CacheFailure extends Failure {
  final String message;

  const CacheFailure([this.message = 'Cache Error']);

  @override
  List<Object> get props => [message];
}

/// Fallas de conexión a internet
class NetworkFailure extends Failure {
  final String message;

  const NetworkFailure([this.message = 'Network Error']);

  @override
  List<Object> get props => [message];
}

/// Fallas de validación de datos
class ValidationFailure extends Failure {
  final String message;

  const ValidationFailure([this.message = 'Validation Error']);

  @override
  List<Object> get props => [message];
}

/// Fallas de autenticación
class AuthenticationFailure extends Failure {
  final String message;

  const AuthenticationFailure([this.message = 'Authentication Error']);

  @override
  List<Object> get props => [message];
}

/// Fallas de autorización
class AuthorizationFailure extends Failure {
  final String message;

  const AuthorizationFailure([this.message = 'Authorization Error']);

  @override
  List<Object> get props => [message];
}
