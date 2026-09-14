import 'package:flutter_test/flutter_test.dart';
import 'package:software1_mobile/ai/intents/intent_exception.dart';
import 'package:software1_mobile/ai/intents/structured_intent.dart';
import 'package:software1_mobile/ai/intents/structured_intent_parser.dart';

void main() {
  const parser = StructuredIntentParser();

  test('parses the strict structured intent contract', () {
    final intent = parser.parse('''
      {
        "operation": "create_entity",
        "entity": " Cliente ",
        "parameters": {"nombre": "Ana", "saldo": 12.5}
      }
    ''');

    expect(intent.operation, IntentOperation.createEntity);
    expect(intent.entity, 'Cliente');
    expect(intent.identifier, isNull);
    expect(intent.parameters, {'nombre': 'Ana', 'saldo': 12.5});
    expect(() => intent.parameters['nombre'] = 'Bea', throwsUnsupportedError);
  });

  test('accepts scalar identifiers and lists of scalar parameters', () {
    final intent = parser.parse(
      '{"operation":"UPDATE_ENTITY","entity":"Cliente",'
      '"identifier":7,"parameters":{"ids":[1,2,null]}}',
    );

    expect(intent.identifier, 7);
    expect(intent.parameters['ids'], [1, 2, null]);
  });

  test('rejects malformed JSON and Markdown wrappers', () {
    for (final response in [
      '{invalid',
      '```json\n{"operation":"LIST_ENTITIES","entity":"Cliente"}\n```',
    ]) {
      expect(
        () => parser.parse(response),
        throwsA(isA<IntentFormatException>()),
      );
    }
  });

  test('rejects unknown operations and extra root properties', () {
    expect(
      () => parser.parse('{"operation":"DROP_TABLE","entity":"Cliente"}'),
      throwsA(isA<IntentFormatException>()),
    );
    expect(
      () => parser.parse(
        '{"operation":"LIST_ENTITIES","entity":"Cliente","admin":true}',
      ),
      throwsA(isA<IntentFormatException>()),
    );
  });

  test('rejects nested parameter objects and invalid identifiers', () {
    expect(
      () => parser.parse(
        '{"operation":"SEARCH_ENTITY","entity":"Cliente",'
        '"parameters":{"nombre":{"contains":"Ana"}}}',
      ),
      throwsA(isA<IntentFormatException>()),
    );
    expect(
      () => parser.parse(
        '{"operation":"GET_ENTITY","entity":"Cliente",'
        '"identifier":[1]}',
      ),
      throwsA(isA<IntentFormatException>()),
    );
  });
}
