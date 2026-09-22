import 'package:flutter/material.dart';

import '../../core/config/app_configuration.dart';
import '../../core/errors/app_exception.dart';
import '../../domain/loading/domain_model_loader.dart';
import '../../domain/model/domain_model.dart';
import '../../navigation/app_router.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.configuration,
    required this.domainModelLoader,
    super.key,
  });

  final AppConfiguration configuration;
  final DomainModelLoader domainModelLoader;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<DomainModel> _domainModel;

  @override
  void initState() {
    super.initState();
    _loadDomainModel();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.domainModelLoader != widget.domainModelLoader) {
      _loadDomainModel();
    }
  }

  void _loadDomainModel() {
    _domainModel = widget.domainModelLoader.loadFromAsset(
      AppConfiguration.domainModelAsset,
    );
  }

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
                subtitle: Text(widget.configuration.apiBaseUri.toString()),
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<DomainModel>(
              future: _domainModel,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Card(
                    child: ListTile(
                      leading: SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      title: Text('Cargando contrato de dominio…'),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.error_outline),
                      title: const Text('Contrato de dominio inválido'),
                      subtitle: Text(userMessageFor(snapshot.error!)),
                      trailing: IconButton(
                        onPressed: () => setState(_loadDomainModel),
                        tooltip: 'Reintentar',
                        icon: const Icon(Icons.refresh),
                      ),
                    ),
                  );
                }

                final model = snapshot.requireData;
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.schema_outlined),
                    title: Text(model.application),
                    subtitle: Text(
                      '${model.entities.length} ${model.entities.length == 1 ? 'entidad disponible' : 'entidades disponibles'}',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.assistant),
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('Abrir asistente'),
            ),
            if (AppConfiguration.demoDomain == 'biblioteca') ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.biblioteca),
                icon: const Icon(Icons.local_library_outlined),
                label: const Text('Abrir Biblioteca'),
              ),
            ],
            if (AppConfiguration.demoDomain == 'hotel') ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.hotel),
                icon: const Icon(Icons.hotel_outlined),
                label: const Text('Abrir Hotel'),
              ),
            ],
            if (AppConfiguration.demoDomain == 'universidad') ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.universidad),
                icon: const Icon(Icons.school_outlined),
                label: const Text('Abrir Universidad'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
