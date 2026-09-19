import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:software1_mobile/ai/intents/intent_exception.dart';
import 'package:software1_mobile/ai/intents/intent_service.dart';
import 'package:software1_mobile/ai/intents/structured_intent.dart';
import 'package:software1_mobile/core/api/api_client.dart';
import 'package:software1_mobile/core/config/app_configuration.dart';

import '../../support/domain_model_fixture.dart';
import '../../support/fake_local_ai_provider.dart';

void main() {
  final domain = buildDomainModelFixture();

  test(
    'loads the model, sends domain context and executes LIST_ENTITIES',
    () async {
      var requestCount = 0;
      final client = _client(
        MockClient((request) async {
          requestCount++;
          expect(request.method, 'GET');
          expect(request.url.toString(), 'http://server.test/api/clientes');
          return http.Response(
            '[{"id":1,"nombre":"Ana"}]',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.close);
      final provider = FakeLocalAIProvider(
        response:
            '{"operation":"LIST_ENTITIES","entity":"Cliente",'
            '"parameters":{}}',
      );
      final service = IntentService(provider: provider, apiClient: client);

      final first = await service.execute('  lista los clientes  ', domain);
      final second = await service.execute('lista otra vez', domain);

      expect(first.intent.operation, IntentOperation.listEntities);
      expect(first.statusCode, 200);
      expect(first.data, [
        {'id': 1, 'nombre': 'Ana'},
      ]);
      expect(second.statusCode, 200);
      expect(provider.loadCalls, 1);
      expect(provider.instructions, ['lista los clientes', 'lista otra vez']);
      expect(provider.contexts, hasLength(2));
      expect(provider.contexts, everyElement(contains('Cliente (/clientes)')));
      expect(requestCount, 2);
    },
  );

  test('executes CREATE_ENTITY with a validated canonical JSON body', () async {
    late http.Request captured;
    final client = _client(
      MockClient((request) async {
        captured = request;
        return http.Response(
          '{"id":9,"nombre":"Ana"}',
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.close);
    final provider = FakeLocalAIProvider(
      response: jsonEncode({
        'operation': 'CREATE_ENTITY',
        'entity': 'cliente',
        'parameters': {'NOMBRE': 'Ana', 'FECHAREGISTRO': '2026-09-14T10:30:00'},
      }),
    );

    final result = await IntentService(
      provider: provider,
      apiClient: client,
    ).execute('crea una cliente llamada Ana', domain);

    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/clientes');
    expect(jsonDecode(captured.body), {
      'nombre': 'Ana',
      'fechaRegistro': '2026-09-14T10:30:00',
    });
    expect(result.statusCode, 201);
  });

  test('rejects invalid intent before making an HTTP request', () async {
    var requestCount = 0;
    final client = _client(
      MockClient((_) async {
        requestCount++;
        return http.Response('{}', 200);
      }),
    );
    addTearDown(client.close);
    final provider = FakeLocalAIProvider(
      response:
          '{"operation":"DELETE_ENTITY","entity":"Cliente",'
          '"parameters":{}}',
    );

    await expectLater(
      IntentService(
        provider: provider,
        apiClient: client,
      ).execute('borra un cliente', domain),
      throwsA(isA<IntentValidationException>()),
    );
    expect(requestCount, 0);
  });

  test('maps provider internals to a safe local AI error', () async {
    final client = _client(MockClient((_) async => http.Response('{}', 200)));
    addTearDown(client.close);
    final provider = FakeLocalAIProvider(
      response: '',
      generationFailure: StateError('native model crashed at secret path'),
    );

    await expectLater(
      IntentService(
        provider: provider,
        apiClient: client,
      ).execute('lista clientes', domain),
      throwsA(
        isA<LocalAIException>()
            .having(
              (error) => error.userMessage,
              'user message',
              contains('IA local'),
            )
            .having(
              (error) => error.userMessage,
              'private details',
              isNot(contains('secret path')),
            ),
      ),
    );
  });

  test('preserves actionable typed local model errors', () async {
    final client = _client(MockClient((_) async => http.Response('{}', 200)));
    addTearDown(client.close);
    final provider = FakeLocalAIProvider(
      response: '',
      loadFailure: const LocalModelException('Importa un modelo local.'),
    );

    await expectLater(
      IntentService(
        provider: provider,
        apiClient: client,
      ).execute('lista clientes', domain),
      throwsA(
        isA<LocalModelException>().having(
          (error) => error.userMessage,
          'user message',
          'Importa un modelo local.',
        ),
      ),
    );
  });

  test(
    'implements SEARCH_ENTITY through collection GET and local filtering',
    () async {
      late http.Request captured;
      final client = _client(
        MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode([
              {
                'id': 1,
                'nombre': 'Ana María',
                'mascotasIds': [2, 3],
              },
              {
                'id': 2,
                'nombre': 'Beatriz',
                'mascotasIds': [2],
              },
              {
                'id': 3,
                'nombre': 'ANA',
                'mascotasIds': [5],
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.close);
      final provider = FakeLocalAIProvider(
        response:
            '{"operation":"SEARCH_ENTITY","entity":"Cliente",'
            '"parameters":{"nombre":"ana","mascotasIds":2}}',
      );

      final result = await IntentService(
        provider: provider,
        apiClient: client,
      ).execute('busca clientes Ana con mascota 2', domain);

      expect(captured.method, 'GET');
      expect(captured.url.toString(), 'http://server.test/api/clientes');
      expect(result.operation.requiresLocalFiltering, isTrue);
      expect(result.data, [
        {
          'id': 1,
          'nombre': 'Ana María',
          'mascotasIds': [2, 3],
        },
      ]);
    },
  );

  test('rejects an empty user instruction without loading the model', () async {
    final client = _client(MockClient((_) async => http.Response('{}', 200)));
    addTearDown(client.close);
    final provider = FakeLocalAIProvider(response: '{}');

    await expectLater(
      IntentService(
        provider: provider,
        apiClient: client,
      ).execute('   ', domain),
      throwsA(isA<IntentFormatException>()),
    );
    expect(provider.loadCalls, 0);
  });
}

ApiClient _client(http.Client transport) => ApiClient(
  configuration: AppConfiguration.fromValue('http://server.test/api'),
  httpClient: transport,
);
