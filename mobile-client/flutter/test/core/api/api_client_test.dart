import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:software1_mobile/core/api/api_client.dart';
import 'package:software1_mobile/core/config/app_configuration.dart';
import 'package:software1_mobile/core/errors/app_exception.dart';

void main() {
  group('ApiClient', () {
    test('executes GET with query parameters and decodes UTF-8 JSON', () async {
      final transport = MockClient((request) async {
        expect(request.method, 'GET');
        expect(
          request.url.toString(),
          'http://server.test/api/clientes?page=2',
        );
        expect(request.headers['accept'], 'application/json');
        return http.Response.bytes(
          utf8.encode('{"nombre":"Ángela"}'),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final client = _client(transport);
      addTearDown(client.close);

      final response = await client.get(
        '/clientes',
        queryParameters: {'page': '2'},
      );

      expect(response.statusCode, 200);
      expect(response.data, {'nombre': 'Ángela'});
    });

    test('supports POST, PUT and DELETE with JSON requests', () async {
      final requests = <http.Request>[];
      final transport = MockClient((request) async {
        requests.add(request);
        return http.Response(
          request.method == 'DELETE' ? '' : '{"ok":true}',
          request.method == 'POST' ? 201 : 200,
          headers: {
            if (request.method != 'DELETE') 'content-type': 'application/json',
          },
        );
      });
      final client = _client(transport);
      addTearDown(client.close);

      await client.post('/clientes', body: {'nombre': 'Ana'});
      await client.put('/clientes/1', body: {'nombre': 'Bea'});
      await client.delete('/clientes/1');

      expect(requests.map((request) => request.method), [
        'POST',
        'PUT',
        'DELETE',
      ]);
      expect(jsonDecode(requests[0].body), {'nombre': 'Ana'});
      expect(requests[0].headers['content-type'], contains('application/json'));
      expect(jsonDecode(requests[1].body), {'nombre': 'Bea'});
      expect(requests[2].body, isEmpty);
    });

    test('turns non-success responses into typed API errors', () async {
      final client = _client(
        MockClient(
          (_) async => http.Response(
            '{"message":"Cliente duplicado"}',
            409,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      addTearDown(client.close);

      await expectLater(
        client.post('/clientes', body: {'nombre': 'Ana'}),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'statusCode', 409)
              .having(
                (error) => error.userMessage,
                'userMessage',
                'Cliente duplicado',
              ),
        ),
      );
    });

    test('reports malformed successful JSON', () async {
      final client = _client(
        MockClient(
          (_) async => http.Response(
            '{invalid',
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      addTearDown(client.close);

      await expectLater(
        client.get('/clientes'),
        throwsA(isA<ResponseDecodingException>()),
      );
    });

    test('preserves the HTTP status when an error body is malformed', () async {
      final client = _client(
        MockClient(
          (_) async => http.Response(
            '{invalid',
            502,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      addTearDown(client.close);

      await expectLater(
        client.get('/clientes'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'statusCode',
            502,
          ),
        ),
      );
    });

    test(
      'maps transport failures without exposing implementation details',
      () async {
        final client = _client(
          MockClient((request) async {
            throw http.ClientException('socket details', request.url);
          }),
        );
        addTearDown(client.close);

        await expectLater(
          client.get('/clientes'),
          throwsA(
            isA<NetworkException>().having(
              (error) => error.userMessage,
              'userMessage',
              contains('conexión'),
            ),
          ),
        );
      },
    );
  });
}

ApiClient _client(http.Client transport) => ApiClient(
  configuration: AppConfiguration.fromValue('http://server.test/api'),
  httpClient: transport,
);
