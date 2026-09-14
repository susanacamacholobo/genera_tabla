import 'dart:convert';

import 'package:flutter/services.dart';

import '../model/domain_model.dart';
import 'domain_model_exception.dart';

class DomainModelLoader {
  const DomainModelLoader();

  Future<DomainModel> loadFromAsset(
    String assetPath, {
    AssetBundle? bundle,
  }) async {
    final sourceBundle = bundle ?? rootBundle;
    late String content;
    try {
      content = await sourceBundle.loadString(assetPath);
    } catch (_) {
      throw DomainModelException(
        source: assetPath,
        issues: const [
          DomainModelIssue(
            code: 'ASSET_READ_ERROR',
            path: r'$',
            message: 'No se pudo leer el archivo.',
          ),
        ],
      );
    }
    return loadFromString(content, source: assetPath);
  }

  DomainModel loadFromString(
    String content, {
    String source = 'domain-model.json',
  }) {
    late Object? decoded;
    try {
      decoded = jsonDecode(content);
    } on FormatException {
      throw DomainModelException(
        source: source,
        issues: const [
          DomainModelIssue(
            code: 'MALFORMED_JSON',
            path: r'$',
            message: 'El archivo no contiene JSON válido.',
          ),
        ],
      );
    }
    return loadFromJson(decoded, source: source);
  }

  DomainModel loadFromJson(
    Object? value, {
    String source = 'domain-model.json',
  }) {
    final reader = _ContractReader();
    final root = reader.object(value, r'$');
    final schemaVersion = reader.string(
      root,
      'schemaVersion',
      r'$.schemaVersion',
    );
    final application = reader.string(root, 'application', r'$.application');
    final artifactId = reader.string(root, 'artifactId', r'$.artifactId');
    final basePath = reader.string(root, 'basePath', r'$.basePath');
    final entityValues = reader.list(root, 'entities', r'$.entities');
    final entities = <DomainEntity>[];

    for (var index = 0; index < entityValues.length; index++) {
      entities.add(
        _readEntity(reader, entityValues[index], r'$.entities[$index]'),
      );
    }

    final model = DomainModel(
      schemaVersion: schemaVersion,
      application: application,
      artifactId: artifactId,
      basePath: basePath,
      entities: entities,
    );
    _validateSemantics(model, reader.issues);

    if (reader.issues.isNotEmpty) {
      throw DomainModelException(source: source, issues: reader.issues);
    }
    return model;
  }

  DomainEntity _readEntity(_ContractReader reader, Object? value, String path) {
    final object = reader.object(value, path);
    final fields = <DomainField>[];
    final fieldValues = reader.list(object, 'fields', '$path.fields');
    for (var index = 0; index < fieldValues.length; index++) {
      fields.add(
        _readField(reader, fieldValues[index], '$path.fields[$index]'),
      );
    }

    final relationships = <DomainRelationship>[];
    final relationshipValues = reader.list(
      object,
      'relationships',
      '$path.relationships',
    );
    for (var index = 0; index < relationshipValues.length; index++) {
      relationships.add(
        _readRelationship(
          reader,
          relationshipValues[index],
          '$path.relationships[$index]',
        ),
      );
    }

    return DomainEntity(
      name: reader.string(object, 'name', '$path.name'),
      endpoint: reader.string(object, 'endpoint', '$path.endpoint'),
      idField: reader.string(object, 'idField', '$path.idField'),
      fields: fields,
      relationships: relationships,
    );
  }

  DomainField _readField(_ContractReader reader, Object? value, String path) {
    final object = reader.object(value, path);
    final rawType = reader.string(object, 'type', '$path.type');
    final type = DomainFieldType.tryParse(rawType);
    if (type == null && rawType.isNotEmpty) {
      reader.issue(
        'UNSUPPORTED_FIELD_TYPE',
        '$path.type',
        'El tipo «$rawType» no está soportado.',
      );
    }
    return DomainField(
      name: reader.string(object, 'name', '$path.name'),
      type: type ?? DomainFieldType.string,
      required: reader.boolean(object, 'required', '$path.required'),
      generated: reader.boolean(object, 'generated', '$path.generated'),
      unique: reader.boolean(object, 'unique', '$path.unique'),
    );
  }

