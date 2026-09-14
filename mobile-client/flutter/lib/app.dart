import 'dart:async';

import 'package:flutter/material.dart';

import 'core/api/api_client.dart';
import 'core/config/app_configuration.dart';
import 'core/dependencies/app_dependencies.dart';
import 'domain/loading/domain_model_loader.dart';
import 'navigation/app_router.dart';
import 'speech/android_speech_to_text_provider.dart';
import 'speech/speech_to_text_provider.dart';

class Software1App extends StatefulWidget {
  const Software1App({
    required this.configuration,
    this.apiClient,
    this.domainModelLoader = const DomainModelLoader(),
    this.speechToTextProvider,
    super.key,
  });

  final AppConfiguration configuration;
  final ApiClient? apiClient;
  final DomainModelLoader domainModelLoader;
  final SpeechToTextProvider? speechToTextProvider;

  @override
  State<Software1App> createState() => _Software1AppState();
}

class _Software1AppState extends State<Software1App> {
  late ApiClient _apiClient;
  late bool _ownsApiClient;
  late SpeechToTextProvider _speechToTextProvider;
  late bool _ownsSpeechToTextProvider;

  @override
  void initState() {
    super.initState();
    _setApiClient();
    _setSpeechToTextProvider();
  }

  @override
  void didUpdateWidget(covariant Software1App oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.apiClient != widget.apiClient ||
        oldWidget.configuration != widget.configuration) {
      if (_ownsApiClient) _apiClient.close();
      _setApiClient();
    }
    if (oldWidget.speechToTextProvider != widget.speechToTextProvider) {
      if (_ownsSpeechToTextProvider) {
        unawaited(_speechToTextProvider.dispose());
      }
      _setSpeechToTextProvider();
    }
  }

  void _setSpeechToTextProvider() {
    _ownsSpeechToTextProvider = widget.speechToTextProvider == null;
    _speechToTextProvider =
        widget.speechToTextProvider ?? AndroidSpeechToTextProvider();
  }

  void _setApiClient() {
    _ownsApiClient = widget.apiClient == null;
    _apiClient =
        widget.apiClient ?? ApiClient(configuration: widget.configuration);
  }

  @override
  void dispose() {
    if (_ownsApiClient) _apiClient.close();
    if (_ownsSpeechToTextProvider) {
      unawaited(_speechToTextProvider.dispose());
    }
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
