import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:software1_mobile/ai/intents/intent_service.dart';
import 'package:software1_mobile/core/api/api_client.dart';
import 'package:software1_mobile/core/config/app_configuration.dart';
import 'package:software1_mobile/domain/loading/domain_model_loader.dart';

import 'support/fake_local_ai_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const loader = DomainModelLoader();

  final scenarios = [
    (
      domain: 'hotel',
      entity: 'Reserva',
      endpoint: '/api/reservas',
      instruction: 'crea una reserva',
      parameters: <String, Object>{
        'fechaEntrada': '2026-09-21',
        'fechaSalida': '2026-09-23',
        'huespedId': 1,
        'habitacionId': 1,
      },
    ),
    (
      domain: 'universidad',
      entity: 'Matricula',
      endpoint: '/api/matriculas',
      instruction: 'matricula al estudiante',
      parameters: <String, Object>{
        'fechaRegistro': '2026-09-21',
        'estudianteId': 1,
        'cursoId': 1,
      },
    ),
  ];

  for (final scenario in scenarios) {
    test(
      'assistant executes ${scenario.domain} intent from bundled contract',
      () async {
        final domain = await loader.loadFromAsset(
          'assets/domain-model-${scenario.domain}.json',
        );
        late http.Request captured;
        final api = ApiClient(
          configuration: AppConfiguration.fromValue('http://server.test'),
          httpClient: MockClient((request) async {
            captured = request;
            return http.Response(
              jsonEncode({'id': 1, ...scenario.parameters}),
              201,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        addTearDown(api.close);
        final provider = FakeLocalAIProvider(
          response: jsonEncode({
            'operation': 'CREATE_ENTITY',
            'entity': scenario.entity,
            'parameters': scenario.parameters,
          }),
        );

        final result = await IntentService(
          provider: provider,
          apiClient: api,
        ).execute(scenario.instruction, domain);

        expect(result.statusCode, 201);
        expect(captured.method, 'POST');
        expect(captured.url.path, scenario.endpoint);
        expect(jsonDecode(captured.body), scenario.parameters);
        expect(provider.contexts.single, contains(scenario.entity));
      },
    );
  }
}
