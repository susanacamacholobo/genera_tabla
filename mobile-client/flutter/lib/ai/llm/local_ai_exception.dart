import '../../core/errors/app_exception.dart';

class LocalAIException extends AppException {
  const LocalAIException(super.userMessage);
}

class LocalModelException extends LocalAIException {
  const LocalModelException(super.userMessage);
}
