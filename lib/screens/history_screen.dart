import 'package:flutter/material.dart';

import '../models/past_service.dart';
import '../models/service_request.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../ui/aura.dart';
import '../ui/service_visuals.dart';
import 'appointments_screen.dart';
import 'lab_results_screen.dart';

/// Historial: lo que está en curso y lo que ya pasó.
///
/// ## Qué se arregló
///
/// - **Un solo aviso de la atención en curso.** Había dos, sobre el mismo
///   servicio y con botones al mismo destino: una franja teal arriba del todo y,
///   veinte líneas más abajo, una tarjeta «Cita Activa hoy». Se fusionan en la
///   tarjeta destacada que ya usa el inicio.
/// - **El estado que se muestra es el real.** La franja afirmaba que «el
///   especialista ya se encuentra coordinando los implementos médicos y en
///   trayecto», siempre, aunque la solicitud llevara diez minutos en la cola del
///   sector. Ese texto no salía de ningún dato: se borra y manda
///   `status.label`.
/// - **«Pedido/Receta» se fue.** Abría un diálogo que *describía* la orden
///   médica y la boleta en vez de mostrarlas: un callejón sin salida con
///   aspecto de acción. `PastService` no trae la URL del documento, así que hoy
///   no hay nada que abrir; cuando el modelo la traiga,
///   `state.openMediaAttachment` es el camino y la acción vuelve.
/// - **El historial vacío dice algo.** Sin datos, la lista dejaba el rótulo de
///   sección flotando sobre nada.
/// - **El párrafo legal se pliega.** Cuatro líneas sobre acreditaciones cerraban
///   la pantalla en un bloque ámbar a pantalla completa; ahora es un detalle que
///   se abre quien quiera leerlo.
class HistoryScreen extends StatelessWidget {
  final AppState state;
  final ValueChanged<String> onRepeatService;

