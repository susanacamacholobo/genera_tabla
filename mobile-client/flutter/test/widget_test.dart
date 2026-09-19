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
  testWidgets('navigates from the reusable home to the assistant', (
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
    await tester.pumpWidget(
      Software1App(
        configuration: configuration,
        apiClient: apiClient,
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
    await tester.enterText(find.byType(EditableText), 'Muéstrame los clientes');
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();

    expect(find.text('Consulta completada'), findsOneWidget);
    expect(find.text('Instrucción: Muéstrame los clientes'), findsOneWidget);
    expect(find.textContaining('"nombre": "Ana"'), findsOneWidget);
    expect(localAI.instructions, ['Muéstrame los clientes']);
    expect(localAI.contexts.single, contains('Cliente (/api/clientes)'));
  });

  testWidgets('connects the assistant microphone to the speech provider', (
    WidgetTester tester,
  ) async {
    final speech = FakeSpeechToTextProvider();
    await tester.pumpWidget(
      Software1App(
        configuration: AppConfiguration.fromValue('http://10.0.2.2:8080'),
        speechToTextProvider: speech,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Abrir asistente'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Usar micrófono sin conexión'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, 'lista los clientes');
    expect(speech.listenCalls, 1);
    expect(speech.locales, ['es-BO']);
  });
}
