import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:software1_mobile/domain/loading/domain_model_exception.dart';
import 'package:software1_mobile/domain/loading/domain_model_loader.dart';
import 'package:software1_mobile/domain/model/domain_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const loader = DomainModelLoader();

  test('loads the bundled generator contract', () async {
    final model = await loader.loadFromAsset('assets/domain-model.json');

    expect(model.schemaVersion, DomainModel.supportedSchemaVersion);
    expect(model.application, 'Veterinaria');
    expect(model.entityNamed('cliente')?.endpoint, '/api/clientes');
    expect(
      model.entityNamed('CLIENTE')?.fieldNamed('saldo')?.type,
      DomainFieldType.decimal,
    );
  });

  test('parses fields, relationships and case-insensitive lookups', () {
    final model = loader.loadFromString(jsonEncode(_validContract()));

    final mascota = model.entityNamed('mascota');
    expect(mascota, isNotNull);
    expect(mascota?.fieldNamed('NOMBRE')?.required, isTrue);
    final owner = mascota?.relationshipNamed('clienteId');
    expect(owner?.targetEntity, 'Cliente');
    expect(owner?.kind, DomainRelationshipKind.manyToOne);
    expect(owner?.writable, isTrue);
  });

  test('returns immutable entity collections', () {
    final model = loader.loadFromJson(_validContract());

    expect(
      () => model.entities.add(model.entities.first),
      throwsUnsupportedError,
    );
    expect(() => model.entities.first.fields.clear(), throwsUnsupportedError);
  });

  test('reports malformed JSON without exposing parser details', () {
    expect(
      () => loader.loadFromString('{invalid', source: 'broken.json'),
      throwsA(
        isA<DomainModelException>()
            .having((error) => error.source, 'source', 'broken.json')
            .having(
              (error) => error.issues.single.code,
              'code',
              'MALFORMED_JSON',
            ),
      ),
    );
  });

  test('rejects unsupported schema and field types', () {
    final contract = _mutableContract();
    contract['schemaVersion'] = '2.0.0';
    final entities = contract['entities'] as List<dynamic>;
    final cliente = entities.first as Map<String, dynamic>;
    final fields = cliente['fields'] as List<dynamic>;
    (fields[1] as Map<String, dynamic>)['type'] = 'Money';

    final exception = _capture(() => loader.loadFromJson(contract));

    expect(
      exception.issues.map((issue) => issue.code),
      containsAll(['UNSUPPORTED_SCHEMA_VERSION', 'UNSUPPORTED_FIELD_TYPE']),
    );
  });

  test('rejects endpoint traversal outside the declared API path', () {
    final contract = _mutableContract();
    final entities = contract['entities'] as List<dynamic>;
    (entities.first as Map<String, dynamic>)['endpoint'] = '/api/../admin';

    final exception = _capture(() => loader.loadFromJson(contract));

    expect(
      exception.issues.map((issue) => issue.code),
      contains('INVALID_ENDPOINT'),
    );
  });

  test('collects broken identity, duplicate and relationship invariants', () {
    final contract = _mutableContract();
    final entities = contract['entities'] as List<dynamic>;
    final mascota = entities[1] as Map<String, dynamic>;
    mascota['name'] = 'cliente';
    mascota['endpoint'] = '/outside/mascotas';
    final fields = mascota['fields'] as List<dynamic>;
    (fields.first as Map<String, dynamic>)['generated'] = false;
    final relationships = mascota['relationships'] as List<dynamic>;
    final relationship = relationships.first as Map<String, dynamic>;
    relationship['targetEntity'] = 'Fantasma';
    relationship['many'] = true;

    final exception = _capture(() => loader.loadFromJson(contract));
    final codes = exception.issues.map((issue) => issue.code);

    expect(
      codes,
      containsAll([
        'DUPLICATE_ENTITY_NAME',
        'INVALID_ENDPOINT',
        'INVALID_ID_FIELD',
        'TARGET_ENTITY_NOT_FOUND',
        'INCONSISTENT_CARDINALITY',
      ]),
    );
    expect(exception.userMessage, contains(r'$.entities'));
  });

  test('rejects missing assets as typed contract errors', () async {
    await expectLater(
      loader.loadFromAsset('assets/does-not-exist.json'),
      throwsA(
        isA<DomainModelException>().having(
          (error) => error.issues.single.code,
          'code',
          'ASSET_READ_ERROR',
        ),
      ),
    );
  });
}

DomainModelException _capture(void Function() action) {
  try {
    action();
  } on DomainModelException catch (error) {
    return error;
  }
  throw StateError('Se esperaba DomainModelException.');
}

Map<String, dynamic> _mutableContract() =>
    jsonDecode(jsonEncode(_validContract())) as Map<String, dynamic>;

Map<String, Object?> _validContract() => {
  'schemaVersion': '1.0.0',
  'application': 'Veterinaria',
  'artifactId': 'veterinaria',
  'basePath': '/api',
  'entities': [
    {
      'name': 'Cliente',
      'endpoint': '/api/clientes',
      'idField': 'id',
      'fields': [
        {
          'name': 'id',
          'type': 'Long',
          'required': true,
          'generated': true,
          'unique': true,
        },
        {
          'name': 'nombre',
          'type': 'String',
          'required': true,
          'generated': false,
          'unique': false,
        },
      ],
      'relationships': [
        {
          'name': 'mascotas',
          'apiField': 'mascotasIds',
          'targetEntity': 'Mascota',
          'kind': 'ONE_TO_MANY',
          'many': true,
          'required': false,
          'writable': false,
        },
      ],
    },
    {
      'name': 'Mascota',
      'endpoint': '/api/mascotas',
      'idField': 'id',
      'fields': [
        {
          'name': 'id',
          'type': 'Long',
          'required': true,
          'generated': true,
          'unique': true,
        },
        {
          'name': 'nombre',
          'type': 'String',
          'required': true,
          'generated': false,
          'unique': false,
        },
      ],
      'relationships': [
        {
          'name': 'cliente',
          'apiField': 'clienteId',
          'targetEntity': 'Cliente',
          'kind': 'MANY_TO_ONE',
          'many': false,
          'required': true,
          'writable': true,
        },
      ],
    },
  ],
};
