import '../domain/model/domain_model.dart';
import 'offline_store.dart';
import 'pending_mutation.dart';

class MemoryOfflineStore implements OfflineStore {
  final Map<String, Map<String, _MemoryRecord>> _records = {};
  final List<PendingMutation> _pending = [];
  var _nextPendingId = 1;

  @override
  Future<void> initialize() async {}

  @override
  Future<List<Map<String, Object?>>> readAll(DomainEntity entity) async {
    return (_records[entity.name]?.values ?? const <_MemoryRecord>[])
        .map((record) => Map<String, Object?>.from(record.data))
        .toList(growable: false);
  }

  @override
  Future<Map<String, Object?>?> readById(
    DomainEntity entity,
    Object identifier,
  ) async {
    final record = _records[entity.name]?[identifier.toString()];
    return record == null ? null : Map<String, Object?>.from(record.data);
  }

  @override
  Future<void> replaceRemoteCollection(
    DomainEntity entity,
    List<Map<String, Object?>> records,
  ) async {
    final bucket = _records.putIfAbsent(entity.name, () => {});
    bucket.removeWhere((_, record) => !record.dirty);
    for (final record in records) {
      final identifier = record[entity.idField];
      if (identifier != null) {
        bucket[identifier.toString()] = _MemoryRecord(record, dirty: false);
      }
    }
  }

  @override
  Future<void> upsertRecord(
    DomainEntity entity,
    Map<String, Object?> record, {
    required bool dirty,
  }) async {
    final identifier = record[entity.idField];
    if (identifier == null) return;
    _records.putIfAbsent(entity.name, () => {})[identifier.toString()] =
        _MemoryRecord(record, dirty: dirty);
  }

  @override
  Future<void> removeRecord(DomainEntity entity, Object identifier) async {
    _records[entity.name]?.remove(identifier.toString());
  }

  @override
  Future<void> enqueue(PendingMutation mutation) async {
    _pending.add(mutation.copyWith(id: _nextPendingId++));
  }

  @override
  Future<List<PendingMutation>> pendingMutations() async =>
      List.unmodifiable(_pending);

  @override
  Future<int> pendingCount() async => _pending.length;

  @override
  Future<void> removePending(int id) async {
    _pending.removeWhere((mutation) => mutation.id == id);
  }

  @override
  Future<void> remapIdentifier({
    required DomainEntity entity,
    required Object oldIdentifier,
    required Object newIdentifier,
  }) async {
    final bucket = _records[entity.name];
    final oldKey = oldIdentifier.toString();
    final newKey = newIdentifier.toString();
    final record = bucket?.remove(oldKey);
    if (record != null) {
      final data = Map<String, Object?>.from(record.data)
        ..[entity.idField] = newIdentifier;
      bucket![newKey] = _MemoryRecord(data, dirty: record.dirty);
    }
    for (var index = 0; index < _pending.length; index++) {
      final mutation = _pending[index];
      if (mutation.entityName != entity.name || mutation.recordKey != oldKey) {
        continue;
      }
      _pending[index] = mutation.copyWith(
        recordKey: newKey,
        path: '${entity.endpoint}/${Uri.encodeComponent(newKey)}',
      );
    }
  }

  @override
  Future<void> close() async {}
}

class _MemoryRecord {
  _MemoryRecord(Map<String, Object?> data, {required this.dirty})
    : data = Map<String, Object?>.from(data);

  final Map<String, Object?> data;
  final bool dirty;
}
