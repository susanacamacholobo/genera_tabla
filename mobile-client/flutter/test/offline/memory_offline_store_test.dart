import 'package:flutter_test/flutter_test.dart';
import 'package:software1_mobile/ai/intents/api_operation_resolver.dart';
import 'package:software1_mobile/offline/memory_offline_store.dart';
import 'package:software1_mobile/offline/pending_mutation.dart';

import '../support/domain_model_fixture.dart';

void main() {
  final entity = buildDomainModelFixture().entityNamed('Cliente')!;

  test('caches remote records and preserves dirty local records', () async {
    final store = MemoryOfflineStore();
    await store.upsertRecord(entity, {
      'id': -1,
      'nombre': 'Local',
    }, dirty: true);
    await store.replaceRemoteCollection(entity, [
      {'id': 1, 'nombre': 'Ana'},
    ]);
    await store.replaceRemoteCollection(entity, [
      {'id': 2, 'nombre': 'Beatriz'},
    ]);

    expect(
      await store.readAll(entity),
      containsAll([
        {'id': -1, 'nombre': 'Local'},
        {'id': 2, 'nombre': 'Beatriz'},
      ]),
    );
    expect(await store.readById(entity, 1), isNull);
  });

  test(
    'keeps queued mutations ordered and remaps temporary identifiers',
    () async {
      final store = MemoryOfflineStore();
      await store.upsertRecord(entity, {
        'id': -7,
        'nombre': 'Ana',
      }, dirty: true);
      await store.enqueue(
        PendingMutation(
          method: ApiMethod.post,
          path: entity.endpoint,
          entityName: entity.name,
          recordKey: '-7',
          body: const {'nombre': 'Ana'},
          createdAt: DateTime.utc(2026, 9, 20),
        ),
      );
      await store.enqueue(
        PendingMutation(
          method: ApiMethod.put,
          path: '${entity.endpoint}/-7',
          entityName: entity.name,
          recordKey: '-7',
          body: const {'nombre': 'Ana Maria'},
          createdAt: DateTime.utc(2026, 9, 20, 0, 1),
        ),
      );

      await store.remapIdentifier(
        entity: entity,
        oldIdentifier: -7,
        newIdentifier: 42,
      );

      expect(await store.readById(entity, -7), isNull);
      expect(await store.readById(entity, 42), {'id': 42, 'nombre': 'Ana'});
      final pending = await store.pendingMutations();
      expect(pending.map((item) => item.id), [1, 2]);
      expect(pending.last.recordKey, '42');
      expect(pending.last.path, '${entity.endpoint}/42');
    },
  );
}
