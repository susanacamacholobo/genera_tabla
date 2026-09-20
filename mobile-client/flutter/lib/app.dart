import 'dart:async';

import 'package:flutter/material.dart';

import 'ai/llm/lite_rt_local_ai_provider.dart';
import 'ai/llm/local_ai_provider.dart';
import 'core/api/api_client.dart';
import 'core/config/app_configuration.dart';
import 'core/dependencies/app_dependencies.dart';
import 'domain/loading/domain_model_loader.dart';
import 'navigation/app_router.dart';
import 'offline/offline_data_coordinator.dart';
import 'offline/offline_store.dart';
import 'offline/sqlite_offline_store.dart';
import 'speech/android_speech_to_text_provider.dart';
import 'speech/speech_to_text_provider.dart';

class Software1App extends StatefulWidget {
  const Software1App({
    required this.configuration,
    this.apiClient,
    this.domainModelLoader = const DomainModelLoader(),
    this.speechToTextProvider,
    this.localAIProvider,
    this.offlineStore,
    super.key,
  });

  final AppConfiguration configuration;
  final ApiClient? apiClient;
  final DomainModelLoader domainModelLoader;
  final SpeechToTextProvider? speechToTextProvider;
  final LocalAIProvider? localAIProvider;
  final OfflineStore? offlineStore;

  @override
  State<Software1App> createState() => _Software1AppState();
}

class _Software1AppState extends State<Software1App> {
  late ApiClient _apiClient;
  late bool _ownsApiClient;
  late SpeechToTextProvider _speechToTextProvider;
  late bool _ownsSpeechToTextProvider;
  late LocalAIProvider _localAIProvider;
  late bool _ownsLocalAIProvider;
  late OfflineDataCoordinator _offlineCoordinator;

  @override
  void initState() {
    super.initState();
    _setApiClient();
    _setOfflineCoordinator();
    _setSpeechToTextProvider();
    _setLocalAIProvider();
  }

  @override
  void didUpdateWidget(covariant Software1App oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.apiClient != widget.apiClient ||
        oldWidget.configuration != widget.configuration ||
        oldWidget.offlineStore != widget.offlineStore) {
      _offlineCoordinator.dispose();
      if (_ownsApiClient) _apiClient.close();
      _setApiClient();
      _setOfflineCoordinator();
    }
    if (oldWidget.speechToTextProvider != widget.speechToTextProvider) {
      if (_ownsSpeechToTextProvider) {
        unawaited(_speechToTextProvider.dispose());
      }
      _setSpeechToTextProvider();
    }
    if (oldWidget.localAIProvider != widget.localAIProvider) {
      if (_ownsLocalAIProvider) {
        unawaited(_localAIProvider.dispose());
      }
      _setLocalAIProvider();
    }
  }

  void _setSpeechToTextProvider() {
    _ownsSpeechToTextProvider = widget.speechToTextProvider == null;
    _speechToTextProvider =
        widget.speechToTextProvider ?? AndroidSpeechToTextProvider();
  }

  void _setLocalAIProvider() {
    _ownsLocalAIProvider = widget.localAIProvider == null;
    _localAIProvider = widget.localAIProvider ?? LiteRtLocalAIProvider();
  }

  void _setApiClient() {
    _ownsApiClient = widget.apiClient == null;
    _apiClient =
        widget.apiClient ?? ApiClient(configuration: widget.configuration);
  }

  void _setOfflineCoordinator() {
    _offlineCoordinator = OfflineDataCoordinator(
      apiClient: _apiClient,
      store: widget.offlineStore ?? SqliteOfflineStore(),
    );
  }

  @override
  void dispose() {
    _offlineCoordinator.dispose();
    if (_ownsApiClient) _apiClient.close();
    if (_ownsSpeechToTextProvider) {
      unawaited(_speechToTextProvider.dispose());
    }
    if (_ownsLocalAIProvider) unawaited(_localAIProvider.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = AppRouter(
      configuration: widget.configuration,
      domainModelLoader: widget.domainModelLoader,
    );
    return AppDependencies(
      configuration: widget.configuration,
      apiClient: _apiClient,
      domainModelLoader: widget.domainModelLoader,
      speechToTextProvider: _speechToTextProvider,
      localAIProvider: _localAIProvider,
      offlineCoordinator: _offlineCoordinator,
      child: MaterialApp(
        title: 'Software 1 Mobile',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff3157d5)),
          useMaterial3: true,
        ),
        initialRoute: AppRoutes.home,
        onGenerateRoute: router.onGenerateRoute,
      ),
    );
  }
}
