import '../../domain/model/domain_model.dart';
import 'structured_intent.dart';

/// Repairs only unambiguous small-model serialization mistakes. Validation
/// still checks the resulting intent before any local or remote write.
class IntentNormalizer {
  const IntentNormalizer();

  StructuredIntent normalize(
    StructuredIntent intent,
    DomainModel domain, {
    required String instruction,
  }) {
    final entity = domain.entityNamed(intent.entity);
    if (entity == null) return intent;
    final writesData =
        intent.operation == IntentOperation.createEntity ||
        intent.operation == IntentOperation.updateEntity;
    final normalizedInstruction = instruction.toLowerCase();
    final parameters = <String, Object?>{};

    for (final entry in intent.parameters.entries) {
      final field = entity.fieldNamed(entry.key);
      if (field == null) {
        parameters[entry.key] = entry.value;
        continue;
      }

      final raw = entry.value;
      final value = raw is String
          ? _numericValue(raw.trim(), field.type)
          : raw is num && _isNumericField(field.type)
          ? raw
          : null;
      final isUnrequestedDefaultZero =
          writesData &&
          !field.required &&
          value == 0 &&
          !normalizedInstruction.contains(field.name.toLowerCase());
      if (isUnrequestedDefaultZero) continue;

      parameters[entry.key] = value ?? raw;
    }

    return StructuredIntent(
      operation: intent.operation,
      entity: intent.entity,
      identifier: intent.identifier,
      parameters: parameters,
    );
  }

  num? _numericValue(String raw, DomainFieldType type) {
    if (!RegExp(r'^-?(?:0|[1-9]\d*)(?:\.\d+)?$').hasMatch(raw)) {
      return null;
    }
    return switch (type) {
      DomainFieldType.integer ||
      DomainFieldType.long => raw.contains('.') ? null : int.tryParse(raw),
      DomainFieldType.decimal ||
      DomainFieldType.doubleType => num.tryParse(raw),
      _ => null,
    };
  }

  bool _isNumericField(DomainFieldType type) =>
      type == DomainFieldType.integer ||
      type == DomainFieldType.long ||
      type == DomainFieldType.decimal ||
      type == DomainFieldType.doubleType;
}
