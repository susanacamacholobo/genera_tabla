import '../../domain/model/domain_model.dart';
import 'intent_exception.dart';
import 'structured_intent.dart';

class IntentValidationResult {
  IntentValidationResult(List<IntentIssue> issues)
    : issues = List.unmodifiable(issues);

  final List<IntentIssue> issues;

  bool get isValid => issues.isEmpty;
}

class IntentValidator {
  const IntentValidator();

  IntentValidationResult validate(StructuredIntent intent, DomainModel domain) {
    final issues = <IntentIssue>[];
    final entity = domain.entityNamed(intent.entity);
    if (entity == null) {
      issues.add(
        IntentIssue(
          code: 'ENTITY_NOT_FOUND',
          path: r'$.entity',
          message: 'La entidad «${intent.entity}» no existe.',
        ),
      );
      return IntentValidationResult(issues);
    }

    final requiresIdentifier = const {
      IntentOperation.getEntity,
      IntentOperation.updateEntity,
      IntentOperation.deleteEntity,
    }.contains(intent.operation);
    if (requiresIdentifier) {
      if (intent.identifier == null) {
        issues.add(
          const IntentIssue(
            code: 'MISSING_IDENTIFIER',
            path: r'$.identifier',
            message: 'La operación requiere un identificador.',
          ),
        );
      } else {
        final idField = entity.fieldNamed(entity.idField);
        if (idField != null &&
            !_matchesFieldType(intent.identifier, idField.type)) {
          issues.add(
            IntentIssue(
              code: 'INVALID_IDENTIFIER_TYPE',
              path: r'$.identifier',
              message:
                  'Debe tener el tipo ${idField.type.wireName} de ${entity.idField}.',
            ),
          );
        }
      }
    } else if (intent.identifier != null) {
      issues.add(
        const IntentIssue(
          code: 'IDENTIFIER_NOT_ALLOWED',
          path: r'$.identifier',
          message: 'La operación no admite identificador.',
        ),
      );
    }

    final acceptsParameters = const {
      IntentOperation.createEntity,
      IntentOperation.updateEntity,
      IntentOperation.searchEntity,
    }.contains(intent.operation);
    if (!acceptsParameters && intent.parameters.isNotEmpty) {
      issues.add(
        const IntentIssue(
          code: 'PARAMETERS_NOT_ALLOWED',
          path: r'$.parameters',
          message: 'La operación no admite parámetros.',
        ),
      );
      return IntentValidationResult(issues);
    }
    if (intent.operation == IntentOperation.searchEntity &&
        intent.parameters.isEmpty) {
      issues.add(
        const IntentIssue(
          code: 'MISSING_SEARCH_FILTER',
          path: r'$.parameters',
          message: 'La búsqueda requiere al menos un filtro.',
        ),
      );
    }

    final resolvedKeys = <String>{};
    for (final entry in intent.parameters.entries) {
      final field = entity.fieldNamed(entry.key);
      final relationship = entity.relationshipNamed(entry.key);
      final canonicalKey = field?.name ?? relationship?.apiField;
      if (canonicalKey == null) {
        issues.add(
          IntentIssue(
            code: 'UNKNOWN_PARAMETER',
            path: r'$.parameters.' + entry.key,
            message: 'El campo «${entry.key}» no existe en ${entity.name}.',
          ),
        );
        continue;
      }
      if (!resolvedKeys.add(_normalized(canonicalKey))) {
        issues.add(
          IntentIssue(
            code: 'DUPLICATE_PARAMETER',
            path: r'$.parameters.' + entry.key,
            message: 'El campo «$canonicalKey» aparece más de una vez.',
          ),
        );
        continue;
      }

      final writesData =
          intent.operation == IntentOperation.createEntity ||
          intent.operation == IntentOperation.updateEntity;
      if (writesData && field?.generated == true) {
        issues.add(
          IntentIssue(
            code: 'READ_ONLY_FIELD',
            path: r'$.parameters.' + entry.key,
            message:
                'El campo «${field!.name}» es generado y no se puede escribir.',
          ),
        );
        continue;
      }
      if (writesData && relationship != null && !relationship.writable) {
        issues.add(
          IntentIssue(
            code: 'READ_ONLY_RELATIONSHIP',
            path: r'$.parameters.' + entry.key,
            message:
                'La relación «${relationship.name}» no se escribe desde ${entity.name}.',
          ),
        );
        continue;
      }

      if (field != null) {
        if (!_validFieldValue(entry.value, field)) {
          issues.add(
            IntentIssue(
              code: 'INVALID_FIELD_TYPE',
              path: r'$.parameters.' + entry.key,
              message:
                  'El campo «${field.name}» requiere ${field.type.wireName}.',
            ),
          );
        }
      } else if (relationship != null &&
          !_validRelationshipValue(
            entry.value,
            relationship,
            domain,
            searching: intent.operation == IntentOperation.searchEntity,
          )) {
        issues.add(
          IntentIssue(
            code: 'INVALID_RELATIONSHIP_VALUE',
            path: r'$.parameters.' + entry.key,
            message:
                'El valor de «${relationship.apiField}» no contiene IDs válidos.',
          ),
        );
      }
    }

    final requiresCompleteBody =
        intent.operation == IntentOperation.createEntity ||
        intent.operation == IntentOperation.updateEntity;
    if (requiresCompleteBody) {
      for (final field in entity.fields) {
        if (field.required &&
            !field.generated &&
            !resolvedKeys.contains(_normalized(field.name))) {
          issues.add(
            IntentIssue(
              code: 'MISSING_REQUIRED_FIELD',
              path: r'$.parameters.' + field.name,
              message: 'Falta el campo obligatorio «${field.name}».',
            ),
          );
        }
      }
      for (final relationship in entity.relationships) {
        if (relationship.required &&
            relationship.writable &&
            !resolvedKeys.contains(_normalized(relationship.apiField))) {
          issues.add(
            IntentIssue(
              code: 'MISSING_REQUIRED_RELATIONSHIP',
              path: r'$.parameters.' + relationship.apiField,
              message:
                  'Falta la relación obligatoria «${relationship.apiField}».',
            ),
          );
        }
      }
    }

    return IntentValidationResult(issues);
  }

