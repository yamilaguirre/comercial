class ServerException implements Exception {
  final String message;
  const ServerException([this.message = 'Server Exception']);
}

class CacheException implements Exception {
  final String message;
  const CacheException([this.message = 'Cache Exception']);
}

class NetworkException implements Exception {
  final String message;
  const NetworkException([this.message = 'Network Exception']);
}

class ValidationException implements Exception {
  final String message;
  const ValidationException([this.message = 'Validation Exception']);
}

class AuthenticationException implements Exception {
  final String message;
  const AuthenticationException([this.message = 'Authentication Exception']);
}

class AuthorizationException implements Exception {
  final String message;
  const AuthorizationException([this.message = 'Authorization Exception']);
}
