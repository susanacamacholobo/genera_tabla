class SpeechRecognitionResult {
  const SpeechRecognitionResult({
    required this.transcript,
    required this.locale,
    this.confidence,
  });

  final String transcript;
  final String locale;
  final double? confidence;
}

abstract interface class SpeechToTextProvider {
  bool get isListening;

  Future<bool> isAvailable();

  Future<SpeechRecognitionResult> listen({String locale = 'es-ES'});

  Future<void> stop();

  Future<void> cancel();

  Future<void> dispose();
}
