import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:software1_mobile/app.dart';
import 'package:software1_mobile/core/config/app_configuration.dart';

import 'support/fake_speech_to_text_provider.dart';

void main() {
  testWidgets('navigates from the reusable home to the assistant', (
    WidgetTester tester,
  ) async {
    final configuration = AppConfiguration.fromValue(
      'http://192.168.1.50:8080',
    );
    await tester.pumpWidget(Software1App(configuration: configuration));
    await tester.pumpAndSettle();

    expect(find.text('Base Flutter lista'), findsOneWidget);
    expect(find.text('http://192.168.1.50:8080/'), findsOneWidget);
    expect(find.text('Veterinaria'), findsOneWidget);
    expect(find.text('1 entidad disponible'), findsOneWidget);

    await tester.tap(find.text('Abrir asistente'));
    await tester.pumpAndSettle();

    expect(find.text('Asistente'), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'Muéstrame los clientes');
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();

    expect(find.text('Instrucción recibida'), findsOneWidget);
    expect(find.text('Muéstrame los clientes'), findsOneWidget);
  });

  testWidgets('connects the assistant microphone to the speech provider', (
    WidgetTester tester,
  ) async {
    final speech = FakeSpeechToTextProvider();
    await tester.pumpWidget(
      Software1App(
        configuration: AppConfiguration.fromValue('http://10.0.2.2:8080'),
        speechToTextProvider: speech,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Abrir asistente'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Usar micrófono sin conexión'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, 'lista los clientes');
    expect(speech.listenCalls, 1);
    expect(speech.locales, ['es-BO']);
  });
}
