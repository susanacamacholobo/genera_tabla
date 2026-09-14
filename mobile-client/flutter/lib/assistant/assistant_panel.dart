import 'package:flutter/material.dart';

import '../core/errors/app_exception.dart';

typedef AssistantSubmit = Future<void> Function(String instruction);

class AssistantPanel extends StatefulWidget {
  const AssistantPanel({
    required this.onSubmit,
    this.onVoicePressed,
    this.hintText = 'Escribe una instrucción',
    super.key,
  });

  final AssistantSubmit onSubmit;
  final VoidCallback? onVoicePressed;
  final String hintText;

  @override
  State<AssistantPanel> createState() => _AssistantPanelState();
}

class _AssistantPanelState extends State<AssistantPanel> {
  final _controller = TextEditingController();
  String? _error;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final instruction = _controller.text.trim();
    if (instruction.isEmpty) {
      setState(() => _error = 'Escribe una instrucción.');
      return;
    }

    setState(() {
      _error = null;
      _isSubmitting = true;
    });
    try {
      await widget.onSubmit(instruction);
      if (!mounted) return;
      _controller.clear();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = userMessageFor(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '¿Qué deseas hacer?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              enabled: !_isSubmitting,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: widget.hintText,
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: _isSubmitting ? null : widget.onVoicePressed,
                  tooltip: widget.onVoicePressed == null
                      ? 'La voz local se integrará en la fase 19'
                      : 'Usar micrófono',
                  icon: const Icon(Icons.mic_none),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(_isSubmitting ? 'Procesando…' : 'Enviar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
