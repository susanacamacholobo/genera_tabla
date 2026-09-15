import 'local_ai_provider.dart';

class LocalModelStatus {
  const LocalModelStatus({
    required this.installed,
    required this.loaded,
    this.fileName,
    this.sizeBytes,
  });

  final bool installed;
  final bool loaded;
  final String? fileName;
  final int? sizeBytes;
}

abstract interface class ManagedLocalAIProvider implements LocalAIProvider {
  Future<LocalModelStatus> getModelStatus();

  Future<LocalModelStatus> importModel();
}
