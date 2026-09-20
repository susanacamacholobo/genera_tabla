import 'dart:convert';

import 'package:flutter/services.dart';

import 'local_ai_exception.dart';
import 'local_model_manager.dart';

class LiteRtLocalAIProvider implements ManagedLocalAIProvider {
  LiteRtLocalAIProvider({
    MethodChannel channel = const MethodChannel(channelName),
  }) : _channel = channel;

  static const channelName = 'bo.edu.software1/local_llm';

  final MethodChannel _channel;
  bool _isModelLoaded = false;
  bool _isDisposed = false;
  bool _isGenerating = false;

  @override
  bool get isModelLoaded => _isModelLoaded;

  @override
  Future<LocalModelStatus> getModelStatus() async {
    _assertNotDisposed();
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>('status');
      final status = _decodeStatus(raw);
      _isModelLoaded = status.loaded;
      return status;
    } on PlatformException catch (error) {
      throw _mapPlatformError(error);
    } on MissingPluginException {
      return const LocalModelStatus(installed: false, loaded: false);
    }
  }

  @override
  Future<LocalModelStatus> importModel() async {
    _assertNotDisposed();
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>(
        'importModel',
      );
      final status = _decodeStatus(raw);
      _isModelLoaded = status.loaded;
      return status;
    } on PlatformException catch (error) {
      throw _mapPlatformError(error);
    } on MissingPluginException {
      throw const LocalModelException(
        'La importación del modelo local sólo está disponible en Android.',
      );
    }
  }

  @override
  Future<void> loadModel() async {
    _assertNotDisposed();
    if (_isModelLoaded) return;
    try {
      await _channel.invokeMethod<void>('loadModel');
      _isModelLoaded = true;
    } on PlatformException catch (error) {
      _isModelLoaded = false;
      throw _mapPlatformError(error);
    } on MissingPluginException {
      throw const LocalModelException(
        'El modelo local sólo puede cargarse en Android.',
      );
    }
  }

  @override
  Future<String> generateStructuredIntent({
    required String instruction,
    required String domainContext,
  }) async {
    _assertNotDisposed();
    if (!_isModelLoaded) {
      throw const LocalModelException(
        'El modelo local todavía no está cargado.',
      );
    }
    if (_isGenerating) {
      throw const LocalAIException(
        'La IA local ya está procesando una instrucción.',
      );
    }
    final normalizedInstruction = instruction.trim();
    final normalizedContext = domainContext.trim();
    if (normalizedInstruction.isEmpty || normalizedContext.isEmpty) {
      throw const LocalAIException(
        'La instrucción y el contexto de dominio son obligatorios.',
      );
    }

    _isGenerating = true;
    try {
      final response = await _channel.invokeMethod<String>('generate', {
        'instruction': normalizedInstruction,
        'domainContext': normalizedContext,
      });
      if (response == null || response.trim().isEmpty) {
        throw const LocalAIException('La IA local no devolvió una intención.');
      }
      final decoded = _decodeJsonObject(response);
      return jsonEncode(decoded);
    } on PlatformException catch (error) {
      throw _mapPlatformError(error);
    } on MissingPluginException {
      throw const LocalAIException(
        'La IA local sólo está disponible en Android.',
      );
    } finally {
      _isGenerating = false;
    }
  }

  Map<String, Object?> _decodeJsonObject(String response) {
    try {
      final exact = jsonDecode(response);
      if (exact is Map<String, Object?>) return exact;
      throw const LocalAIException(
        'La IA local debe devolver un único objeto JSON.',
      );
    } on FormatException {
      // Some small models wrap an otherwise valid JSON object in prose or
      // Markdown despite constrained decoding. Extract that object below.
    }

    final candidate = _firstJsonObject(response);
    if (candidate != null) {
      try {
        final extracted = jsonDecode(candidate);
        if (extracted is Map<String, Object?>) return extracted;
      } on FormatException {
        // Report one stable, user-facing error below.
      }
    }

    throw const LocalAIException(
      'La IA local devolvió una intención que no es JSON válido.',
    );
  }

  String? _firstJsonObject(String source) {
    final start = source.indexOf('{');
    if (start < 0) return null;

    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var index = start; index < source.length; index++) {
      final character = source[index];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (character == r'\') {
          escaped = true;
        } else if (character == '"') {
          inString = false;
        }
        continue;
      }
      if (character == '"') {
        inString = true;
      } else if (character == '{') {
        depth++;
      } else if (character == '}') {
        depth--;
        if (depth == 0) return source.substring(start, index + 1);
      }
    }
    return null;
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    try {
      await _channel.invokeMethod<void>('dispose');
    } on PlatformException {
      // The host activity can already be gone during application shutdown.
    } on MissingPluginException {
      // Desktop and widget tests do not register the Android channel.
    } finally {
      _isDisposed = true;
      _isModelLoaded = false;
      _isGenerating = false;
    }
  }

  LocalModelStatus _decodeStatus(Map<String, Object?>? raw) {
    final installed = raw?['installed'];
    final loaded = raw?['loaded'];
    final fileName = raw?['fileName'];
    final sizeBytes = raw?['sizeBytes'];
    if (installed is! bool ||
        loaded is! bool ||
        (fileName != null && fileName is! String) ||
        (sizeBytes != null && sizeBytes is! int)) {
      throw const LocalModelException(
        'Android devolvió un estado de modelo inválido.',
      );
    }
    return LocalModelStatus(
      installed: installed,
      loaded: loaded,
      fileName: fileName as String?,
      sizeBytes: sizeBytes as int?,
    );
  }

  void _assertNotDisposed() {
    if (_isDisposed) {
      throw const LocalAIException('El proveedor de IA local ya fue cerrado.');
    }
  }

  LocalAIException _mapPlatformError(PlatformException error) {
    return switch (error.code) {
      'MODEL_NOT_INSTALLED' => const LocalModelException(
        'Importa un modelo .litertlm antes de usar la IA local.',
      ),
      'INVALID_MODEL_FILE' => const LocalModelException(
        'El archivo seleccionado no es un modelo .litertlm válido.',
      ),
      'IMPORT_CANCELLED' => const LocalModelException(
        'No se seleccionó ningún modelo local.',
      ),
      'NO_SPACE' => const LocalModelException(
        'No hay espacio suficiente para guardar el modelo local.',
      ),
      'MODEL_LOAD_FAILED' => const LocalModelException(
        'No se pudo cargar el modelo local en este dispositivo.',
      ),
      'MODEL_NOT_LOADED' => const LocalModelException(
        'El modelo local todavía no está cargado.',
      ),
      'BUSY' => const LocalAIException(
        'La IA local ya está procesando una instrucción.',
      ),
      _ => const LocalAIException(
        'No se pudo ejecutar la IA local en el dispositivo.',
      ),
    };
  }
}
