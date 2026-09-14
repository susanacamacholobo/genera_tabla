enum IntentOperation {
  createEntity('CREATE_ENTITY'),
  getEntity('GET_ENTITY'),
  listEntities('LIST_ENTITIES'),
  updateEntity('UPDATE_ENTITY'),
  deleteEntity('DELETE_ENTITY'),
  searchEntity('SEARCH_ENTITY');

  const IntentOperation(this.wireName);

  final String wireName;

  static IntentOperation? tryParse(String value) {
    final normalized = value.trim().toUpperCase();
    for (final operation in values) {
      if (operation.wireName == normalized) return operation;
    }
    return null;
  }
}

class StructuredIntent {
  StructuredIntent({
    required this.operation,
    required this.entity,
    this.identifier,
    Map<String, Object?> parameters = const {},
  }) : parameters = Map.unmodifiable(parameters);

  final IntentOperation operation;
  final String entity;
  final Object? identifier;
  final Map<String, Object?> parameters;
}
