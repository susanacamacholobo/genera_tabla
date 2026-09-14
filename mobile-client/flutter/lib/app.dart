import 'package:flutter/material.dart';

import 'core/api/api_client.dart';
import 'core/config/app_configuration.dart';
import 'core/dependencies/app_dependencies.dart';
import 'navigation/app_router.dart';

class Software1App extends StatefulWidget {
  const Software1App({required this.configuration, this.apiClient, super.key});

  final AppConfiguration configuration;
  final ApiClient? apiClient;

  @override
  State<Software1App> createState() => _Software1AppState();
}

class _Software1AppState extends State<Software1App> {
  late ApiClient _apiClient;
  late bool _ownsApiClient;

  @override
  void initState() {
    super.initState();
    _setApiClient();
  }

  @override
  void didUpdateWidget(covariant Software1App oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.apiClient != widget.apiClient ||
        oldWidget.configuration != widget.configuration) {
      if (_ownsApiClient) _apiClient.close();
      _setApiClient();
    }
  }

  void _setApiClient() {
    _ownsApiClient = widget.apiClient == null;
    _apiClient =
        widget.apiClient ?? ApiClient(configuration: widget.configuration);
  }

  @override
  void dispose() {
    if (_ownsApiClient) _apiClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = AppRouter(configuration: widget.configuration);
    return AppDependencies(
      configuration: widget.configuration,
      apiClient: _apiClient,
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
