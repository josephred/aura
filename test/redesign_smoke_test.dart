import 'package:aura/models/clinical_service.dart';
import 'package:aura/theme/app_theme.dart';
import 'package:aura/ui/aura.dart';
import 'package:aura/ui/service_visuals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Estas pruebas montan los componentes del sistema de diseño de verdad.
///
/// `flutter analyze` dice que el código compila; no dice que una tarjeta no
/// desborde cuando alguien pone la letra al 200 %, que es exactamente el
/// escenario para el que se rediseñó esta app. Aquí se renderiza en un lienzo
/// de teléfono pequeño (320×640) y con `textScaler` al máximo que permite la
/// app, y se comprueba que Flutter no reporte desbordes.
void main() {
  Widget host(Widget child, {double textScale = 1.0, Brightness brightness = Brightness.light}) {
    return MaterialApp(
      theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(320, 640),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
  }

  group('Sistema de diseño', () {
    testWidgets('los botones se pintan en sus cuatro variantes', (tester) async {
      await tester.pumpWidget(host(Column(
        children: [
          AuraButton.primary(label: 'Pedir un médico', onPressed: () {}),
          AuraButton.secondary(label: 'Volver', onPressed: () {}),
          AuraButton.tertiary(label: 'Más opciones', onPressed: () {}),
          AuraButton.danger(label: 'Cancelar', onPressed: () {}),
          const AuraButton.primary(label: 'Inhabilitado', onPressed: null),
          AuraButton.primary(label: 'Cargando', onPressed: () {}, loading: true),
        ],
      )));
      expect(find.text('Pedir un médico'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('la acción principal alcanza el objetivo táctil de 60 px', (tester) async {
      await tester.pumpWidget(host(AuraButton.primary(label: 'Continuar', onPressed: () {})));
      final size = tester.getSize(find.byType(TextButton));
      expect(size.height, greaterThanOrEqualTo(AuraTap.large));
    });

    testWidgets('los botones de icono nunca bajan de 44 px', (tester) async {
      await tester.pumpWidget(host(
        AuraIconButton(icon: Icons.close_rounded, tooltip: 'Cerrar', onPressed: () {}),
      ));
      final size = tester.getSize(find.byType(InkWell).first);
      expect(size.width, greaterThanOrEqualTo(AuraTap.min));
      expect(size.height, greaterThanOrEqualTo(AuraTap.min));
    });

    testWidgets('una opción del flujo guiado mide al menos 60 px', (tester) async {
      await tester.pumpWidget(host(AuraChoiceTile(
        title: 'Para mí',
        subtitle: 'Aaron Redondo',
        icon: Icons.person_rounded,
        onTap: () {},
      )));
      expect(tester.getSize(find.byType(InkWell).first).height,
          greaterThanOrEqualTo(AuraTap.large));
    });

    testWidgets('los estados vacío, de error y de éxito se pintan', (tester) async {
      await tester.pumpWidget(host(Column(
        children: [
          const AuraEmptyState(
            icon: Icons.inbox_rounded,
            title: 'Aún no tienes atenciones',
            message: 'Cuando pidas una, aparecerá aquí.',
          ),
          const AuraErrorState(
            title: 'No pudimos cargar tus citas',
            message: 'Revisa tu conexión e inténtalo otra vez.',
          ),
          const AuraSuccessState(
            title: 'Solicitud enviada',
            message: 'Te avisamos cuando esté confirmada.',
          ),
        ],
      )));
      expect(find.text('Aún no tienes atenciones'), findsOneWidget);
      expect(find.text('No pudimos cargar tus citas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('un paso del flujo guiado ancla su acción al fondo', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AuraFlowStep(
            question: '¿Para quién es la atención?',
            primaryLabel: 'Continuar',
            onPrimary: () {},
            child: Column(children: [
              AuraChoiceTile(title: 'Para mí', selected: true, onTap: () {}),
              AuraChoiceTile(title: 'Para un familiar', onTap: () {}),
            ]),
          ),
        ),
      ));
      expect(find.text('¿Para quién es la atención?'), findsOneWidget);
      expect(find.text('Continuar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('un paso bloqueado dice qué falta y deshabilita el botón', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: AuraFlowStep(
            question: '¿Dónde te atendemos?',
            primaryLabel: 'Continuar',
            onPrimary: null,
            blockedReason: 'Escribe la dirección donde te atendemos.',
            child: const SizedBox(height: 100),
          ),
        ),
      ));
      expect(find.text('Escribe la dirección donde te atendemos.'), findsOneWidget);
      final button = tester.widget<TextButton>(find.byType(TextButton).last);
      expect(button.onPressed, isNull);
    });
  });

  group('Escalado de texto y modo oscuro', () {
    // 2.0 es el techo que fija `main.dart`, y es lo que exige WCAG 1.4.4.
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('sin desbordes al ${(scale * 100).round()} % en claro', (tester) async {
        await tester.pumpWidget(host(
          Column(children: [
            AuraChoiceTile(
              title: 'Traslado medicalizado',
              subtitle: 'Con enfermero y equipo de soporte',
              icon: Icons.monitor_heart_rounded,
              trailingText: r'$28.500',
              onTap: () {},
            ),
            const AuraBanner(
              tone: AuraTone.warning,
              title: 'Si hay riesgo vital, llama a urgencias',
              message: 'Aura atiende en casa casos que pueden esperar unas horas.',
            ),
            const AuraSummaryRow(
              label: 'Dirección',
              value: 'Calle Los Alerces 1420, depto 402, Providencia',
            ),
            AuraButton.primary(label: 'Pedir el traslado', onPressed: () {}),
          ]),
          textScale: scale,
        ));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('la rejilla de servicios aguanta un teléfono pequeño', (tester) async {
      await tester.pumpWidget(host(
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AuraSpace.sm,
          crossAxisSpacing: AuraSpace.sm,
          childAspectRatio: 0.92,
          children: [
            for (final id in homeServiceIds)
              AuraServiceTile(
                label: serviceShortName(id, id),
                hint: serviceOneLiner(id, ''),
                icon: serviceIconFor('', serviceId: id),
                onTap: () {},
              ),
          ],
        ),
      ));
      expect(find.text('Médico'), findsOneWidget);
      expect(find.text('Ambulancia'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('los componentes se pintan también en oscuro', (tester) async {
      await tester.pumpWidget(host(
        Column(children: [
          AuraCard(emphasis: true, child: const Text('Atención en curso')),
          const AuraBadge(label: 'Pago confirmado', tone: AuraTone.success),
          const AuraBanner(tone: AuraTone.error, message: 'No pudimos reservar la hora.'),
          AuraButton.primary(label: 'Ver el seguimiento', onPressed: () {}),
        ]),
        brightness: Brightness.dark,
      ));
      expect(tester.takeException(), isNull);
    });
  });

  group('Catálogo de servicios', () {
    test('cada servicio del inicio tiene icono, nombre corto y descripción', () {
      for (final id in homeServiceIds) {
        expect(serviceShortName(id, 'fallback'), isNot('fallback'),
            reason: '$id no tiene nombre corto');
        expect(serviceOneLiner(id, 'fallback'), isNot('fallback'),
            reason: '$id no tiene descripción de una línea');
        expect(serviceIconFor('', serviceId: id),
            isNot(Icons.health_and_safety_rounded),
            reason: '$id cae al icono por defecto');
      }
    });

    test('el nombre corto no es el título largo del catálogo', () {
      const catalogo = ClinicalService(
        id: 'ambulancia',
        title: 'Ambulancia de Transporte Programado',
        shortTitle: 'Ambulancia',
        subtitle: 'Traslado clínico básico o medicalizado no urgente.',
        description: '',
        basePrice: 18500,
        baseEta: '15 - 30',
        requiresPrescription: false,
        iconName: 'Truck',
      );
      expect(serviceShortName(catalogo.id, catalogo.shortTitle), 'Ambulancia');
      expect(serviceOneLiner(catalogo.id, catalogo.subtitle), 'Traslado programado');
    });

    test('la espera se redondea a lenguaje llano', () {
      expect(etaHint('45 - 60'), 'Desde 45 min');
      expect(etaHint('120 - 180'), 'Desde 2 h');
      expect(etaHint('sin dato'), '');
    });
  });
}
