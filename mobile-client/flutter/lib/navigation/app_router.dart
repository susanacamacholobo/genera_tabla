import 'package:flutter/material.dart';

import '../core/config/app_configuration.dart';
import '../domain/loading/domain_model_loader.dart';
import '../features/assistant/assistant_screen.dart';
import '../features/biblioteca/biblioteca_screen.dart';
import '../features/hotel/hotel_screen.dart';
import '../features/home/home_screen.dart';
import '../features/universidad/universidad_screen.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const assistant = '/assistant';
  static const biblioteca = '/biblioteca';
  static const hotel = '/hotel';
  static const universidad = '/universidad';
}

class AppRouter {
  const AppRouter({
    required this.configuration,
    required this.domainModelLoader,
  });

  final AppConfiguration configuration;
  final DomainModelLoader domainModelLoader;

  Route<void> onGenerateRoute(RouteSettings settings) {
    return switch (settings.name) {
      AppRoutes.home => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => HomeScreen(
          configuration: configuration,
          domainModelLoader: domainModelLoader,
        ),
      ),
      AppRoutes.assistant => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const AssistantScreen(),
      ),
      AppRoutes.biblioteca => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const BibliotecaScreen(),
      ),
      AppRoutes.hotel => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const HotelScreen(),
      ),
      AppRoutes.universidad => MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const UniversidadScreen(),
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
