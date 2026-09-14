import '../../core/errors/app_exception.dart';

class DomainModelIssue {
  const DomainModelIssue({
    required this.code,
    required this.path,
    required this.message,
  });

  final String code;
  final String path;
  final String message;
}

class DomainModelException extends AppException {
  DomainModelException({
    required this.source,
    required List<DomainModelIssue> issues,
  }) : issues = List.unmodifiable(issues),
       super(_message(issues));

  final String source;
  final List<DomainModelIssue> issues;

  static String _message(List<DomainModelIssue> issues) {
    if (issues.isEmpty) return 'El contrato de dominio no es válido.';
    final first = issues.first;
    final suffix = issues.length == 1 ? '' : ' (${issues.length} problemas)';
    return 'Contrato de dominio inválido en ${first.path}: ${first.message}$suffix';
  }
}
