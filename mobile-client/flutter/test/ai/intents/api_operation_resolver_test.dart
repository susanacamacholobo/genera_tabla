import 'package:flutter_test/flutter_test.dart';
import 'package:software1_mobile/ai/intents/api_operation_resolver.dart';
import 'package:software1_mobile/ai/intents/intent_exception.dart';
import 'package:software1_mobile/ai/intents/structured_intent.dart';

import '../../support/domain_model_fixture.dart';

void main() {
  const resolver = ApiOperationResolver();
  final domain = buildDomainModelFixture();

  StructuredIntent intent(
    IntentOperation operation, {
    Object? identifier,
    Map<String, Object?> parameters = const {},
  }) => StructuredIntent(
    operation: operation,
    entity: 'cliente',
    identifier: identifier,
    parameters: parameters,
  );

  test('resolves create, get, list, update and delete HTTP operations', () {
    final body = {'NOMBRE': 'Ana', 'FECHAREGISTRO': '2026-09-14T10:30:00'};
    final create = resolver.resolve(
      intent(IntentOperation.createEntity, parameters: body),
      domain,
    );
    final get = resolver.resolve(
      intent(IntentOperation.getEntity, identifier: 7),
      domain,
    );
    final list = resolver.resolve(intent(IntentOperation.listEntities), domain);
    final update = resolver.resolve(
      intent(IntentOperation.updateEntity, identifier: 7, parameters: body),
      domain,
    );
    final delete = resolver.resolve(
      intent(IntentOperation.deleteEntity, identifier: 7),
      domain,
    );

    expect(create.method, ApiMethod.post);
    expect(create.path, '/clientes');
    expect(create.body, {
      'nombre': 'Ana',
      'fechaRegistro': '2026-09-14T10:30:00',
    });
    expect(get.method, ApiMethod.get);
    expect(get.path, '/clientes/7');
    expect(list.method, ApiMethod.get);
    expect(list.path, '/clientes');
    expect(update.method, ApiMethod.put);
    expect(update.path, '/clientes/7');
    expect(update.body, create.body);
    expect(delete.method, ApiMethod.delete);
    expect(delete.path, '/clientes/7');
  });

  test('resolves search as collection GET plus canonical local filters', () {
    final operation = resolver.resolve(
      intent(
        IntentOperation.searchEntity,
        parameters: {'NOMBRE': 'ana', 'MASCOTAS': 2},
      ),
      domain,
    );

    expect(operation.method, ApiMethod.get);
    expect(operation.path, '/clientes');
    expect(operation.body, isNull);
    expect(operation.localFilters, {'nombre': 'ana', 'mascotasIds': 2});
    expect(operation.requiresLocalFiltering, isTrue);
  });

  test('validates before resolving an operation', () {
    expect(
      () => resolver.resolve(intent(IntentOperation.createEntity), domain),
      throwsA(isA<IntentValidationException>()),
    );
  });
}
