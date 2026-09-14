import 'package:flutter_test/flutter_test.dart';
import 'package:software1_mobile/ai/context/domain_context_builder.dart';

import '../../support/domain_model_fixture.dart';

void main() {
  test('builds local AI context from the current domain contract', () {
    final context = const DomainContextBuilder().build(
      buildDomainModelFixture(),
    );

    expect(context, contains('Available entities for Veterinaria'));
    expect(context, contains('Cliente (/clientes)'));
    expect(context, contains('nombre: String, required'));
    expect(context, contains('id: Long, required, generated'));
    expect(context, contains('mascotasIds: ID[] of Mascota'));
    expect(context, contains('clienteId: ID of Cliente, required'));
    expect(context, contains('CREATE_ENTITY'));
    expect(context, contains('SEARCH_ENTITY'));
  });
}
