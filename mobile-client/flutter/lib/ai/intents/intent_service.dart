import '../../core/api/api_client.dart';
import '../../core/api/api_response.dart';
import '../../domain/model/domain_model.dart';
import '../../offline/offline_data_coordinator.dart';
import '../context/domain_context_builder.dart';
import '../llm/local_ai_provider.dart';
import 'api_operation_resolver.dart';
import 'intent_exception.dart';
import 'structured_intent.dart';
import 'structured_intent_parser.dart';

class IntentExecutionResult {
  const IntentExecutionResult({
    required this.intent,
    required this.operation,
    required this.statusCode,
    this.fromLocalStorage = false,
    this.queuedForSync = false,
    this.pendingChanges = 0,
    this.data,
  });

  final StructuredIntent intent;
  final ResolvedApiOperation operation;
  final int statusCode;
  final bool fromLocalStorage;
  final bool queuedForSync;
  final int pendingChanges;
  final Object? data;
}

class IntentService {
  const IntentService({
    required this.provider,
    required this.apiClient,
    this.offlineCoordinator,
    this.parser = const StructuredIntentParser(),
    this.resolver = const ApiOperationResolver(),
    this.contextBuilder = const DomainContextBuilder(),
  });

  final LocalAIProvider provider;
  final ApiClient apiClient;
  final OfflineDataCoordinator? offlineCoordinator;
  final StructuredIntentParser parser;
  final ApiOperationResolver resolver;
  final DomainContextBuilder contextBuilder;

  Future<IntentExecutionResult> execute(
    String instruction,
    DomainModel domain,
  ) async {
    final normalizedInstruction = instruction.trim();
    if (normalizedInstruction.isEmpty) {
      throw const IntentFormatException('Escribe una instrucción.');
    }

    String response;
    try {
      if (!provider.isModelLoaded) await provider.loadModel();
      response = await provider.generateStructuredIntent(
        instruction: normalizedInstruction,
        domainContext: contextBuilder.build(domain),
      );
    } on IntentFormatException {
      rethrow;
    } on LocalAIException {
      rethrow;
    } catch (_) {
      throw const LocalAIException(
        'La IA local no pudo interpretar la instrucción.',
      );
    }

    final intent = parser.parse(response);
    final operation = resolver.resolve(intent, domain);
    final entity = domain.entityNamed(intent.entity)!;
    final offlineExecution = await offlineCoordinator?.execute(
      operation,
      entity,
      domain,
    );
    final apiResponse =
        offlineExecution?.response ?? await _executeOperation(operation);
    final data = operation.requiresLocalFiltering
        ? _filterLocally(apiResponse.data, operation.localFilters)
        : apiResponse.data;
    return IntentExecutionResult(
      intent: intent,
      operation: operation,
      statusCode: apiResponse.statusCode,
      fromLocalStorage: offlineExecution?.fromLocalStorage ?? false,
      queuedForSync: offlineExecution?.queued ?? false,
      pendingChanges: offlineCoordinator?.pendingCount ?? 0,
      data: data,
    );
  }

  Future<ApiResponse> _executeOperation(ResolvedApiOperation operation) {
    return switch (operation.method) {
      ApiMethod.get => apiClient.get(operation.path),
      ApiMethod.post => apiClient.post(operation.path, body: operation.body),
      ApiMethod.put => apiClient.put(operation.path, body: operation.body),
      ApiMethod.delete => apiClient.delete(operation.path),
    };
  }

  Object? _filterLocally(Object? data, Map<String, Object?> filters) {
    if (data is! List<Object?>) return data;
    return data
        .where((item) {
          if (item is! Map<String, Object?>) return false;
          return filters.entries.every(
            (filter) => _matchesFilter(item[filter.key], filter.value),
          );
        })
        .toList(growable: false);
  }

  bool _matchesFilter(Object? actual, Object? expected) {
    if (actual is String && expected is String) {
      return actual.toLowerCase().contains(expected.toLowerCase());
    }
    if (actual is List<Object?>) return actual.contains(expected);
    return actual == expected;
  }
}
