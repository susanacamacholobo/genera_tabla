import 'package:flutter/material.dart';

import '../../core/config/app_configuration.dart';
import '../../navigation/app_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.configuration, super.key});

  final AppConfiguration configuration;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Software 1 Mobile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Base Flutter lista',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              'Esta aplicación contiene la infraestructura reutilizable para conectar las pantallas del dominio y el asistente local.',
            ),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                leading: const Icon(Icons.lan_outlined),
                title: const Text('Backend configurado'),
                subtitle: Text(configuration.apiBaseUri.toString()),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.assistant),
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('Abrir asistente'),
            ),
          ],
        ),
      ),
    );
  }
}
