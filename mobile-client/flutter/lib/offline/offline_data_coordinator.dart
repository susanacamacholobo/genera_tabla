import 'package:flutter/foundation.dart';

import '../ai/intents/api_operation_resolver.dart';
import '../core/api/api_client.dart';
import '../core/api/api_response.dart';
import '../core/errors/app_exception.dart';
import '../domain/model/domain_model.dart';
import 'offline_store.dart';
import 'pending_mutation.dart';

enum DataConnectionState { unknown, online, offline, synchronizing }

class OfflineExecution {
  const OfflineExecution({
    required this.response,
    required this.fromLocalStorage,
    required this.queued,
  });

  final ApiResponse response;
  final bool fromLocalStorage;
  final bool queued;
}

class OfflineDataCoordinator extends ChangeNotifier {
  OfflineDataCoordinator({required this.apiClient, required this.store});

  final ApiClient apiClient;
  final OfflineStore store;

  DataConnectionState _connectionState = DataConnectionState.unknown;
  int _pendingCount = 0;
  String? _lastSyncError;
  Future<void>? _initialization;

  DataConnectionState get connectionState => _connectionState;
  int get pendingCount => _pendingCount;
  String? get lastSyncError => _lastSyncError;

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    await store.initialize();
    _pendingCount = await store.pendingCount();
    notifyListeners();
  }

  Future<OfflineExecution> execute(
    ResolvedApiOperation operation,
    DomainEntity entity,
    DomainModel domain,
  ) async {
    await initialize();
    if (_pendingCount > 0) {
      final synchronized = await synchronize(domain);
      if (!synchronized && _connectionState == DataConnectionState.offline) {
        return _executeLocally(operation, entity);
      }
    }

    try {
      final response = await _send(operation);
      await _cacheRemoteResult(operation, entity, response.data);
      _setConnectionState(DataConnectionState.online);
      return OfflineExecution(
        response: response,
        fromLocalStorage: false,
        queued: false,
      );
    } on NetworkException {
      _setConnectionState(DataConnectionState.offline);
      return _executeLocally(operation, entity);
    }
  }

  Future<bool> synchronize(DomainModel domain) async {
    await initialize();
    if (_connectionState == DataConnectionState.synchronizing) return false;
    _setConnectionState(DataConnectionState.synchronizing);
    _lastSyncError = null;

    try {
      while (true) {
        final mutations = await store.pendingMutations();
        if (mutations.isEmpty) break;
        final mutation = mutations.first;
        final entity = domain.entityNamed(mutation.entityName);
        if (entity == null) {
          throw AppException(
            'No se puede sincronizar ${mutation.entityName}: ya no existe en el dominio.',
          );
        }
        final response = await _sendMutation(mutation);
        await _applySynchronizedMutation(mutation, entity, response.data);
        await store.removePending(mutation.id!);
      }
      _pendingCount = await store.pendingCount();
      _setConnectionState(DataConnectionState.online);
      return true;
    } on NetworkException catch (error) {
      _lastSyncError = error.userMessage;
      _pendingCount = await store.pendingCount();
      _setConnectionState(DataConnectionState.offline);
      return false;
    } on AppException catch (error) {
      _lastSyncError = error.userMessage;
      _pendingCount = await store.pendingCount();
      _setConnectionState(DataConnectionState.online);
      return false;
    }
  }

  Future<OfflineExecution> _executeLocally(
    ResolvedApiOperation operation,
    DomainEntity entity,
  ) async {
    switch (operation.method) {
      case ApiMethod.get:
        final data = _isCollectionPath(operation.path, entity)
            ? await store.readAll(entity)
            : await store.readById(entity, _identifierFrom(operation, entity));
        return OfflineExecution(
          response: ApiResponse(statusCode: 200, headers: const {}, data: data),
          fromLocalStorage: true,
          queued: false,
        );
      case ApiMethod.post:
        final identifier = _temporaryIdentifier(entity);
        final record = <String, Object?>{
          ...?operation.body,
          entity.idField: identifier,
        };
        await store.upsertRecord(entity, record, dirty: true);
        await _enqueue(operation, entity, identifier);
        return _queuedExecution(record);
      case ApiMethod.put:
        final identifier = _identifierFrom(operation, entity);
        final existing = await store.readById(entity, identifier);
        final record = <String, Object?>{
          ...?existing,
          ...?operation.body,
          entity.idField: identifier,
        };
        await store.upsertRecord(entity, record, dirty: true);
        await _enqueue(operation, entity, identifier);
        return _queuedExecution(record);
      case ApiMethod.delete:
        final identifier = _identifierFrom(operation, entity);
        await store.removeRecord(entity, identifier);
        await _enqueue(operation, entity, identifier);
        return _queuedExecution(null);
    }
  }

  Future<void> _enqueue(
    ResolvedApiOperation operation,
    DomainEntity entity,
    Object identifier,
  ) async {
    await store.enqueue(
      PendingMutation(
        method: operation.method,
        path: operation.path,
        entityName: entity.name,
        recordKey: identifier.toString(),
        body: operation.body,
        createdAt: DateTime.now().toUtc(),
      ),
    );
    _pendingCount = await store.pendingCount();
    notifyListeners();
  }

  OfflineExecution _queuedExecution(Object? data) => OfflineExecution(
    response: ApiResponse(statusCode: 202, headers: const {}, data: data),
    fromLocalStorage: true,
    queued: true,
  );

  Future<ApiResponse> _send(ResolvedApiOperation operation) {
    return switch (operation.method) {
      ApiMethod.get => apiClient.get(operation.path),
      ApiMethod.post => apiClient.post(operation.path, body: operation.body),
      ApiMethod.put => apiClient.put(operation.path, body: operation.body),
      ApiMethod.delete => apiClient.delete(operation.path),
    };
  }

  Future<ApiResponse> _sendMutation(PendingMutation mutation) {
    return switch (mutation.method) {
      ApiMethod.get => apiClient.get(mutation.path),
      ApiMethod.post => apiClient.post(mutation.path, body: mutation.body),
      ApiMethod.put => apiClient.put(mutation.path, body: mutation.body),
      ApiMethod.delete => apiClient.delete(mutation.path),
    };
  }

  Future<void> _cacheRemoteResult(
    ResolvedApiOperation operation,
    DomainEntity entity,
    Object? data,
  ) async {
    if (operation.method == ApiMethod.delete) {
      await store.removeRecord(entity, _identifierFrom(operation, entity));
      return;
    }
    if (data is List) {
      final records = data
          .whereType<Map>()
          .map((item) => Map<String, Object?>.from(item))
          .toList(growable: false);
      await store.replaceRemoteCollection(entity, records);
    } else if (data is Map) {
      await store.upsertRecord(
        entity,
        Map<String, Object?>.from(data),
        dirty: false,
      );
    }
  }

  Future<void> _applySynchronizedMutation(
    PendingMutation mutation,
    DomainEntity entity,
    Object? data,
  ) async {
    if (mutation.method == ApiMethod.delete) {
      await store.removeRecord(entity, mutation.recordKey);
      return;
    }
    if (data is Map) {
      final record = Map<String, Object?>.from(data);
      final remoteIdentifier = record[entity.idField];
      if (mutation.method == ApiMethod.post && remoteIdentifier != null) {
        await store.remapIdentifier(
          entity: entity,
          oldIdentifier: mutation.recordKey,
          newIdentifier: remoteIdentifier,
        );
      }
      await store.upsertRecord(entity, record, dirty: false);
      return;
    }
    if (mutation.method == ApiMethod.post) {
      throw const ResponseDecodingException(
        'El servidor no devolvio el registro creado; la sincronizacion se conservara pendiente.',
      );
    }
    final identifier = _coerceIdentifier(entity, mutation.recordKey);
    final record = <String, Object?>{
      ...?mutation.body,
      entity.idField: identifier,
    };
    await store.upsertRecord(entity, record, dirty: false);
  }

  bool _isCollectionPath(String path, DomainEntity entity) =>
      path.replaceAll(RegExp(r'/+$'), '') ==
      entity.endpoint.replaceAll(RegExp(r'/+$'), '');

  Object _identifierFrom(ResolvedApiOperation operation, DomainEntity entity) {
    final segment = Uri.decodeComponent(operation.path.split('/').last);
    return _coerceIdentifier(entity, segment);
  }

  Object _temporaryIdentifier(DomainEntity entity) {
    final idType = entity.fieldNamed(entity.idField)?.type;
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    if (idType == DomainFieldType.integer || idType == DomainFieldType.long) {
      return -timestamp;
    }
    return 'local-$timestamp';
  }

  Object _coerceIdentifier(DomainEntity entity, String value) {
    final idType = entity.fieldNamed(entity.idField)?.type;
    if (idType == DomainFieldType.integer || idType == DomainFieldType.long) {
      return int.tryParse(value) ?? value;
    }
    return value;
  }

  void _setConnectionState(DataConnectionState value) {
    _connectionState = value;
    notifyListeners();
  }

  @override
  void dispose() {
    store.close();
    super.dispose();
  }
}
