import 'package:flutter/material.dart';

import '../ai/llm/local_model_manager.dart';
import '../core/errors/app_exception.dart';

class LocalModelSetupCard extends StatefulWidget {
  const LocalModelSetupCard({required this.provider, super.key});

  final ManagedLocalAIProvider provider;

  @override
  State<LocalModelSetupCard> createState() => _LocalModelSetupCardState();
}

class _LocalModelSetupCardState extends State<LocalModelSetupCard> {
  LocalModelStatus? _status;
  String? _error;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant LocalModelSetupCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.provider != widget.provider) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final status = await widget.provider.getModelStatus();
      if (!mounted) return;
      setState(() {
        _status = status;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = userMessageFor(error));
    }
  }

  Future<void> _import() => _run(() async {
    final status = await widget.provider.importModel();
    if (mounted) setState(() => _status = status);
  });

  Future<void> _load() => _run(() async {
    await widget.provider.loadModel();
    final status = await widget.provider.getModelStatus();
    if (mounted) setState(() => _status = status);
  });

  Future<void> _run(Future<void> Function() operation) async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await operation();
    } catch (error) {
      if (mounted) setState(() => _error = userMessageFor(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  status?.loaded == true ? Icons.memory : Icons.memory_outlined,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Modelo de IA local',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (_working)
                  const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(_description(status)),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            if (status?.loaded != true)
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _working ? null : _import,
                    icon: const Icon(Icons.file_open_outlined),
                    label: Text(
                      status?.installed == true
                          ? 'Cambiar modelo'
                          : 'Importar .litertlm',
                    ),
                  ),
                  if (status?.installed == true)
                    FilledButton.icon(
                      onPressed: _working ? null : _load,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Cargar modelo'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _description(LocalModelStatus? status) {
    if (status == null) return 'Comprobando el almacenamiento local…';
    if (status.loaded) {
      return '${status.fileName ?? 'Modelo'} cargado y listo sin Internet.';
    }
    if (status.installed) {
      final size = status.sizeBytes == null
          ? ''
          : ' (${(status.sizeBytes! / (1024 * 1024)).toStringAsFixed(0)} MB)';
      return '${status.fileName ?? 'Modelo local'}$size está instalado.';
    }
    return 'Selecciona desde el teléfono un modelo compatible con LiteRT-LM.';
  }
}
