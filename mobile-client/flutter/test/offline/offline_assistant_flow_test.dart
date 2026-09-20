import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:software1_mobile/app.dart';
import 'package:software1_mobile/core/api/api_client.dart';
import 'package:software1_mobile/core/config/app_configuration.dart';
import 'package:software1_mobile/offline/memory_offline_store.dart';

import '../support/fake_local_ai_provider.dart';
import '../support/fake_speech_to_text_provider.dart';

void main() {
  testWidgets('queues an offline assistant write and synchronizes it later', (
    WidgetTester tester,
  ) async {
    var online = false;
    final configuration = AppConfiguration.fromValue('http://server.test');
    final apiClient = ApiClient(
      configuration: configuration,
      httpClient: MockClient((request) async {
        if (!online) throw http.ClientException('offline');
        return http.Response(
          '{"id":7,"nombre":"Ana","fechaRegistro":"2026-09-20T18:30:00"}',
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(apiClient.close);
    final localAI = FakeLocalAIProvider(
      response:
          '{"operation":"CREATE_ENTITY","entity":"Cliente",'
          '"parameters":{"nombre":"Ana",'
          '"fechaRegistro":"2026-09-20T18:30:00"}}',
    );
    await tester.pumpWidget(
      Software1App(
        configuration: configuration,
        apiClient: apiClient,
        speechToTextProvider: FakeSpeechToTextProvider(),
        localAIProvider: localAI,
        offlineStore: MemoryOfflineStore(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir asistente'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'crea una cliente Ana');
    final sendButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Enviar'),
    );
    sendButton.onPressed!();
    await _pumpUntil(tester, find.text('Cambio guardado sin conexión'));

    expect(find.text('Modo sin conexión'), findsOneWidget);
    expect(find.textContaining('1 cambio pendiente'), findsOneWidget);

    online = true;
    final syncButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.sync),
    );
    syncButton.onPressed!();
    await _pumpUntil(tester, find.text('Conectado al servidor'));

    expect(find.byTooltip('Sincronizar cambios pendientes'), findsNothing);
  });
}

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  int attempts = 30,
}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('No apareció el widget esperado: $finder');
}
