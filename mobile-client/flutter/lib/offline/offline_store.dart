import '../domain/model/domain_model.dart';
import 'pending_mutation.dart';

abstract class OfflineStore {
  Future<void> initialize();

  Future<List<Map<String, Object?>>> readAll(DomainEntity entity);

  Future<Map<String, Object?>?> readById(
    DomainEntity entity,
    Object identifier,
  );

  Future<void> replaceRemoteCollection(
    DomainEntity entity,
    List<Map<String, Object?>> records,
  );

  Future<void> upsertRecord(
    DomainEntity entity,
    Map<String, Object?> record, {
    required bool dirty,
  });

  Future<void> removeRecord(DomainEntity entity, Object identifier);

  Future<void> enqueue(PendingMutation mutation);

  Future<List<PendingMutation>> pendingMutations();

  Future<int> pendingCount();

  Future<void> removePending(int id);

  Future<void> remapIdentifier({
    required DomainEntity entity,
    required Object oldIdentifier,
    required Object newIdentifier,
  });

  Future<void> close();
}