  void assertValid(StructuredIntent intent, DomainModel domain) {
    final result = validate(intent, domain);
    if (!result.isValid) throw IntentValidationException(result.issues);
  }

  bool _validFieldValue(Object? value, DomainField field) {
    if (value == null) return !field.required;
    return _matchesFieldType(value, field.type);
  }

  bool _matchesFieldType(Object? value, DomainFieldType type) {
    return switch (type) {
      DomainFieldType.string => value is String,
      DomainFieldType.integer || DomainFieldType.long => value is int,
      DomainFieldType.doubleType || DomainFieldType.decimal => value is num,
      DomainFieldType.boolean => value is bool,
      DomainFieldType.date => value is String && _isDate(value),
      DomainFieldType.dateTime => value is String && _isDateTime(value),
      DomainFieldType.uuid => value is String && _isUuid(value),
    };
  }

  bool _validRelationshipValue(
    Object? value,
    DomainRelationship relationship,
    DomainModel domain, {
    required bool searching,
  }) {
    if (value == null) return !relationship.required;
    final target = domain.entityNamed(relationship.targetEntity);
    final idField = target?.fieldNamed(target.idField);
    if (idField == null) return false;
    if (relationship.many) {
      if (searching && _matchesFieldType(value, idField.type)) return true;
      return value is List<Object?> &&
          (!relationship.required || value.isNotEmpty) &&
          value.every((item) => _matchesFieldType(item, idField.type));
    }
    return _matchesFieldType(value, idField.type);
  }

  bool _isDate(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) return false;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return false;
    return parsed.year == int.parse(match[1]!) &&
        parsed.month == int.parse(match[2]!) &&
        parsed.day == int.parse(match[3]!);
  }

  bool _isDateTime(String value) =>
      value.contains('T') && DateTime.tryParse(value) != null;

  bool _isUuid(String value) => RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(value);
}

String _normalized(String value) => value.trim().toLowerCase();
