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

    // A small local model can recognize CREATE_ENTITY but omit a plainly
    // stated name. Recover only a single, explicit value for the selected
    // entity; the normal validator still rejects every other missing field.
    if (intent.operation == IntentOperation.createEntity &&
        _mentionsEntity(instruction, entity.name)) {
      for (final field in entity.fields) {
        if (field.name.toLowerCase() != 'nombre' ||
            field.type != DomainFieldType.string ||
            !field.required ||
            field.generated ||
            parameters.keys.any(
              (key) => entity.fieldNamed(key)?.name == field.name,
            )) {
          continue;
        }
        final name = _explicitName(instruction);
        if (name != null) parameters[field.name] = name;
      }
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

  bool _mentionsEntity(String instruction, String entityName) {
    String fold(String value) => value
        .toLowerCase()
        .replaceAll(RegExp('[áàâä]'), 'a')
        .replaceAll(RegExp('[éèêë]'), 'e')
        .replaceAll(RegExp('[íìîï]'), 'i')
        .replaceAll(RegExp('[óòôö]'), 'o')
        .replaceAll(RegExp('[úùûü]'), 'u');

    final entity = RegExp.escape(fold(entityName));
    return RegExp(
      '(^|[^a-z0-9])$entity([^a-z0-9]|\$)',
    ).hasMatch(fold(instruction));
  }

  String? _explicitName(String instruction) {
    final match = RegExp(
      r'\b(?:llamad[oa]|nombre\s*[:=]?)\s+(.+?)\s*$',
      caseSensitive: false,
    ).firstMatch(instruction);
    if (match == null) return null;
    final value = match
        .group(1)!
        .trim()
        .replaceAll(RegExp(r'[.!?]+$'), '')
        .replaceAll(RegExp(r'^["“”\x27]+|["“”\x27]+$'), '')
        .trim();
    if (value.isEmpty ||
        value.contains(RegExp(r'[,;:]')) ||
        RegExp(
          r'\b(?:y|con|para|sin)\b',
          caseSensitive: false,
        ).hasMatch(value)) {
      return null;
    }
    return value;
  }
}
