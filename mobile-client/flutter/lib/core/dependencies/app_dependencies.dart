import 'package:flutter/widgets.dart';

import '../../ai/llm/local_ai_provider.dart';
import '../../domain/loading/domain_model_loader.dart';
import '../../offline/offline_data_coordinator.dart';
import '../../speech/speech_to_text_provider.dart';
import '../api/api_client.dart';
import '../config/app_configuration.dart';

class AppDependencies extends InheritedWidget {
  const AppDependencies({
    required this.configuration,
    required this.apiClient,
    required this.domainModelLoader,
    required this.speechToTextProvider,
    required this.localAIProvider,
    required this.offlineCoordinator,
    required super.child,
    super.key,
  });

  final AppConfiguration configuration;
  final ApiClient apiClient;
  final DomainModelLoader domainModelLoader;
  final SpeechToTextProvider speechToTextProvider;
  final LocalAIProvider localAIProvider;
  final OfflineDataCoordinator offlineCoordinator;

  static AppDependencies of(BuildContext context) {
    final dependencies = context
        .dependOnInheritedWidgetOfExactType<AppDependencies>();
    assert(
      dependencies != null,
      'AppDependencies no está disponible en este contexto.',
    );
    return dependencies!;
  }

  @override
  bool updateShouldNotify(AppDependencies oldWidget) =>
      configuration != oldWidget.configuration ||
      apiClient != oldWidget.apiClient ||
      domainModelLoader != oldWidget.domainModelLoader ||
      speechToTextProvider != oldWidget.speechToTextProvider ||
      localAIProvider != oldWidget.localAIProvider ||
      offlineCoordinator != oldWidget.offlineCoordinator;
}
