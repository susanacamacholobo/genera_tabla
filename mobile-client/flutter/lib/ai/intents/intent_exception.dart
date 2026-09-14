import '../../core/errors/app_exception.dart';

class IntentIssue {
  const IntentIssue({
    required this.code,
    required this.path,
    required this.message,
  });

  final String code;
  final String path;
  final String message;
}

class IntentFormatException extends AppException {
  const IntentFormatException(super.userMessage);
}

class IntentValidationException extends AppException {
  IntentValidationException(List<IntentIssue> issues)
    : issues = List.unmodifiable(issues),
      super(_message(issues));

  final List<IntentIssue> issues;

  static String _message(List<IntentIssue> issues) {
    if (issues.isEmpty) return 'La intención no es válida.';
    final first = issues.first;
    final suffix = issues.length == 1 ? '' : ' (${issues.length} problemas)';
    return 'Intención inválida en ${first.path}: ${first.message}$suffix';
  }
}

class LocalAIException extends AppException {
  const LocalAIException(super.userMessage);
}
