abstract interface class LocalAIProvider {
  bool get isModelLoaded;

  Future<void> loadModel();

  Future<String> generateStructuredIntent({
    required String instruction,
    required String domainContext,
  });

  Future<void> dispose();
}
