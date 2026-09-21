import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/dependencies/app_dependencies.dart';
import '../../core/errors/app_exception.dart';

/// Pantalla de ejemplo escrita a mano; no se genera a partir del diagrama.
class BibliotecaScreen extends StatefulWidget {
  const BibliotecaScreen({super.key});

  @override
  State<BibliotecaScreen> createState() => _BibliotecaScreenState();
}

class _BibliotecaScreenState extends State<BibliotecaScreen> {
  final _nombre = TextEditingController();
  final _titulo = TextEditingController();
  final _isbn = TextEditingController();
  final _socioId = TextEditingController();
  final _libroId = TextEditingController();
  final _fechaInicio = TextEditingController();
  final _fechaDevolucion = TextEditingController();
  ApiClient? _api;
  int _tab = 0;
  int? _editingId;
  List<Map<String, dynamic>> _items = const [];
  String? _error;
  bool _busy = false;

  static const _paths = ['/api/socios', '/api/libros', '/api/prestamos'];

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
    for (final controller in [
      _nombre,
      _titulo,
      _isbn,
      _socioId,
      _libroId,
      _fechaInicio,
      _fechaDevolucion,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _clearForm() {
    _editingId = null;
    for (final controller in [
      _nombre,
      _titulo,
      _isbn,
      _socioId,
      _libroId,
      _fechaInicio,
      _fechaDevolucion,
    ]) {
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
      final response = await _api!.get(_paths[tab]);
      if (!mounted || tab != _tab) return;
      final rows = response.data as List<dynamic>;
      setState(() => _items = rows.cast<Map<String, dynamic>>());
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
      if (_tab == 0) {
        _nombre.text = row['nombre'] as String? ?? '';
      } else if (_tab == 1) {
        _titulo.text = row['titulo'] as String? ?? '';
        _isbn.text = row['isbn'] as String? ?? '';
      } else {
        _socioId.text = '${row['socioId'] ?? ''}';
        _libroId.text = '${row['libroId'] ?? ''}';
        _fechaInicio.text = row['fechaInicio'] as String? ?? '';
        _fechaDevolucion.text = row['fechaDevolucion'] as String? ?? '';
      }
    });
  }

  Object _body() {
    if (_tab == 0) {
      if (_nombre.text.trim().isEmpty) {
        throw const FormatException('Escribe el nombre del socio.');
      }
      return {'nombre': _nombre.text.trim()};
    }
    if (_tab == 1) {
      if (_titulo.text.trim().isEmpty || _isbn.text.trim().isEmpty) {
        throw const FormatException('Escribe título e ISBN.');
      }
      return {'titulo': _titulo.text.trim(), 'isbn': _isbn.text.trim()};
    }
    final socioId = int.tryParse(_socioId.text.trim());
    final libroId = int.tryParse(_libroId.text.trim());
    if (socioId == null || libroId == null) {
      throw const FormatException('Indica los IDs numéricos de socio y libro.');
    }
    final inicio = _fechaInicio.text.trim().isEmpty
        ? DateTime.now().toIso8601String()
        : _fechaInicio.text.trim();
    if (DateTime.tryParse(inicio) == null ||
        (_fechaDevolucion.text.trim().isNotEmpty &&
            DateTime.tryParse(_fechaDevolucion.text.trim()) == null)) {
      throw const FormatException(
        'Usa fechas ISO, por ejemplo 2026-09-21T10:00:00.',
      );
    }
    return {
      'socioId': socioId,
      'libroId': libroId,
      'fechaInicio': inicio,
      'fechaDevolucion': _fechaDevolucion.text.trim().isEmpty
          ? null
          : _fechaDevolucion.text.trim(),
    };
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final body = _body();
      if (_editingId == null) {
        await _api!.post(_paths[_tab], body: body);
      } else {
        await _api!.put('${_paths[_tab]}/$_editingId', body: body);
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
      await _api!.delete('${_paths[_tab]}/$id');
      if (!mounted) return;
      if (_editingId == id) _clearForm();
      await _reload();
    } catch (error) {
      if (mounted) setState(() => _error = userMessageFor(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  Widget _form() => switch (_tab) {
    0 => _field(_nombre, 'Nombre del socio'),
    1 => Column(children: [_field(_titulo, 'Título'), _field(_isbn, 'ISBN')]),
    _ => Column(
      children: [
        _field(_socioId, 'ID de socio', keyboardType: TextInputType.number),
        _field(_libroId, 'ID de libro', keyboardType: TextInputType.number),
        _field(_fechaInicio, 'Inicio (ISO; vacío = ahora)'),
        _field(_fechaDevolucion, 'Devolución (ISO; opcional)'),
      ],
    ),
  };

  String _title(Map<String, dynamic> row) => switch (_tab) {
    0 => '${row['id']} · ${row['nombre']}',
    1 => '${row['id']} · ${row['titulo']}',
    _ => '${row['id']} · Socio ${row['socioId']} / Libro ${row['libroId']}',
  };

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca'),
        bottom: TabBar(
          onTap: _selectTab,
          tabs: const [
            Tab(text: 'Socios'),
            Tab(text: 'Libros'),
            Tab(text: 'Préstamos'),
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
          _form(),
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
          ..._items.map(
            (row) => ListTile(
              title: Text(_title(row)),
              subtitle: _tab == 1 ? Text('${row['isbn']}') : null,
              onTap: () => _edit(row),
              trailing: IconButton(
                tooltip: 'Eliminar',
                icon: const Icon(Icons.delete_outline),
                onPressed: _busy ? null : () => _delete(row['id'] as int),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
