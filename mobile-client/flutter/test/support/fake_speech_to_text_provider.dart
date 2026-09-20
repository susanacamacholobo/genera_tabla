import 'package:software1_mobile/speech/speech_to_text_provider.dart';

class FakeSpeechToTextProvider implements SpeechToTextProvider {
  FakeSpeechToTextProvider({
    this.available = true,
    this.result = const SpeechRecognitionResult(
      transcript: 'lista los clientes',
      locale: 'es-US',
      confidence: 0.9,
    ),
    this.failure,
    this.onListen,
  });

  final bool available;
  final SpeechRecognitionResult result;
  final Object? failure;
  final Future<SpeechRecognitionResult> Function(String locale)? onListen;
  final locales = <String>[];
  int availabilityCalls = 0;
  int listenCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;
  int disposeCalls = 0;
  bool _isListening = false;

  @override
  bool get isListening => _isListening;

  @override
  Future<bool> isAvailable() async {
    availabilityCalls++;
    return available;
  }

  @override
  Future<SpeechRecognitionResult> listen({String locale = 'es-US'}) async {
    listenCalls++;
    locales.add(locale);
    _isListening = true;
    try {
      if (failure case final error?) throw error;
      return await onListen?.call(locale) ?? result;
    } finally {
      _isListening = false;
    }
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    _isListening = false;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    _isListening = false;
  }
}
