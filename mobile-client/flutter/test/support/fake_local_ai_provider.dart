import 'package:software1_mobile/ai/llm/local_ai_provider.dart';

class FakeLocalAIProvider implements LocalAIProvider {
  FakeLocalAIProvider({
    required this.response,
    this.loadFailure,
    this.generationFailure,
  });

  final String response;
  final Object? loadFailure;
  final Object? generationFailure;
  final instructions = <String>[];
  final contexts = <String>[];
  int loadCalls = 0;
  int disposeCalls = 0;
  bool _isModelLoaded = false;

  @override
  bool get isModelLoaded => _isModelLoaded;

  @override
  Future<void> loadModel() async {
    loadCalls++;
    if (loadFailure case final failure?) throw failure;
    _isModelLoaded = true;
  }

  @override
  Future<String> generateStructuredIntent({
    required String instruction,
    required String domainContext,
  }) async {
    instructions.add(instruction);
    contexts.add(domainContext);
    if (generationFailure case final failure?) throw failure;
    return response;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    _isModelLoaded = false;
  }
}
