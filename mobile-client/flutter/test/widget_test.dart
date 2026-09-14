import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:software1_mobile/app.dart';
import 'package:software1_mobile/core/config/app_configuration.dart';

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
}
