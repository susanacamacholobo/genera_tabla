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
  final scenarios = [
    (
      name: 'Hotel',
      route: '/hotel',
      tabs: ['Huéspedes', 'Habitaciones', 'Reservas'],
      paths: ['/api/huespedes', '/api/habitaciones', '/api/reservas'],
      values: [
        ['Ana Pérez'],
        ['101', '120,50'],
        ['2026-09-21', '2026-09-23', '1', '1'],
      ],
      relationshipKeys: ['huespedId', 'habitacionId'],
    ),
    (
      name: 'Universidad',
      route: '/universidad',
      tabs: ['Estudiantes', 'Cursos', 'Matrículas'],
      paths: ['/api/estudiantes', '/api/cursos', '/api/matriculas'],
      values: [
        ['Luis Flores', 'E-001'],
        ['Programación I', 'C-001'],
        ['2026-09-21', '1', '1'],
      ],
      relationshipKeys: ['estudianteId', 'cursoId'],
    ),
  ];

  for (final scenario in scenarios) {
    testWidgets(
      '${scenario.name} permite crear, editar y borrar las relaciones',
      (tester) async {
        final records = {
          for (final path in scenario.paths) path: <Map<String, dynamic>>[],
        };
        final configuration = AppConfiguration.fromValue(
          'http://127.0.0.1:8082',
        );
        final api = ApiClient(
          configuration: configuration,
          httpClient: MockClient((request) async {
            final path = request.url.path;
            final collection = scenario.paths.firstWhere(
              (candidate) =>
                  path == candidate || path.startsWith('$candidate/'),
            );
            final rows = records[collection]!;
            if (request.method == 'GET') {
              return http.Response(
                jsonEncode(rows),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (request.method == 'POST') {
              final row = {
                'id': rows.length + 1,
                ...jsonDecode(request.body) as Map<String, dynamic>,
              };
              rows.add(row);
              return http.Response(
                jsonEncode(row),
                201,
                headers: {'content-type': 'application/json'},
              );
            }
            if (request.method == 'PUT') {
              rows[0] = {
                'id': 1,
                ...jsonDecode(request.body) as Map<String, dynamic>,
              };
              return http.Response(
                jsonEncode(rows[0]),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (request.method == 'DELETE') {
              rows.removeWhere(
                (row) => row['id'] == int.parse(path.split('/').last),
              );
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
        await tester.pump();
        tester
            .state<NavigatorState>(find.byType(Navigator))
            .pushNamed(scenario.route);
        await tester.pumpAndSettle();

        for (var section = 0; section < scenario.tabs.length; section++) {
          if (section > 0) {
            await tester.tap(find.text(scenario.tabs[section]));
            await tester.pumpAndSettle();
          }
          final values = scenario.values[section];
          final fields = find.byType(TextField);
          expect(fields, findsNWidgets(values.length));
          for (var index = 0; index < values.length; index++) {
            await tester.enterText(fields.at(index), values[index]);
          }
          await tester.tap(find.text('Crear'));
          await tester.pumpAndSettle();
          expect(records[scenario.paths[section]], hasLength(1));
        }

        final dependent = records[scenario.paths.last]!.single;
        for (final key in scenario.relationshipKeys) {
          expect(dependent[key], 1);
        }
        await tester.tap(find.byType(ListTile).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Guardar'));
        await tester.pumpAndSettle();
        expect(records[scenario.paths.last], hasLength(1));
        await tester.tap(find.byTooltip('Eliminar'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Eliminar').last);
        await tester.pumpAndSettle();
        expect(records[scenario.paths.last], isEmpty);
      },
    );
  }
}
