import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:software1_mobile/ai/llm/local_ai_exception.dart';
import 'package:software1_mobile/ai/llm/local_model_manager.dart';
import 'package:software1_mobile/assistant/local_model_setup_card.dart';

void main() {
  testWidgets('offers model import when no model is installed', (tester) async {
    final provider = _FakeManagedProvider();

    await tester.pumpWidget(_app(provider));
    await tester.pumpAndSettle();

    expect(find.text('Importar .litertlm'), findsOneWidget);
    expect(find.textContaining('Selecciona desde el teléfono'), findsOneWidget);
  });

  testWidgets('imports and then loads the selected model', (tester) async {
    final provider = _FakeManagedProvider();
    await tester.pumpWidget(_app(provider));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Importar .litertlm'));
    await tester.pumpAndSettle();

    expect(provider.importCalls, 1);
    expect(find.text('Cargar modelo'), findsOneWidget);
    expect(find.textContaining('4 MB'), findsOneWidget);

    await tester.tap(find.text('Cargar modelo'));
    await tester.pumpAndSettle();

    expect(provider.loadCalls, 1);
    expect(find.textContaining('listo sin Internet'), findsOneWidget);
    expect(find.text('Cargar modelo'), findsNothing);
  });

  testWidgets('shows a safe model error', (tester) async {
    final provider = _FakeManagedProvider(
      importFailure: const LocalModelException('Modelo incompatible.'),
    );
    await tester.pumpWidget(_app(provider));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Importar .litertlm'));
    await tester.pumpAndSettle();

    expect(find.text('Modelo incompatible.'), findsOneWidget);
  });
}

Widget _app(ManagedLocalAIProvider provider) {
  return MaterialApp(
    home: Scaffold(body: LocalModelSetupCard(provider: provider)),
  );
}

class _FakeManagedProvider implements ManagedLocalAIProvider {
  _FakeManagedProvider({this.importFailure});

  final Object? importFailure;
  var status = const LocalModelStatus(installed: false, loaded: false);
  int importCalls = 0;
  int loadCalls = 0;

  @override
  bool get isModelLoaded => status.loaded;

  @override
  Future<LocalModelStatus> getModelStatus() async => status;

  @override
  Future<LocalModelStatus> importModel() async {
    importCalls++;
    if (importFailure case final failure?) throw failure;
    status = const LocalModelStatus(
      installed: true,
      loaded: false,
      fileName: 'assistant.litertlm',
      sizeBytes: 4 * 1024 * 1024,
    );
    return status;
  }

  @override
  Future<void> loadModel() async {
    loadCalls++;
    status = LocalModelStatus(
      installed: true,
      loaded: true,
      fileName: status.fileName,
      sizeBytes: status.sizeBytes,
    );
  }

  @override
  Future<String> generateStructuredIntent({
    required String instruction,
    required String domainContext,
  }) async => '{}';

  @override
  Future<void> dispose() async {}
}
