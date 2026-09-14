import 'package:flutter/material.dart';

import '../../assistant/assistant_panel.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Asistente')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'El panel ya acepta instrucciones. La interpretación de intenciones y la IA dentro de Android se conectarán en las fases siguientes.',
            ),
            const SizedBox(height: 16),
            AssistantPanel(onSubmit: _acceptInstruction),
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
