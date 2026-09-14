import 'package:flutter/services.dart';

import '../core/errors/app_exception.dart';
import 'speech_exception.dart';
import 'speech_to_text_provider.dart';

class AndroidSpeechToTextProvider implements SpeechToTextProvider {
  AndroidSpeechToTextProvider({
    MethodChannel channel = const MethodChannel(channelName),
  }) : _channel = channel;

  static const channelName = 'bo.edu.software1/speech_to_text';

  final MethodChannel _channel;
  bool _isListening = false;
  bool _isDisposed = false;

  @override
  bool get isListening => _isListening;

  @override
  Future<bool> isAvailable() async {
    _assertNotDisposed();
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on PlatformException catch (error) {
      throw _mapPlatformError(error);
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<SpeechRecognitionResult> listen({String locale = 'es-BO'}) async {
    _assertNotDisposed();
    if (_isListening) {
      throw const SpeechRecognitionException(
        'Ya hay un reconocimiento de voz en curso.',
      );
    }
    final normalizedLocale = locale.trim();
    if (normalizedLocale.isEmpty) {
      throw const SpeechRecognitionException(
        'El idioma de reconocimiento no puede estar vacío.',
      );
    }

    _isListening = true;
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>('listen', {
        'locale': normalizedLocale,
      });
      if (raw == null) {
        throw const SpeechRecognitionException(
          'El reconocedor local no devolvió un resultado.',
        );
      }
      final transcript = raw['transcript'];
      final resultLocale = raw['locale'];
      final confidence = raw['confidence'];
      if (transcript is! String ||
          transcript.trim().isEmpty ||
          resultLocale is! String ||
          resultLocale.trim().isEmpty ||
          (confidence != null && confidence is! num)) {
        throw const SpeechRecognitionException(
          'El reconocedor local devolvió un resultado inválido.',
        );
      }
      return SpeechRecognitionResult(
        transcript: transcript.trim(),
        locale: resultLocale,
        confidence: (confidence as num?)?.toDouble(),
      );
    } on PlatformException catch (error) {
      throw _mapPlatformError(error);
    } on MissingPluginException {
      throw const SpeechUnavailableException(
        'El reconocimiento de voz local sólo está disponible en Android.',
      );
    } finally {
      _isListening = false;
    }
  }

  @override
  Future<void> stop() => _invokeControlMethod('stop');

  @override
  Future<void> cancel() => _invokeControlMethod('cancel');

  Future<void> _invokeControlMethod(String method) async {
    _assertNotDisposed();
    try {
      await _channel.invokeMethod<void>(method);
    } on PlatformException catch (error) {
      throw _mapPlatformError(error);
    } on MissingPluginException {
      throw const SpeechUnavailableException(
        'El reconocimiento de voz local sólo está disponible en Android.',
      );
    }
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    try {
      await _channel.invokeMethod<void>('dispose');
    } on PlatformException {
      // The Android activity can already be gone while Flutter is disposing.
    } on MissingPluginException {
      // Non-Android test and desktop targets do not register this channel.
    } finally {
      _isDisposed = true;
      _isListening = false;
    }
  }

  void _assertNotDisposed() {
    if (_isDisposed) {
      throw const SpeechRecognitionException(
        'El reconocedor de voz ya fue cerrado.',
      );
    }
  }

  AppException _mapPlatformError(PlatformException error) {
    return switch (error.code) {
      'OFFLINE_UNAVAILABLE' => const SpeechUnavailableException(
        'Este dispositivo no tiene reconocimiento de voz local disponible. '
        'Instala el idioma sin conexión en Android.',
      ),
      'PERMISSION_DENIED' => const SpeechPermissionException(
        'Se necesita permiso de micrófono para reconocer voz.',
      ),
      'NO_MATCH' => const SpeechRecognitionException(
        'No se pudo reconocer lo que dijiste. Inténtalo de nuevo.',
      ),
      'NO_SPEECH' => const SpeechRecognitionException(
        'No se detectó voz. Inténtalo de nuevo.',
      ),
      'BUSY' => const SpeechRecognitionException(
        'El reconocimiento de voz ya está ocupado.',
      ),
      'CANCELLED' => const SpeechRecognitionException(
        'El reconocimiento de voz fue cancelado.',
      ),
      _ => const SpeechRecognitionException(
        'No se pudo completar el reconocimiento de voz local.',
      ),
    };
  }
}
