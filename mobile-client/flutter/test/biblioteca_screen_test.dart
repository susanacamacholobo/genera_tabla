import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:software1_mobile/app.dart';
import 'package:software1_mobile/core/api/api_client.dart';
import 'package:software1_mobile/core/config/app_configuration.dart';
import 'package:software1_mobile/offline/memory_offline_store.dart';

import 'support/fake_local_ai_provider.dart';
import 'support/fake_speech_to_text_provider.dart';

void main() {
  testWidgets('Biblioteca permite crear, editar y eliminar un socio', (
    tester,
  ) async {
    final socios = <Map<String, dynamic>>[];
    final configuration = AppConfiguration.fromValue('http://127.0.0.1:8081');
    final api = ApiClient(
      configuration: configuration,
      httpClient: MockClient((request) async {
        expect(request.url.path, startsWith('/api/socios'));
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode(socios),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.method == 'POST') {
          socios.add({
            'id': 1,
            ...jsonDecode(request.body) as Map<String, dynamic>,
          });
          return http.Response(
            jsonEncode(socios.single),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.method == 'PUT') {
          socios[0] = {
            'id': 1,
            ...jsonDecode(request.body) as Map<String, dynamic>,
          };
          return http.Response(
            jsonEncode(socios.single),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.method == 'DELETE') {
          socios.clear();
          return http.Response('', 204);
        }
        throw StateError('Método inesperado: ${request.method}');
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      Software1App(
        configuration: configuration,
        apiClient: api,
        localAIProvider: FakeLocalAIProvider(response: '{}'),
        speechToTextProvider: FakeSpeechToTextProvider(),
        offlineStore: MemoryOfflineStore(),
      ),
    );
    await tester.pumpAndSettle();
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed('/biblioteca');
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Ana');
    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();
    expect(find.text('1 · Ana'), findsOneWidget);

    await tester.tap(find.text('1 · Ana'));
    await tester.enterText(find.byType(TextField).first, 'Ana María');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('1 · Ana María'), findsOneWidget);

    await tester.tap(find.byTooltip('Eliminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar').last);
    await tester.pumpAndSettle();
    expect(find.text('Sin registros.'), findsOneWidget);
    expect(socios, isEmpty);
  });
}
