import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:software1_mobile/ai/intents/api_operation_resolver.dart';
import 'package:software1_mobile/core/api/api_client.dart';
import 'package:software1_mobile/core/config/app_configuration.dart';
import 'package:software1_mobile/offline/memory_offline_store.dart';
import 'package:software1_mobile/offline/offline_data_coordinator.dart';

import '../support/domain_model_fixture.dart';

void main() {
  final domain = buildDomainModelFixture();
  final entity = domain.entityNamed('Cliente')!;

  test(
    'caches an online list and returns it when the server is offline',
    () async {
      var online = true;
      final client = _client(
        MockClient((_) async {
          if (!online) throw http.ClientException('offline');
          return http.Response(
            '[{"id":1,"nombre":"Ana"}]',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final coordinator = OfflineDataCoordinator(
        apiClient: client,
        store: MemoryOfflineStore(),
      );
      addTearDown(() {
        coordinator.dispose();
        client.close();
      });
      final operation = ResolvedApiOperation(
        method: ApiMethod.get,
        path: entity.endpoint,
      );

      final remote = await coordinator.execute(operation, entity, domain);
      online = false;
      final local = await coordinator.execute(operation, entity, domain);

      expect(remote.fromLocalStorage, isFalse);
      expect(local.fromLocalStorage, isTrue);
      expect(local.response.data, [
        {'id': 1, 'nombre': 'Ana'},
      ]);
      expect(coordinator.connectionState, DataConnectionState.offline);
    },
  );

  test(
    'queues an offline create and synchronizes it with a remote id',
    () async {
      var online = false;
      var remoteCalls = 0;
      final store = MemoryOfflineStore();
      final client = _client(
        MockClient((request) async {
          remoteCalls++;
          if (!online) throw http.ClientException('offline');
          expect(request.method, 'POST');
          expect(jsonDecode(request.body), {'nombre': 'Ana'});
          return http.Response(
            '{"id":42,"nombre":"Ana"}',
            201,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final coordinator = OfflineDataCoordinator(
        apiClient: client,
        store: store,
      );
      addTearDown(() {
        coordinator.dispose();
        client.close();
      });
      final operation = ResolvedApiOperation(
        method: ApiMethod.post,
        path: entity.endpoint,
        body: const {'nombre': 'Ana'},
      );

      final local = await coordinator.execute(operation, entity, domain);

      expect(local.response.statusCode, 202);
      expect(local.queued, isTrue);
      expect(coordinator.pendingCount, 1);
      expect(remoteCalls, 1);
      final temporaryId = (local.response.data! as Map)['id'];
      expect(temporaryId, isNegative);

      online = true;
      expect(await coordinator.synchronize(domain), isTrue);
      expect(coordinator.pendingCount, 0);
      expect(await store.readById(entity, temporaryId), isNull);
      expect(await store.readById(entity, 42), {'id': 42, 'nombre': 'Ana'});
      expect(coordinator.connectionState, DataConnectionState.online);
    },
  );

  test('retries connectivity on a later read without pending writes', () async {
    var online = false;
    final client = _client(
      MockClient((_) async {
        if (!online) throw http.ClientException('offline');
        return http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final coordinator = OfflineDataCoordinator(
      apiClient: client,
      store: MemoryOfflineStore(),
    );
    addTearDown(() {
      coordinator.dispose();
      client.close();
    });
    final operation = ResolvedApiOperation(
      method: ApiMethod.get,
      path: entity.endpoint,
    );

    expect(
      (await coordinator.execute(operation, entity, domain)).fromLocalStorage,
      isTrue,
    );
    online = true;
    expect(
      (await coordinator.execute(operation, entity, domain)).fromLocalStorage,
      isFalse,
    );
    expect(coordinator.connectionState, DataConnectionState.online);
  });

  test(
    'remaps later queued writes after synchronizing a local create',
    () async {
      var online = false;
      final requestedPaths = <String>[];
      final client = _client(
        MockClient((request) async {
          if (!online) throw http.ClientException('offline');
          requestedPaths.add(request.url.path);
          if (request.method == 'POST') {
            return http.Response(
              '{"id":42,"nombre":"Ana"}',
              201,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            '{"id":42,"nombre":"Ana Maria"}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final store = MemoryOfflineStore();
      final coordinator = OfflineDataCoordinator(
        apiClient: client,
        store: store,
      );
      addTearDown(() {
        coordinator.dispose();
        client.close();
      });
      final create = await coordinator.execute(
        ResolvedApiOperation(
          method: ApiMethod.post,
          path: entity.endpoint,
          body: const {'nombre': 'Ana'},
        ),
        entity,
        domain,
      );
      final temporaryId = (create.response.data! as Map)['id'];
      await coordinator.execute(
        ResolvedApiOperation(
          method: ApiMethod.put,
          path: '${entity.endpoint}/$temporaryId',
          body: const {'nombre': 'Ana Maria'},
        ),
        entity,
        domain,
      );

      online = true;
      expect(await coordinator.synchronize(domain), isTrue);

      expect(requestedPaths, ['/api/clientes', '/api/clientes/42']);
      expect(coordinator.pendingCount, 0);
    },
  );
}

ApiClient _client(http.Client transport) => ApiClient(
  configuration: AppConfiguration.fromValue('http://server.test/api'),
  httpClient: transport,
  timeout: const Duration(milliseconds: 100),
);
