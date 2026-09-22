import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/dependencies/app_dependencies.dart';
import '../../core/errors/app_exception.dart';

enum DemoFieldKind { text, integer, decimal, date }

/// Campos elegidos a mano para cada demo; no se crean desde la metadata UML.
class DemoField {
  const DemoField(
    this.name,
    this.label, {
    this.kind = DemoFieldKind.text,
    this.optional = false,
  });

  final String name;
  final String label;
  final DemoFieldKind kind;
  final bool optional;
}

class DemoSection {
  const DemoSection(this.title, this.endpoint, this.titleField, this.fields);

  final String title;
  final String endpoint;
  final String titleField;
  final List<DemoField> fields;
}

class ManualCrudDemoScreen extends StatefulWidget {
  const ManualCrudDemoScreen({
    required this.title,
    required this.sections,
    super.key,
  });

  final String title;
  final List<DemoSection> sections;

  @override
  State<ManualCrudDemoScreen> createState() => _ManualCrudDemoScreenState();
}

class _ManualCrudDemoScreenState extends State<ManualCrudDemoScreen> {
  final Map<String, TextEditingController> _controllers = {};
  ApiClient? _api;
  int _tab = 0;
  int? _editingId;
  List<Map<String, dynamic>> _items = const [];
  String? _error;
  bool _busy = false;

  DemoSection get _section => widget.sections[_tab];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final api = AppDependencies.of(context).apiClient;
    if (_api == api) return;
    _api = api;
    _reload();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controller(String name) =>
      _controllers.putIfAbsent(name, TextEditingController.new);

  void _clearForm() {
    _editingId = null;
    for (final controller in _controllers.values) {
      controller.clear();
    }
  }

  Future<void> _reload() async {
    final tab = _tab;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final response = await _api!.get(widget.sections[tab].endpoint);
      if (!mounted || tab != _tab) return;
      setState(
        () => _items = (response.data as List<dynamic>)
            .cast<Map<String, dynamic>>(),
      );
    } catch (error) {
      if (mounted && tab == _tab) {
        setState(() => _error = userMessageFor(error));
      }
    } finally {
      if (mounted && tab == _tab) setState(() => _busy = false);
    }
  }

  void _selectTab(int tab) {
    setState(() {
      _tab = tab;
      _items = const [];
      _error = null;
      _clearForm();
    });
    _reload();
  }

  void _edit(Map<String, dynamic> row) {
    setState(() {
      _editingId = row['id'] as int;
      for (final field in _section.fields) {
        _controller(field.name).text = '${row[field.name] ?? ''}';
      }
    });
  }

  Map<String, Object?> _body() {
    final result = <String, Object?>{};
    for (final field in _section.fields) {
      var value = _controller(field.name).text.trim();
      if (value.isEmpty &&
          field.kind == DemoFieldKind.date &&
          !field.optional) {
        value = DateTime.now().toIso8601String().substring(0, 10);
      }
      if (value.isEmpty) {
        if (!field.optional) {
          throw FormatException('${field.label} es obligatorio.');
        }
        result[field.name] = null;
        continue;
      }
      switch (field.kind) {
        case DemoFieldKind.text:
          result[field.name] = value;
        case DemoFieldKind.integer:
          final parsed = int.tryParse(value);
          if (parsed == null || parsed <= 0) {
            throw FormatException('${field.label} debe ser un ID positivo.');
          }
          result[field.name] = parsed;
        case DemoFieldKind.decimal:
          final parsed = num.tryParse(value.replaceAll(',', '.'));
          if (parsed == null || parsed < 0 || !parsed.isFinite) {
            throw FormatException('${field.label} debe ser un número válido.');
          }
          result[field.name] = parsed;
        case DemoFieldKind.date:
          final parsed = DateTime.tryParse(value);
          if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
              parsed == null ||
              parsed.toIso8601String().substring(0, 10) != value) {
            throw FormatException('${field.label}: usa AAAA-MM-DD.');
          }
          result[field.name] = value;
      }
    }
    return result;
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final body = _body();
      if (_editingId == null) {
        await _api!.post(_section.endpoint, body: body);
      } else {
        await _api!.put('${_section.endpoint}/$_editingId', body: body);
      }
      if (!mounted) return;
      _clearForm();
      await _reload();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is FormatException
              ? error.message
              : userMessageFor(error),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar registro'),
        content: Text('¿Eliminar el registro $id?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api!.delete('${_section.endpoint}/$id');
      if (!mounted) return;
      if (_editingId == id) _clearForm();
      await _reload();
    } catch (error) {
      if (mounted) setState(() => _error = userMessageFor(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(DemoField field) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: _controller(field.name),
      keyboardType: switch (field.kind) {
        DemoFieldKind.integer => TextInputType.number,
        DemoFieldKind.decimal => const TextInputType.numberWithOptions(
          decimal: true,
        ),
        _ => TextInputType.text,
      },
      decoration: InputDecoration(
        labelText: field.label,
        hintText: field.kind == DemoFieldKind.date ? 'AAAA-MM-DD' : null,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: widget.sections.length,
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: TabBar(
          isScrollable: true,
          onTap: _selectTab,
          tabs: [
            for (final section in widget.sections) Tab(text: section.title),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _editingId == null ? 'Nuevo registro' : 'Editar #$_editingId',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          for (final field in _section.fields) _field(field),
          Row(
            children: [
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(_editingId == null ? 'Crear' : 'Guardar'),
              ),
              if (_editingId != null)
                TextButton(
                  onPressed: () => setState(_clearForm),
                  child: const Text('Cancelar'),
                ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const Divider(height: 32),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Registros',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                onPressed: _busy ? null : _reload,
                tooltip: 'Actualizar',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (_busy) const LinearProgressIndicator(),
          if (!_busy && _items.isEmpty) const Text('Sin registros.'),
          for (final row in _items)
            ListTile(
              title: Text('${row['id']} · ${row[_section.titleField]}'),
              onTap: () => _edit(row),
              trailing: IconButton(
                tooltip: 'Eliminar',
                icon: const Icon(Icons.delete_outline),
                onPressed: _busy ? null : () => _delete(row['id'] as int),
              ),
            ),
        ],
      ),
    ),
  );
}
