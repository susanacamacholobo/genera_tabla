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
  }

  Future<void> _acceptInstruction(String instruction) async {
    final dependencies = AppDependencies.of(context);
    final domain = await _domainModel;
    final result = await IntentService(
      provider: dependencies.localAIProvider,
      apiClient: dependencies.apiClient,
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
    final localAIProvider = AppDependencies.of(context).localAIProvider;
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
                  const Icon(Icons.check_circle_outline),
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
              Text(
                'Entidad: ${result.intent.entity} · HTTP ${result.statusCode}',
              ),
              const SizedBox(height: 10),
              SelectableText(_formatData(result.data)),
            ],
          ),
        ),
      ),
    );
  }

  String _title(IntentOperation operation) => switch (operation) {
    IntentOperation.createEntity => 'Registro creado',
    IntentOperation.getEntity => 'Registro encontrado',
    IntentOperation.listEntities => 'Consulta completada',
    IntentOperation.updateEntity => 'Registro actualizado',
    IntentOperation.deleteEntity => 'Registro eliminado',
    IntentOperation.searchEntity => 'Búsqueda completada',
  };

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
