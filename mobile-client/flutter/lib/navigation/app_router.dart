import 'package:flutter/material.dart';

import '../core/config/app_configuration.dart';
import '../features/assistant/assistant_screen.dart';
import '../features/home/home_screen.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const assistant = '/assistant';
}

class AppRouter {
  const AppRouter({required this.configuration});

  final AppConfiguration configuration;

  Route<void> onGenerateRoute(RouteSettings settings) {
    return switch (settings.name) {
      AppRoutes.home => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => HomeScreen(configuration: configuration),
      ),
      AppRoutes.assistant => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const AssistantScreen(),
      ),
      _ => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const _UnknownRouteScreen(),
      ),
    };
  }
}

class _UnknownRouteScreen extends StatelessWidget {
  const _UnknownRouteScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ruta no encontrada')),
      body: Center(
        child: FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false),
          child: const Text('Volver al inicio'),
        ),
      ),
    );
  }
}
