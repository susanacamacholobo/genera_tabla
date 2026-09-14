import 'package:flutter/material.dart';

import '../../assistant/assistant_panel.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Asistente')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Puedes escribir o dictar una instrucción. La voz se reconoce dentro del dispositivo; la conexión con el modelo local se completará en las fases siguientes.',
            ),
            const SizedBox(height: 16),
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
