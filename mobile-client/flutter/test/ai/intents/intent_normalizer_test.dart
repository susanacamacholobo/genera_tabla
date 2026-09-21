import 'package:flutter_test/flutter_test.dart';
import 'package:software1_mobile/ai/intents/intent_normalizer.dart';
import 'package:software1_mobile/ai/intents/intent_validator.dart';
import 'package:software1_mobile/ai/intents/structured_intent.dart';

import '../../support/domain_model_fixture.dart';

void main() {
  const normalizer = IntentNormalizer();
  const validator = IntentValidator();
  final domain = buildDomainModelFixture();

  StructuredIntent create(Map<String, Object?> parameters) => StructuredIntent(
    operation: IntentOperation.createEntity,
    entity: 'Cliente',
    parameters: parameters,
  );

  test('drops an unsolicited optional zero serialized as text', () {
    final result = normalizer.normalize(
      create({
        'nombre': 'Prueba Offline',
        'saldo': '0',
        'fechaRegistro': '2026-09-21T14:00:00',
      }),
      domain,
      instruction:
          'Crea un cliente llamado Prueba Offline con fecha de registro 2026-09-21T14:00:00',
    );

    expect(result.parameters.containsKey('saldo'), isFalse);
    expect(validator.validate(result, domain).isValid, isTrue);
  });

  test('also drops an unsolicited optional JSON number zero', () {
    final result = normalizer.normalize(
      create({
        'nombre': 'Prueba Offline',
        'saldo': 0,
        'fechaRegistro': '2026-09-21T14:00:00',
      }),
      domain,
      instruction: 'Crea cliente Prueba Offline',
    );

    expect(result.parameters.containsKey('saldo'), isFalse);
  });

  test('keeps a requested zero and converts numeric strings', () {
    final result = normalizer.normalize(
      create({
        'nombre': 'Ana',
        'saldo': '0',
        'fechaRegistro': '2026-09-21T14:00:00',
      }),
      domain,
      instruction: 'Crea cliente Ana con saldo 0',
    );

    expect(result.parameters['saldo'], 0);
    expect(validator.validate(result, domain).isValid, isTrue);
  });

  test('converts a requested decimal without changing invalid text', () {
    final converted = normalizer.normalize(
      create({'saldo': '12.50'}),
      domain,
      instruction: 'saldo 12.50',
    );
    final invalid = normalizer.normalize(
      create({'saldo': 'mucho'}),
      domain,
      instruction: 'saldo mucho',
    );

    expect(converted.parameters['saldo'], 12.5);
    expect(invalid.parameters['saldo'], 'mucho');
    expect(
      validator.validate(invalid, domain).issues.map((issue) => issue.code),
      contains('INVALID_FIELD_TYPE'),
    );
  });
}
