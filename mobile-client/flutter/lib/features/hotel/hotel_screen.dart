import 'package:flutter/material.dart';

import '../demo/manual_crud_demo_screen.dart';

/// Formulario de Hotel definido manualmente, independiente del editor UML.
class HotelScreen extends StatelessWidget {
  const HotelScreen({super.key});

  @override
  Widget build(BuildContext context) => const ManualCrudDemoScreen(
    title: 'Hotel',
    sections: [
      DemoSection('Huéspedes', '/api/huespedes', 'nombre', [
        DemoField('nombre', 'Nombre del huésped'),
      ]),
      DemoSection('Habitaciones', '/api/habitaciones', 'numero', [
        DemoField('numero', 'Número de habitación'),
        DemoField(
          'precioNoche',
          'Precio por noche',
          kind: DemoFieldKind.decimal,
        ),
      ]),
      DemoSection('Reservas', '/api/reservas', 'fechaEntrada', [
        DemoField(
          'fechaEntrada',
          'Entrada (vacío = hoy)',
          kind: DemoFieldKind.date,
        ),
        DemoField('fechaSalida', 'Salida', kind: DemoFieldKind.date),
        DemoField('huespedId', 'ID de huésped', kind: DemoFieldKind.integer),
        DemoField(
          'habitacionId',
          'ID de habitación',
          kind: DemoFieldKind.integer,
        ),
      ]),
    ],
  );
}