  DomainRelationship _readRelationship(
    _ContractReader reader,
    Object? value,
    String path,
  ) {
    final object = reader.object(value, path);
    final rawKind = reader.string(object, 'kind', '$path.kind');
    final kind = DomainRelationshipKind.tryParse(rawKind);
    if (kind == null && rawKind.isNotEmpty) {
      reader.issue(
        'UNSUPPORTED_RELATIONSHIP_KIND',
        '$path.kind',
        'La relación «$rawKind» no está soportada.',
      );
    }
    return DomainRelationship(
      name: reader.string(object, 'name', '$path.name'),
      apiField: reader.string(object, 'apiField', '$path.apiField'),
      targetEntity: reader.string(object, 'targetEntity', '$path.targetEntity'),
      kind: kind ?? DomainRelationshipKind.oneToOne,
      many: reader.boolean(object, 'many', '$path.many'),
      required: reader.boolean(object, 'required', '$path.required'),
      writable: reader.boolean(object, 'writable', '$path.writable'),
    );
  }

  void _validateSemantics(DomainModel model, List<DomainModelIssue> issues) {
    if (model.schemaVersion != DomainModel.supportedSchemaVersion) {
      issues.add(
        DomainModelIssue(
          code: 'UNSUPPORTED_SCHEMA_VERSION',
          path: r'$.schemaVersion',
          message:
              'Se esperaba ${DomainModel.supportedSchemaVersion} y se recibió «${model.schemaVersion}».',
        ),
      );
    }
    _requiredText(model.application, r'$.application', issues);
    _requiredText(model.artifactId, r'$.artifactId', issues);
    if (!_validPath(model.basePath)) {
      issues.add(
        const DomainModelIssue(
          code: 'INVALID_BASE_PATH',
          path: r'$.basePath',
          message: 'Debe ser una ruta absoluta sin query ni fragmento.',
        ),
      );
    }
    if (model.entities.isEmpty) {
      issues.add(
        const DomainModelIssue(
          code: 'EMPTY_ENTITIES',
          path: r'$.entities',
          message: 'Debe contener al menos una entidad.',
        ),
      );
    }

    _duplicates(
      model.entities.map((entity) => entity.name),
      r'$.entities',
      'DUPLICATE_ENTITY_NAME',
      issues,
    );
    _duplicates(
      model.entities.map((entity) => entity.endpoint),
      r'$.entities',
      'DUPLICATE_ENTITY_ENDPOINT',
      issues,
    );

    final entityNames = {
      for (final entity in model.entities) _normalized(entity.name),
    };
    for (var index = 0; index < model.entities.length; index++) {
      final entity = model.entities[index];
      final path = '\$.entities[$index]';
      _requiredText(entity.name, '$path.name', issues);
      _requiredText(entity.idField, '$path.idField', issues);
      if (!_validPath(entity.endpoint) ||
          !_endpointInsideBasePath(entity.endpoint, model.basePath)) {
        issues.add(
          DomainModelIssue(
            code: 'INVALID_ENDPOINT',
            path: '$path.endpoint',
            message: 'Debe ser una ruta dentro de ${model.basePath}.',
          ),
        );
      }
      if (entity.fields.isEmpty) {
        issues.add(
          DomainModelIssue(
            code: 'EMPTY_FIELDS',
            path: '$path.fields',
            message: 'La entidad debe contener campos.',
          ),
        );
      }
      _duplicates(
        entity.fields.map((field) => field.name),
        '$path.fields',
        'DUPLICATE_FIELD_NAME',
        issues,
      );
      _duplicates(
        entity.relationships.map((relationship) => relationship.apiField),
        '$path.relationships',
        'DUPLICATE_RELATIONSHIP_API_FIELD',
        issues,
      );

      final idField = entity.fieldNamed(entity.idField);
      if (idField == null) {
        issues.add(
          DomainModelIssue(
            code: 'ID_FIELD_NOT_FOUND',
            path: '$path.idField',
            message: 'No referencia un campo de la entidad.',
          ),
        );
      } else if (!idField.generated || !idField.required || !idField.unique) {
        issues.add(
          DomainModelIssue(
            code: 'INVALID_ID_FIELD',
            path: '$path.idField',
            message: 'El campo ID debe ser requerido, generado y único.',
          ),
        );
      }

      for (
        var fieldIndex = 0;
        fieldIndex < entity.fields.length;
        fieldIndex++
      ) {
        _requiredText(
          entity.fields[fieldIndex].name,
          '$path.fields[$fieldIndex].name',
          issues,
        );
      }
      for (
        var relationshipIndex = 0;
        relationshipIndex < entity.relationships.length;
        relationshipIndex++
      ) {
        final relationship = entity.relationships[relationshipIndex];
        final relationshipPath = '$path.relationships[$relationshipIndex]';
        _requiredText(relationship.name, '$relationshipPath.name', issues);
        _requiredText(
          relationship.apiField,
          '$relationshipPath.apiField',
          issues,
        );
        if (!entityNames.contains(_normalized(relationship.targetEntity))) {
          issues.add(
            DomainModelIssue(
              code: 'TARGET_ENTITY_NOT_FOUND',
              path: '$relationshipPath.targetEntity',
              message: 'La entidad destino no existe.',
            ),
          );
        }
        if (relationship.many != relationship.kind.many) {
          issues.add(
            DomainModelIssue(
              code: 'INCONSISTENT_CARDINALITY',
              path: '$relationshipPath.many',
              message: 'No coincide con ${relationship.kind.wireName}.',
            ),
          );
        }
      }
    }
  }

