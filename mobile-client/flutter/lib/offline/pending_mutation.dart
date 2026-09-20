import '../ai/intents/api_operation_resolver.dart';

class PendingMutation {
  const PendingMutation({
    this.id,
    required this.method,
    required this.path,
    required this.entityName,
    required this.recordKey,
    required this.body,
    required this.createdAt,
  });

  final int? id;
  final ApiMethod method;
  final String path;
  final String entityName;
  final String recordKey;
  final Map<String, Object?>? body;
  final DateTime createdAt;

  PendingMutation copyWith({int? id, String? path, String? recordKey}) {
    return PendingMutation(
      id: id ?? this.id,
      method: method,
      path: path ?? this.path,
      entityName: entityName,
      recordKey: recordKey ?? this.recordKey,
      body: body,
      createdAt: createdAt,
    );
  }
}
