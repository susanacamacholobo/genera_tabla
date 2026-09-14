import '../core/errors/app_exception.dart';

class SpeechUnavailableException extends AppException {
  const SpeechUnavailableException(super.userMessage);
}

class SpeechPermissionException extends AppException {
  const SpeechPermissionException(super.userMessage);
}

class SpeechRecognitionException extends AppException {
  const SpeechRecognitionException(super.userMessage);
}