  void _requiredText(String value, String path, List<DomainModelIssue> issues) {
    if (value.trim().isEmpty) {
      issues.add(
        DomainModelIssue(
          code: 'EMPTY_VALUE',
          path: path,
          message: 'No puede estar vacío.',
        ),
      );
    }
  }

  void _duplicates(
    Iterable<String> values,
    String path,
    String code,
    List<DomainModelIssue> issues,
  ) {
    final seen = <String>{};
    for (final value in values) {
      final key = _normalized(value);
      if (key.isNotEmpty && !seen.add(key)) {
        issues.add(
          DomainModelIssue(
            code: code,
            path: path,
            message: 'El valor «$value» está duplicado.',
          ),
        );
      }
    }
  }

  bool _validPath(String value) {
    if (!value.startsWith('/') ||
        value.contains('\\') ||
        value.contains('//')) {
      return false;
    }
    final rawSegments = value.split('/');
    if (rawSegments.any((segment) => segment == '.' || segment == '..')) {
      return false;
    }
    final uri = Uri.tryParse(value);
    return uri != null &&
        !uri.hasScheme &&
        !uri.hasAuthority &&
        !uri.hasQuery &&
        !uri.hasFragment;
  }

  bool _endpointInsideBasePath(String endpoint, String basePath) {
    if (basePath == '/') return endpoint.startsWith('/');
    final normalizedBase = basePath.replaceFirst(RegExp(r'/$'), '');
    return endpoint == normalizedBase ||
        endpoint.startsWith('$normalizedBase/');
  }
}

class _ContractReader {
  final issues = <DomainModelIssue>[];

  Map<String, Object?> object(Object? value, String path) {
    if (value is Map<String, Object?>) return value;
    issue('EXPECTED_OBJECT', path, 'Se esperaba un objeto JSON.');
    return const {};
  }

  List<Object?> list(Map<String, Object?> object, String key, String path) {
    final value = object[key];
    if (value is List<Object?>) return value;
    issue('EXPECTED_ARRAY', path, 'Se esperaba una lista JSON.');
    return const [];
  }

  String string(Map<String, Object?> object, String key, String path) {
    final value = object[key];
    if (value is String) return value.trim();
    issue('EXPECTED_STRING', path, 'Se esperaba texto.');
    return '';
  }

  bool boolean(Map<String, Object?> object, String key, String path) {
    final value = object[key];
    if (value is bool) return value;
    issue('EXPECTED_BOOLEAN', path, 'Se esperaba true o false.');
    return false;
  }

  void issue(String code, String path, String message) {
    issues.add(DomainModelIssue(code: code, path: path, message: message));
  }
}

String _normalized(String value) => value.trim().toLowerCase();
