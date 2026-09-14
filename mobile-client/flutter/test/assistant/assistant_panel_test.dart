import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:software1_mobile/assistant/assistant_panel.dart';
import 'package:software1_mobile/core/errors/app_exception.dart';

void main() {
  testWidgets('validates empty instructions', (WidgetTester tester) async {
    await tester.pumpWidget(_app(AssistantPanel(onSubmit: (_) async {})));

    await tester.tap(find.text('Enviar'));
    await tester.pump();

    expect(find.text('Escribe una instrucción.'), findsOneWidget);
  });

  testWidgets('waits for async processing and prevents duplicate submissions', (
    WidgetTester tester,
  ) async {
    final pending = Completer<void>();
    final received = <String>[];
    await tester.pumpWidget(
      _app(
        AssistantPanel(
          onSubmit: (instruction) {
            received.add(instruction);
            return pending.future;
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '  Lista clientes  ');
    await tester.tap(find.text('Enviar'));
    await tester.pump();

    expect(find.text('Procesando…'), findsOneWidget);
    expect(received, ['Lista clientes']);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Procesando…'),
    );
    expect(button.onPressed, isNull);

    pending.complete();
    await tester.pumpAndSettle();

    expect(find.text('Enviar'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, isEmpty);
  });

  testWidgets('shows safe messages for typed application errors', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(
        AssistantPanel(
          onSubmit: (_) async {
            throw const NetworkException('Servidor local no disponible.');
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Lista clientes');
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();

    expect(find.text('Servidor local no disponible.'), findsOneWidget);
  });
}

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));
