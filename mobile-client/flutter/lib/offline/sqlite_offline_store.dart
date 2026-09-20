import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../ai/intents/api_operation_resolver.dart';
import '../domain/model/domain_model.dart';
import 'offline_store.dart';
import 'pending_mutation.dart';

class SqliteOfflineStore implements OfflineStore {
  Database? _database;

  Future<Database> get _db async {
    await initialize();
    return _database!;
  }

  @override
  Future<void> initialize() async {
    if (_database != null) return;
    final databasesPath = await getDatabasesPath();
    _database = await openDatabase(
      path.join(databasesPath, 'software1_offline.db'),
      version: 1,
      onCreate: (database, _) async {
        await database.execute('''
          CREATE TABLE offline_records (
            entity_name TEXT NOT NULL,
            record_key TEXT NOT NULL,
            payload TEXT NOT NULL,
            dirty INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (entity_name, record_key)
          )
        ''');
        await database.execute('''
          CREATE TABLE pending_mutations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            method TEXT NOT NULL,
            path TEXT NOT NULL,
            entity_name TEXT NOT NULL,
            record_key TEXT NOT NULL,
            body TEXT,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  @override
  Future<List<Map<String, Object?>>> readAll(DomainEntity entity) async {
    final rows = await (await _db).query(
      'offline_records',
      columns: ['payload'],
      where: 'entity_name = ?',
      whereArgs: [entity.name],
      orderBy: 'record_key ASC',
    );
    return rows.map((row) => _decodeMap(row['payload']! as String)).toList();
  }

  @override
  Future<Map<String, Object?>?> readById(
    DomainEntity entity,
    Object identifier,
  ) async {
    final rows = await (await _db).query(
      'offline_records',
      columns: ['payload'],
      where: 'entity_name = ? AND record_key = ?',
      whereArgs: [entity.name, identifier.toString()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _decodeMap(rows.single['payload']! as String);
  }

  @override
  Future<void> replaceRemoteCollection(
    DomainEntity entity,
    List<Map<String, Object?>> records,
  ) async {
    final database = await _db;
    await database.transaction((transaction) async {
      await transaction.delete(
        'offline_records',
        where: 'entity_name = ? AND dirty = 0',
        whereArgs: [entity.name],
      );
      for (final record in records) {
        final identifier = record[entity.idField];
        if (identifier == null) continue;
        await transaction.insert('offline_records', {
          'entity_name': entity.name,
          'record_key': identifier.toString(),
          'payload': jsonEncode(record),
          'dirty': 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  @override
  Future<void> upsertRecord(
    DomainEntity entity,
    Map<String, Object?> record, {
    required bool dirty,
  }) async {
    final identifier = record[entity.idField];
    if (identifier == null) return;
    await (await _db).insert('offline_records', {
      'entity_name': entity.name,
      'record_key': identifier.toString(),
      'payload': jsonEncode(record),
      'dirty': dirty ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> removeRecord(DomainEntity entity, Object identifier) async {
    await (await _db).delete(
      'offline_records',
      where: 'entity_name = ? AND record_key = ?',
      whereArgs: [entity.name, identifier.toString()],
    );
  }

  @override
  Future<void> enqueue(PendingMutation mutation) async {
    await (await _db).insert('pending_mutations', {
      'method': mutation.method.name,
      'path': mutation.path,
      'entity_name': mutation.entityName,
      'record_key': mutation.recordKey,
      'body': mutation.body == null ? null : jsonEncode(mutation.body),
      'created_at': mutation.createdAt.toUtc().toIso8601String(),
    });
  }

  @override
  Future<List<PendingMutation>> pendingMutations() async {
    final rows = await (await _db).query(
      'pending_mutations',
      orderBy: 'id ASC',
    );
    return rows
        .map((row) {
          final body = row['body'] as String?;
          return PendingMutation(
            id: row['id']! as int,
            method: ApiMethod.values.byName(row['method']! as String),
            path: row['path']! as String,
            entityName: row['entity_name']! as String,
            recordKey: row['record_key']! as String,
            body: body == null ? null : _decodeMap(body),
            createdAt: DateTime.parse(row['created_at']! as String),
          );
        })
        .toList(growable: false);
  }

  @override
  Future<int> pendingCount() async {
    final rows = await (await _db).rawQuery(
      'SELECT COUNT(*) AS count FROM pending_mutations',
    );
    return (rows.single['count'] as int?) ?? 0;
  }

  @override
  Future<void> removePending(int id) async {
    await (await _db).delete(
      'pending_mutations',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> remapIdentifier({
    required DomainEntity entity,
    required Object oldIdentifier,
    required Object newIdentifier,
  }) async {
    final database = await _db;
    final oldKey = oldIdentifier.toString();
    final newKey = newIdentifier.toString();
    await database.transaction((transaction) async {
      final records = await transaction.query(
        'offline_records',
        columns: ['payload', 'dirty'],
        where: 'entity_name = ? AND record_key = ?',
        whereArgs: [entity.name, oldKey],
        limit: 1,
      );
      if (records.isNotEmpty) {
        final payload = _decodeMap(records.single['payload']! as String)
          ..[entity.idField] = newIdentifier;
        await transaction.delete(
          'offline_records',
          where: 'entity_name = ? AND record_key = ?',
          whereArgs: [entity.name, oldKey],
        );
        await transaction.insert('offline_records', {
          'entity_name': entity.name,
          'record_key': newKey,
          'payload': jsonEncode(payload),
          'dirty': records.single['dirty'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await transaction.rawUpdate(
        '''
        UPDATE pending_mutations
        SET record_key = ?, path = ?
        WHERE entity_name = ? AND record_key = ?
        ''',
        [
          newKey,
          '${entity.endpoint}/${Uri.encodeComponent(newKey)}',
          entity.name,
          oldKey,
        ],
      );
    });
  }

  Map<String, Object?> _decodeMap(String encoded) =>
      Map<String, Object?>.from(jsonDecode(encoded) as Map);

  @override
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