  const HistoryScreen({
    super.key,
    required this.state,
    required this.onRepeatService,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final activeRequest = state.currentRequest;
    final hasActiveRequest =
        activeRequest != null &&
        activeRequest.status != RequestStatus.completed &&
        activeRequest.status != RequestStatus.cancelled;
    final past = state.pastServices;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.screenX,
        AuraSpace.md,
        AuraSpace.screenX,
        AuraSpace.navClearance,
      ),
      children: [
        AuraReadable(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Mis citas y consultas',
                  style: AppType.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    color: p.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: AuraSpace.xxs),
              Text(
                'Tu historial y el de las personas a tu cargo.',
                style: AppType.bodySmall.copyWith(color: p.textMuted),
              ),
              const SizedBox(height: AuraSpace.lg),

              // 1 · Lo que está pasando ahora. Si no hay nada en curso la
              //     sección desaparece entera, como en el inicio: un cartel de
              //     "no tienes nada hoy" encima del historial es ruido.
              if (hasActiveRequest) ...[
                _ActiveCareCard(state: state, request: activeRequest),
                const SizedBox(height: AuraSpace.xl),
              ],

              // 2 · Las dos agendas, como filas y no como dos botones de
              //     contorno idénticos apilados.
              const AuraSectionHeader(title: 'Tus agendas'),
              AuraCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.xs,
                  vertical: AuraSpace.xxs,
                ),
                child: Column(
                  children: [
                    AuraActionRow(
                      title: 'Mis citas agendadas',
                      subtitle: 'Consultas con fecha y hora reservada',
                      icon: Icons.event_note_rounded,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AppointmentsScreen(state: state),
                        ),
                      ),
                    ),
                    Divider(height: 1, color: p.border),
                    AuraActionRow(
                      title: 'Mis exámenes de laboratorio',
                      subtitle: 'Tomas de muestra e informes',
                      icon: Icons.biotech_rounded,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LabResultsScreen(state: state),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AuraSpace.xl),

              // 3 · Lo ya atendido.
              const AuraSectionHeader(title: 'Atenciones realizadas'),
              if (past.isEmpty)
                AuraEmptyState(
                  icon: Icons.history_rounded,
                  title: 'Todavía no hay atenciones',
                  message:
                      'Aquí queda el resumen de cada visita, con lo que indicó '
                      'el profesional y la opción de pedir el mismo servicio.',
                  actionLabel: 'Pedir una atención',
                  onAction: () => state.setTab('home'),
                )
              else
                for (var i = 0; i < past.length; i++) ...[
                  if (i > 0) const SizedBox(height: AuraSpace.sm),
                  _PastServiceCard(
                    state: state,
                    past: past[i],
                    onRepeatService: onRepeatService,
                  ),
                ],

              const SizedBox(height: AuraSpace.xl),

              // 4 · Lo legal, plegado. Sigue estando entero; deja de ser lo
              //     último que se lee en la pantalla.
              AuraCard(
                outlined: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.xs,
                  vertical: AuraSpace.xxs,
                ),
                child: AuraDisclosure(
                  title: 'Sobre nuestros profesionales',
                  icon: Icons.verified_user_outlined,
                  child: Text(
                    'Aura cuenta con acreditación de la Superintendencia de '
                    'Salud. Todo nuestro personal pasa por un estricto proceso '
                    'de validación de antecedentes penales, títulos '
                    'universitarios y especialidades clínicas.',
                    style: AppType.bodySmall.copyWith(color: p.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ atención en curso

/// La atención en curso, en una sola tarjeta.
///
/// Antes esto eran dos bloques separados por media pantalla que decían lo mismo
/// y llevaban al mismo sitio. Aquí hay un servicio, su estado real, dónde es y
/// una acción.
class _ActiveCareCard extends StatelessWidget {
  final AppState state;
  final ServiceRequest request;

  const _ActiveCareCard({required this.state, required this.request});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final needsPayment = request.status == RequestStatus.pendingPayment;
    final name = serviceShortName(request.serviceId, 'Tu atención');

    return AuraCard(
      emphasis: true,
      onTap: () => state.setTab('appointments'),
      semanticLabel:
          '$name en curso. ${request.status.label}. En ${request.addressText}. '
          'Tocar para ver el seguimiento.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: p.onBrandDeep.withValues(alpha: 0.16),
                  borderRadius: AuraRadius.allSm,
                ),
                child: Icon(
                  serviceIconFor('', serviceId: request.serviceId),
                  color: p.onBrandDeep,
                  size: AuraIcon.lg,
                ),
              ),
              const SizedBox(width: AuraSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppType.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: p.onBrandDeep,
                      ),
                    ),
                    const SizedBox(height: AuraSpace.xxxs),
                    Row(
                      children: [
                        // El punto acompaña al texto; el estado lo dice el
                        // texto, que es el que viene del servidor.
                        Container(
                          height: 8,
                          width: 8,
                          decoration: BoxDecoration(
                            color: needsPayment ? p.warning : p.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AuraSpace.xxs),
                        Flexible(
                          child: Text(
                            request.status.label,
                            style: AppType.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                              color: p.onBrandDeep.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.place_outlined,
                size: AuraIcon.sm,
                color: p.onBrandDeep.withValues(alpha: 0.7),
              ),
              const SizedBox(width: AuraSpace.xxs),
              Expanded(
                child: Text(
                  request.addressText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.bodySmall.copyWith(
                    color: p.onBrandDeep.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.md),
          AuraButton(
            label: needsPayment ? 'Completar el pago' : 'Ver el seguimiento',
            icon: Icons.arrow_forward_rounded,
            trailingIcon: true,
            onPressed: () => state.setTab('appointments'),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------- atención realizada

class _PastServiceCard extends StatelessWidget {
  final AppState state;
  final PastService past;
  final ValueChanged<String> onRepeatService;

  const _PastServiceCard({
    required this.state,
    required this.past,
    required this.onRepeatService,
  });

  /// El historial trae el estado en crudo del servidor y la tarjeta pintaba
  /// «Completada» en todas sin mirarlo. Cuando el valor no se reconoce no se
  /// pone insignia: mejor eso que afirmar algo que no consta.
  ({String label, AuraTone tone})? get _statusBadge {
    final raw = past.status.toLowerCase();
    if (raw.contains('cancel')) {
      return (label: 'Cancelada', tone: AuraTone.neutral);
    }
    if (raw.contains('no_show') || raw.contains('no show')) {
      return (label: 'No asistió', tone: AuraTone.warning);
    }
    if (raw.contains('complet') || raw.contains('finaliz')) {
      return (label: 'Completada', tone: AuraTone.success);
    }
    return null;
  }

  Future<void> _rate(BuildContext context) async {
    // El messenger se toma antes de abrir el diálogo. El envío ocurre cuando el
    // diálogo ya se cerró, y el código anterior usaba para el aviso el
    // `context` de la pantalla después de ese `Navigator.pop`.
    final messenger = ScaffoldMessenger.of(context);
    final p = context.palette;

    final result = await showDialog<({int rating, String feedback})>(
      context: context,
      builder: (_) => _RatingDialog(past: past),
    );
    if (result == null) return;

    final error = await state.submitRating(
      bookingId: past.id,
      rating: result.rating,
      feedback: result.feedback,
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(error ?? 'Gracias por calificar la atención.'),
        backgroundColor: error == null ? null : p.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final badge = _statusBadge;

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      past.serviceTitle,
                      style: AppType.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: p.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AuraSpace.xxxs),
                    Text(
                      '${past.date} · Paciente: ${past.patient}',
                      style: AppType.label.copyWith(color: p.textMuted),
                    ),
                  ],
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: AuraSpace.xs),
                Flexible(child: AuraBadge(label: badge.label, tone: badge.tone)),
              ],
            ],
          ),
          const SizedBox(height: AuraSpace.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AuraSpace.sm),
            decoration: BoxDecoration(
              color: p.cardSubtle,
              borderRadius: AuraRadius.allMd,
              border: Border.all(color: p.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Era 'RESUMEN DE ATENCIÓN (NOMBRE EN MAYÚSCULAS)'. Las
                // versalitas no añadían jerarquía: la añade el peso.
                Text(
                  'Resumen de ${past.professional}',
                  style: AppType.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: p.accentText,
                  ),
                ),
                const SizedBox(height: AuraSpace.xxs),
                Text(
                  past.details,
                  style: AppType.bodySmall.copyWith(color: p.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: AuraSpace.md),
          // Dos acciones con pesos distintos donde había tres del mismo tamaño
          // en una fila apretada. Repetir el servicio manda; calificar es un
          // extra. La primaria rellena se reserva para la pantalla, no para
          // cada una de las tarjetas de una lista.
          Row(
            children: [
              Expanded(
                child: AuraButton(
                  label: 'Pedir de nuevo',
                  kind: AuraButtonKind.secondary,
                  size: AuraButtonSize.small,
                  icon: Icons.refresh_rounded,
                  onPressed: () => onRepeatService(past.serviceId),
                  semanticLabel: 'Pedir de nuevo: ${past.serviceTitle}',
                ),
              ),
              const SizedBox(width: AuraTap.gap),
              AuraButton(
                label: 'Calificar',
                kind: AuraButtonKind.tertiary,
                size: AuraButtonSize.small,
                icon: Icons.star_outline_rounded,
                expand: false,
                onPressed: () => _rate(context),
                semanticLabel:
                    'Calificar la atención de ${past.professional} '
                    'del ${past.date}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- calificación

/// Diálogo de calificación.
///
/// Es un widget con estado propio por dos defectos concretos del anterior: el
/// `TextEditingController` vivía dentro de un `StatefulBuilder` y no se liberaba
/// nunca, y el envío usaba el `context` de la pantalla después de haber cerrado
/// el diálogo. Aquí el controlador se libera en `dispose` y el diálogo solo
/// devuelve la calificación: quien la envía es la tarjeta.
class _RatingDialog extends StatefulWidget {
  final PastService past;

  const _RatingDialog({required this.past});

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  final TextEditingController _feedback = TextEditingController();

  /// Empieza sin estrellas. Antes empezaba en cinco: tocar «Enviar» sin haber
  /// mirado siquiera las estrellas mandaba un cinco que nadie había puesto.
  int _stars = 0;

  static const List<String> _meaning = [
    'Muy mala',
    'Mala',
    'Regular',
    'Buena',
    'Excelente',
  ];

  @override
  void dispose() {
    _feedback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return AlertDialog(
      // Márgenes propios: cinco objetivos táctiles de 44 px no caben en el
      // ancho por defecto de un diálogo en un teléfono pequeño.
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.md,
        vertical: AuraSpace.xl,
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        AuraSpace.lg,
        AuraSpace.sm,
        AuraSpace.lg,
        AuraSpace.md,
      ),
      title: const Text('¿Cómo estuvo la atención?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.past.professional} · ${widget.past.date}',
              style: AppType.bodySmall.copyWith(color: p.textMuted),
            ),
            const SizedBox(height: AuraSpace.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final star = i + 1;
                final on = star <= _stars;
                return AuraIconButton(
                  icon: on ? Icons.star_rounded : Icons.star_border_rounded,
                  size: AuraIcon.lg,
                  color: on ? p.accent : p.borderStrong,
                  tooltip: '$star de 5: ${_meaning[i]}',
                  onPressed: () => setState(() => _stars = star),
                );
              }),
            ),
            const SizedBox(height: AuraSpace.xs),
            // Qué significa la nota, en palabras: cinco iconos iguales no
            // dicen si tres estrellas es "regular" o "casi bien".
            Center(
              child: Text(
                _stars == 0
                    ? 'Toca una estrella para calificar'
                    : '$_stars de 5 · ${_meaning[_stars - 1]}',
                style: AppType.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _stars == 0 ? p.textMuted : p.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: AuraSpace.md),
            AuraField(
              label: 'Comentario (opcional)',
              hint: '¿Qué destacarías de la visita?',
              controller: _feedback,
              maxLines: 3,
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AuraSpace.lg,
        0,
        AuraSpace.lg,
        AuraSpace.md,
      ),
      actions: [
        AuraButton.tertiary(
          label: 'Ahora no',
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(width: AuraSpace.xs),
        AuraButton(
          label: 'Enviar calificación',
          expand: false,
          // Inhabilitado mientras no haya nota: no hay ningún valor por defecto
          // que enviar en nombre de nadie.
          onPressed: _stars == 0
              ? null
              : () => Navigator.pop(
                    context,
                    (rating: _stars, feedback: _feedback.text.trim()),
                  ),
        ),
      ],
    );
  }
}
