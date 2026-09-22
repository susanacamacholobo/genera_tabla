import 'package:flutter/material.dart';

import '../demo/manual_crud_demo_screen.dart';

/// Formulario de Universidad definido manualmente, independiente del editor UML.
class UniversidadScreen extends StatelessWidget {
  const UniversidadScreen({super.key});

  @override
  Widget build(BuildContext context) => const ManualCrudDemoScreen(
    title: 'Universidad',
    sections: [
      DemoSection('Estudiantes', '/api/estudiantes', 'nombre', [
        DemoField('nombre', 'Nombre del estudiante'),
        DemoField('codigo', 'Código de estudiante'),
      ]),
      DemoSection('Cursos', '/api/cursos', 'nombre', [
        DemoField('nombre', 'Nombre del curso'),
        DemoField('codigo', 'Código de curso'),
      ]),
      DemoSection('Matrículas', '/api/matriculas', 'fechaRegistro', [
        DemoField(
          'fechaRegistro',
          'Fecha (vacío = hoy)',
          kind: DemoFieldKind.date,
        ),
        DemoField(
          'estudianteId',
          'ID de estudiante',
          kind: DemoFieldKind.integer,
        ),
        DemoField('cursoId', 'ID de curso', kind: DemoFieldKind.integer),
      ]),
    ],
  );
}
