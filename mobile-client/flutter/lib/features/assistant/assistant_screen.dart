import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../ai/intents/intent_service.dart';
import '../../ai/intents/structured_intent.dart';
import '../../assistant/assistant_panel.dart';
import '../../assistant/local_model_setup_card.dart';
import '../../ai/llm/local_model_manager.dart';
import '../../core/dependencies/app_dependencies.dart';
import '../../domain/loading/domain_model_loader.dart';
import '../../domain/model/domain_model.dart';
import '../../offline/offline_data_coordinator.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  DomainModelLoader? _domainModelLoader;
  late Future<DomainModel> _domainModel;
  IntentExecutionResult? _lastResult;
  String? _lastInstruction;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final loader = AppDependencies.of(context).domainModelLoader;
    if (_domainModelLoader == loader) return;
    _domainModelLoader = loader;
    _domainModel = loader.loadFromAsset('assets/domain-model.json');
    unawaited(AppDependencies.of(context).offlineCoordinator.initialize());
  }

  Future<void> _acceptInstruction(String instruction) async {
    final dependencies = AppDependencies.of(context);
    final domain = await _domainModel;
    final result = await IntentService(
      provider: dependencies.localAIProvider,
      apiClient: dependencies.apiClient,
      offlineCoordinator: dependencies.offlineCoordinator,
    ).execute(instruction, domain);
    if (!mounted) return;
    setState(() {
      _lastInstruction = instruction;
      _lastResult = result;
    });
  }

  Future<String> _listenOffline() async {
    final result = await AppDependencies.of(
      context,
    ).speechToTextProvider.listen();
    return result.transcript;
  }

  @override
  Widget build(BuildContext context) {
    final dependencies = AppDependencies.of(context);
    final localAIProvider = dependencies.localAIProvider;
    return Scaffold(
      appBar: AppBar(title: const Text('Asistente')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Puedes escribir o dictar una instrucción. La voz y el modelo de IA pueden ejecutarse dentro del dispositivo, incluso sin Internet.',
            ),
            const SizedBox(height: 16),
            if (localAIProvider is ManagedLocalAIProvider) ...[
              LocalModelSetupCard(provider: localAIProvider),
              const SizedBox(height: 16),
            ],
            _OfflineStatusCard(
              coordinator: dependencies.offlineCoordinator,
              domainModel: _domainModel,
            ),
            const SizedBox(height: 16),
            AssistantPanel(
              onSubmit: _acceptInstruction,
              onVoiceInput: _listenOffline,
            ),
            if (_lastInstruction != null && _lastResult != null) ...[
              const SizedBox(height: 16),
              _ExecutionResultCard(
                instruction: _lastInstruction!,
                result: _lastResult!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExecutionResultCard extends StatelessWidget {
  const _ExecutionResultCard({required this.instruction, required this.result});

  final String instruction;
  final IntentExecutionResult result;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    result.queuedForSync
                        ? Icons.cloud_upload_outlined
                        : Icons.check_circle_outline,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _title(result.intent.operation),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Instrucción: $instruction'),
              Text(_metadata()),
              const SizedBox(height: 10),
              SelectableText(_formatData(result.data)),
            ],
          ),
        ),
      ),
    );
  }

  String _title(IntentOperation operation) => switch (operation) {
    _ when result.queuedForSync => 'Cambio guardado sin conexión',
    IntentOperation.createEntity => 'Registro creado',
    IntentOperation.getEntity => 'Registro encontrado',
    IntentOperation.listEntities => 'Consulta completada',
    IntentOperation.updateEntity => 'Registro actualizado',
    IntentOperation.deleteEntity => 'Registro eliminado',
    IntentOperation.searchEntity => 'Búsqueda completada',
  };

  String _metadata() {
    final origin = result.fromLocalStorage ? 'datos locales' : 'servidor';
    final pending = result.pendingChanges == 0
        ? ''
        : ' · ${result.pendingChanges} pendiente${result.pendingChanges == 1 ? '' : 's'}';
    return 'Entidad: ${result.intent.entity} · $origin · HTTP ${result.statusCode}$pending';
  }

  String _formatData(Object? data) {
    if (data == null) return 'Operación completada correctamente.';
    if (data is List<Object?> && data.isEmpty) {
      return 'No se encontraron resultados.';
    }
    if (data is String) return data;
    try {
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data.toString();
    }
  }
}

class _OfflineStatusCard extends StatelessWidget {
  const _OfflineStatusCard({
    required this.coordinator,
    required this.domainModel,
  });

  final OfflineDataCoordinator coordinator;
  final Future<DomainModel> domainModel;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: coordinator,
      builder: (context, _) {
        final status = coordinator.connectionState;
        final pending = coordinator.pendingCount;
        return Card(
          child: ListTile(
            leading: Icon(_icon(status), color: _color(context, status)),
            title: Text(_titleFor(status)),
            subtitle: Text(
              _subtitle(status, pending, coordinator.lastSyncError),
            ),
            trailing: pending > 0
                ? IconButton(
                    onPressed: status == DataConnectionState.synchronizing
                        ? null
                        : () async {
                            final domain = await domainModel;
                            await coordinator.synchronize(domain);
                          },
                    tooltip: 'Sincronizar cambios pendientes',
                    icon: status == DataConnectionState.synchronizing
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync),
                  )
                : null,
          ),
        );
      },
    );
  }

  String _titleFor(DataConnectionState status) => switch (status) {
    DataConnectionState.unknown => 'Conexión sin comprobar',
    DataConnectionState.online => 'Conectado al servidor',
    DataConnectionState.offline => 'Modo sin conexión',
    DataConnectionState.synchronizing => 'Sincronizando…',
  };

  String _subtitle(
    DataConnectionState status,
    int pending,
    String? lastSyncError,
  ) {
    final base = switch (status) {
      DataConnectionState.unknown =>
        'La aplicación usará el servidor si está disponible.',
      DataConnectionState.online =>
        'Los datos se guardan también en el teléfono.',
      DataConnectionState.offline =>
        'Trabajando con la copia guardada en el teléfono.',
      DataConnectionState.synchronizing =>
        'Enviando cambios en el orden en que se hicieron.',
    };
    final pendingText = pending == 0
        ? ''
        : ' $pending cambio${pending == 1 ? '' : 's'} pendiente${pending == 1 ? '' : 's'}.';
    final errorText = lastSyncError == null ? '' : ' $lastSyncError';
    return '$base$pendingText$errorText';
  }

  IconData _icon(DataConnectionState status) => switch (status) {
    DataConnectionState.unknown => Icons.cloud_queue_outlined,
    DataConnectionState.online => Icons.cloud_done_outlined,
    DataConnectionState.offline => Icons.cloud_off_outlined,
    DataConnectionState.synchronizing => Icons.sync,
  };

  Color _color(BuildContext context, DataConnectionState status) =>
      switch (status) {
        DataConnectionState.offline => Theme.of(context).colorScheme.tertiary,
        DataConnectionState.online => Colors.green,
        _ => Theme.of(context).colorScheme.primary,
      };
}
