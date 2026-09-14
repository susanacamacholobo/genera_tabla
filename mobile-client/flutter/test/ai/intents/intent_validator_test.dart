import 'package:flutter_test/flutter_test.dart';
import 'package:software1_mobile/ai/intents/intent_exception.dart';
import 'package:software1_mobile/ai/intents/intent_validator.dart';
import 'package:software1_mobile/ai/intents/structured_intent.dart';

import '../../support/domain_model_fixture.dart';

void main() {
  const validator = IntentValidator();
  final domain = buildDomainModelFixture();

  StructuredIntent intent(
    IntentOperation operation, {
    String entity = 'Cliente',
    Object? identifier,
    Map<String, Object?> parameters = const {},
  }) => StructuredIntent(
    operation: operation,
    entity: entity,
    identifier: identifier,
    parameters: parameters,
  );

  test('accepts a complete CREATE_ENTITY body', () {
    final result = validator.validate(
      intent(
        IntentOperation.createEntity,
        parameters: {
          'nombre': 'Ana',
          'saldo': 12.5,
          'fechaRegistro': '2026-09-14T10:30:00-04:00',
        },
      ),
      domain,
    );

    expect(result.isValid, isTrue);
    expect(result.issues, isEmpty);
  });

  test('reports unknown, generated, missing and mistyped fields', () {
    final result = validator.validate(
      intent(
        IntentOperation.createEntity,
        parameters: {'id': 1, 'saldo': 'mucho', 'fantasma': true},
      ),
      domain,
    );

    expect(
      result.issues.map((issue) => issue.code),
      containsAll({
        'READ_ONLY_FIELD',
        'INVALID_FIELD_TYPE',
        'UNKNOWN_PARAMETER',
        'MISSING_REQUIRED_FIELD',
      }),
    );
  });

  test('requires correctly typed identifiers for item operations', () {
    expect(
      validator
          .validate(intent(IntentOperation.getEntity), domain)
          .issues
          .single
          .code,
      'MISSING_IDENTIFIER',
    );
    expect(
      validator
          .validate(
            intent(IntentOperation.deleteEntity, identifier: 'uno'),
            domain,
          )
          .issues
          .single
          .code,
      'INVALID_IDENTIFIER_TYPE',
    );
  });

  test('UPDATE_ENTITY follows the complete generated PUT contract', () {
    final valid = validator.validate(
      intent(
        IntentOperation.updateEntity,
        identifier: 3,
        parameters: {'nombre': 'Bea', 'fechaRegistro': '2026-09-14T11:00:00'},
      ),
      domain,
    );
    final incomplete = validator.validate(
      intent(
        IntentOperation.updateEntity,
        identifier: 3,
        parameters: {'nombre': 'Bea'},
      ),
      domain,
    );

    expect(valid.isValid, isTrue);
    expect(
      incomplete.issues.map((issue) => issue.code),
      contains('MISSING_REQUIRED_FIELD'),
    );
  });

  test('validates required writable relationships against target ID type', () {
    final missing = validator.validate(
      intent(
        IntentOperation.createEntity,
        entity: 'Mascota',
        parameters: {'nombre': 'Luna'},
      ),
      domain,
    );
    final wrongType = validator.validate(
      intent(
        IntentOperation.createEntity,
        entity: 'Mascota',
        parameters: {'nombre': 'Luna', 'clienteId': 'uno'},
      ),
      domain,
    );
    final valid = validator.validate(
      intent(
        IntentOperation.createEntity,
        entity: 'Mascota',
        parameters: {'nombre': 'Luna', 'cliente': 1},
      ),
      domain,
    );

    expect(
      missing.issues.map((issue) => issue.code),
      contains('MISSING_REQUIRED_RELATIONSHIP'),
    );
    expect(
      wrongType.issues.map((issue) => issue.code),
      contains('INVALID_RELATIONSHIP_VALUE'),
    );
    expect(valid.isValid, isTrue);
  });

  test('rejects read-only relationships in writes', () {
    final result = validator.validate(
      intent(
        IntentOperation.createEntity,
        parameters: {
          'nombre': 'Ana',
          'fechaRegistro': '2026-09-14T10:30:00',
          'mascotasIds': [1, 2],
        },
      ),
      domain,
    );

    expect(
      result.issues.map((issue) => issue.code),
      contains('READ_ONLY_RELATIONSHIP'),
    );
  });

  test('enforces parameter rules for list and search operations', () {
    final list = validator.validate(
      intent(IntentOperation.listEntities, parameters: {'nombre': 'Ana'}),
      domain,
    );
    final emptySearch = validator.validate(
      intent(IntentOperation.searchEntity),
      domain,
    );
    final search = validator.validate(
      intent(
        IntentOperation.searchEntity,
        parameters: {'ID': 1, 'mascotas': 2},
      ),
      domain,
    );

    expect(list.issues.single.code, 'PARAMETERS_NOT_ALLOWED');
    expect(emptySearch.issues.single.code, 'MISSING_SEARCH_FILTER');
    expect(search.isValid, isTrue);
  });

  test('assertValid exposes typed validation failures', () {
    expect(
      () => validator.assertValid(
        intent(IntentOperation.listEntities, entity: 'Desconocida'),
        domain,
      ),
      throwsA(
        isA<IntentValidationException>().having(
          (error) => error.issues.first.code,
          'first issue',
          'ENTITY_NOT_FOUND',
        ),
      ),
    );
  });
}
