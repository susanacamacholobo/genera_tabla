import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:software1_mobile/app.dart';
import 'package:software1_mobile/core/api/api_client.dart';
import 'package:software1_mobile/core/config/app_configuration.dart';

import 'support/fake_local_ai_provider.dart';
import 'support/fake_speech_to_text_provider.dart';

void main() {
  testWidgets('connects voice, local AI, validated intent and REST', (
    WidgetTester tester,
  ) async {
    final configuration = AppConfiguration.fromValue(
      'http://192.168.1.50:8080',
    );
    final apiClient = ApiClient(
      configuration: configuration,
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/clientes');
        return http.Response(
          '[{"id":1,"nombre":"Ana"}]',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(apiClient.close);
    final localAI = FakeLocalAIProvider(
      response:
          '{"operation":"LIST_ENTITIES","entity":"Cliente",'
          '"parameters":{}}',
    );
    final speech = FakeSpeechToTextProvider();
    await tester.pumpWidget(
      Software1App(
        configuration: configuration,
        apiClient: apiClient,
        speechToTextProvider: speech,
        localAIProvider: localAI,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Base Flutter lista'), findsOneWidget);
    expect(find.text('http://192.168.1.50:8080/'), findsOneWidget);
    expect(find.text('Veterinaria'), findsOneWidget);
    expect(find.text('1 entidad disponible'), findsOneWidget);

    await tester.tap(find.text('Abrir asistente'));
    await tester.pumpAndSettle();

    expect(find.text('Asistente'), findsOneWidget);
    await tester.tap(find.byTooltip('Usar micrófono sin conexión'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, 'lista los clientes');
    await tester.tap(find.text('Enviar'));
    await tester.pump();
    for (var attempt = 0; attempt < 20; attempt++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.text('Consulta completada').evaluate().isNotEmpty) break;
    }

    expect(find.text('Consulta completada'), findsOneWidget);
    expect(find.text('Instrucción: lista los clientes'), findsOneWidget);
    expect(find.textContaining('"nombre": "Ana"'), findsOneWidget);
    expect(speech.listenCalls, 1);
    expect(speech.locales, ['es-ES']);
    expect(localAI.instructions, ['lista los clientes']);
    expect(localAI.contexts.single, contains('Cliente (/api/clientes)'));
  });
}
