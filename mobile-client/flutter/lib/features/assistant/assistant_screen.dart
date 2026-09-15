import 'package:flutter/material.dart';

import '../../assistant/assistant_panel.dart';
import '../../assistant/local_model_setup_card.dart';
import '../../ai/llm/local_model_manager.dart';
import '../../core/dependencies/app_dependencies.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  String? _lastInstruction;

  Future<void> _acceptInstruction(String instruction) async {
    setState(() => _lastInstruction = instruction);
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
            if (_lastInstruction != null) ...[
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.check_circle_outline),
                    title: const Text('Instrucción recibida'),
                    subtitle: Text(_lastInstruction!),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
