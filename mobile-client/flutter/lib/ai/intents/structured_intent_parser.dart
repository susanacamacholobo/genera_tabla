import 'dart:convert';

import 'intent_exception.dart';
import 'structured_intent.dart';

class StructuredIntentParser {
  const StructuredIntentParser();

  StructuredIntent parse(String response) {
    late Object? decoded;
    try {
      decoded = jsonDecode(response);
    } on FormatException {
      throw const IntentFormatException(
        'La IA local devolvió una intención que no es JSON válido.',
      );
    }
    if (decoded is! Map<String, Object?>) {
      throw const IntentFormatException(
        'La intención debe ser un objeto JSON.',
      );
    }

    const allowedKeys = {'operation', 'entity', 'identifier', 'parameters'};
    if (decoded.keys.any((key) => !allowedKeys.contains(key))) {
      throw const IntentFormatException(
        'La intención contiene propiedades no permitidas.',
      );
    }

    final rawOperation = decoded['operation'];
    final rawEntity = decoded['entity'];
    if (rawOperation is! String || rawEntity is! String) {
      throw const IntentFormatException(
        'La intención requiere operation y entity como texto.',
      );
    }
    final operation = IntentOperation.tryParse(rawOperation);
    if (operation == null) {
      throw IntentFormatException(
        'La operación «$rawOperation» no está permitida.',
      );
    }
    final entity = rawEntity.trim();
    if (entity.isEmpty) {
      throw const IntentFormatException('La entidad no puede estar vacía.');
    }

    final identifier = decoded['identifier'];
    if (identifier != null && identifier is! String && identifier is! num) {
      throw const IntentFormatException('identifier debe ser texto o número.');
    }

    final rawParameters = decoded['parameters'];
    final Map<String, Object?> parameters;
    if (rawParameters == null) {
      parameters = const {};
    } else if (rawParameters is Map<String, Object?>) {
      parameters = rawParameters;
    } else {
      throw const IntentFormatException('parameters debe ser un objeto JSON.');
    }
    for (final entry in parameters.entries) {
      if (entry.key.trim().isEmpty || !_isParameterValue(entry.value)) {
        throw IntentFormatException(
          'El parámetro «${entry.key}» tiene una forma no permitida.',
        );
      }
    }

    return StructuredIntent(
      operation: operation,
      entity: entity,
      identifier: identifier,
      parameters: parameters,
    );
  }

  bool _isParameterValue(Object? value) {
    if (value == null || value is String || value is num || value is bool) {
      return true;
    }
    return value is List<Object?> && value.every(_isScalar);
  }

  bool _isScalar(Object? value) =>
      value == null || value is String || value is num || value is bool;
}
