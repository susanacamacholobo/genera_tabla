class AppException implements Exception {
  const AppException(this.userMessage);

  final String userMessage;

  @override
  String toString() => userMessage;
}

class ConfigurationException extends AppException {
  const ConfigurationException(super.userMessage);
}

class NetworkException extends AppException {
  const NetworkException(super.userMessage);
}

class ResponseDecodingException extends AppException {
  const ResponseDecodingException(super.userMessage);
}

class ApiException extends AppException {
  const ApiException({required this.statusCode, required String userMessage})
    : super(userMessage);

  final int statusCode;
}

String userMessageFor(Object error) {
  if (error is AppException) return error.userMessage;
  return 'Ocurrió un error inesperado. Inténtalo nuevamente.';
}
