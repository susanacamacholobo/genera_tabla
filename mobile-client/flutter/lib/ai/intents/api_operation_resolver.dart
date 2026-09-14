import '../../domain/model/domain_model.dart';
import 'intent_validator.dart';
import 'structured_intent.dart';

enum ApiMethod { get, post, put, delete }

class ResolvedApiOperation {
  ResolvedApiOperation({
    required this.method,
    required this.path,
    Map<String, Object?>? body,
    Map<String, Object?>? localFilters,
  }) : body = body == null ? null : Map.unmodifiable(body),
       localFilters = Map.unmodifiable(localFilters ?? const {});

  final ApiMethod method;
  final String path;
  final Map<String, Object?>? body;
  final Map<String, Object?> localFilters;

  bool get requiresLocalFiltering => localFilters.isNotEmpty;
}

class ApiOperationResolver {
  const ApiOperationResolver({this.validator = const IntentValidator()});

  final IntentValidator validator;

  ResolvedApiOperation resolve(StructuredIntent intent, DomainModel domain) {
    validator.assertValid(intent, domain);
    final entity = domain.entityNamed(intent.entity)!;
    final parameters = _canonicalParameters(intent, entity);

    return switch (intent.operation) {
      IntentOperation.createEntity => ResolvedApiOperation(
        method: ApiMethod.post,
        path: entity.endpoint,
        body: parameters,
      ),
      IntentOperation.getEntity => ResolvedApiOperation(
        method: ApiMethod.get,
        path: _itemPath(entity.endpoint, intent.identifier!),
      ),
      IntentOperation.listEntities => ResolvedApiOperation(
        method: ApiMethod.get,
        path: entity.endpoint,
      ),
      IntentOperation.updateEntity => ResolvedApiOperation(
        method: ApiMethod.put,
        path: _itemPath(entity.endpoint, intent.identifier!),
        body: parameters,
      ),
      IntentOperation.deleteEntity => ResolvedApiOperation(
        method: ApiMethod.delete,
        path: _itemPath(entity.endpoint, intent.identifier!),
      ),
      IntentOperation.searchEntity => ResolvedApiOperation(
        method: ApiMethod.get,
        path: entity.endpoint,
        localFilters: parameters,
      ),
    };
  }

  Map<String, Object?> _canonicalParameters(
    StructuredIntent intent,
    DomainEntity entity,
  ) {
    return {
      for (final entry in intent.parameters.entries)
        (entity.fieldNamed(entry.key)?.name ??
                entity.relationshipNamed(entry.key)!.apiField):
            entry.value,
    };
  }

  String _itemPath(String endpoint, Object identifier) =>
      '$endpoint/${Uri.encodeComponent(identifier.toString())}';
}
