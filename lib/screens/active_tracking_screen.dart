import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/dependent.dart';
import '../models/service_request.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../ui/aura.dart';
import '../ui/service_visuals.dart';
import '../utils/money.dart';
import '../widgets/tracking_map.dart';
import 'doctor_profile_screen.dart';

/// Seguimiento de una atención en curso.
///
/// ## El reloj mentía
///
/// La versión anterior arrancaba con `_secondsLeft = 53` y `_minutesLeft = 15`
/// escritos a mano. No leía `request.etaMinutes` ni `request.startTime`: cada
/// paciente, pidiera lo que pidiera y a la hora que fuera, veía la misma cuenta
/// atrás de 15:53 empezar de cero cada vez que entraba a la pantalla. Encima
/// había **dos relojes que se contradecían**: el círculo pintaba `00:$segundos`
/// —siempre «00:»— y el rótulo de debajo `$minutos min`.
///
/// Un dato inventado en una pantalla de salud no es un detalle de maquetación.
/// La persona que espera a un profesional en su casa organiza la siguiente hora
/// alrededor de ese número.
///
/// Lo que hay ahora sale de los datos reales: `startTime` (la hora a la que se
/// creó la solicitud) más `etaMinutes` da la hora de llegada. Si esa cuenta no
/// se puede hacer —`startTime` viene vacío o ilegible— **no se inventa un
/// reloj**: se dice «Llega en unos 45 minutos» y se acabó.
///
/// Y se refresca cada 30 segundos, no cada segundo. Una cuenta atrás al segundo
/// sobre una espera de 45 minutos es teatro: no aporta precisión y mantiene la
/// pantalla redibujándose.
///
/// ## Lo demás que se quitó
///
/// - «El vehículo clínico se desplaza por autopista principal. Tránsito
///   fluido.» — texto fijo, no venía de ningún dato de tráfico.
/// - «Pago Confirmado» se pintaba siempre, hubiera pago confirmado o no.
/// - «Evaluación en progreso. Complete el registro si requiere reembolso
///   aseguradora.» — no existe ningún registro que completar.
/// - Ocho bloques apilados pasan a cuatro, con el detalle plegado.
class ActiveTrackingScreen extends StatefulWidget {
  final AppState state;
  final ServiceRequest request;
  final Dependent? dependent;
  final VoidCallback onNavigateToChat;

  const ActiveTrackingScreen({
    super.key,
    required this.state,
    required this.request,
    this.dependent,
    required this.onNavigateToChat,
  });

  @override
  State<ActiveTrackingScreen> createState() => _ActiveTrackingScreenState();
}

class _ActiveTrackingScreenState extends State<ActiveTrackingScreen> {
  AppPalette get p => context.palette;

  /// Solo redibuja el tiempo restante. No cuenta nada por su cuenta: la fuente
  /// es siempre `_arrivalAt`, así que salir de la app y volver da el número
  /// correcto en vez de reanudar una cuenta congelada.
  Timer? _ticker;

  int _selectedRating = 0;
  final TextEditingController _ratingFeedbackCtrl = TextEditingController();
  bool _ratingSubmitted = false;
  bool _submittingRating = false;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(seconds: 30),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ratingFeedbackCtrl.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ tiempo

  /// Hora de llegada estimada, o `null` si no se puede calcular honestamente.
  ///
  /// `startTime` llega como `'HH:mm'`, sin fecha. Se combina con el día de hoy;
  /// si eso da una hora en el futuro lejano, la solicitud se creó antes de
  /// medianoche y hay que restar un día.
  DateTime? get _arrivalAt {
    final raw = widget.request.startTime.trim();
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw);
    if (match == null) return null;

    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null || hour > 23 || minute > 59) return null;

    final now = DateTime.now();
    var start = DateTime(now.year, now.month, now.day, hour, minute);
    if (start.isAfter(now.add(const Duration(hours: 2)))) {
      start = start.subtract(const Duration(days: 1));
    }
    return start.add(Duration(minutes: widget.request.etaMinutes));
  }

  /// Minutos que faltan. Negativo significa que ya se pasó la estimación, y eso
  /// se dice —«Está por llegar»— en vez de pintar un número en rojo.
  int? get _minutesLeft {
    final arrival = _arrivalAt;
    if (arrival == null) return null;
    return arrival.difference(DateTime.now()).inMinutes;
  }

  bool get _isOnTheWay =>
      widget.request.status == RequestStatus.pending ||
      widget.request.status == RequestStatus.accepted ||
      widget.request.status == RequestStatus.enCamino;

  bool get _isFinished =>
      widget.request.status == RequestStatus.completed ||
      widget.request.currentStep >= 4;

  // -------------------------------------------------------------- profesional

  /// Identidad de quien atiende, tomada de la propia solicitud.
  ///
  /// Devuelve null mientras nadie la ha tomado. Deliberadamente no hay un valor
  /// de relleno: darle a un paciente el nombre y el teléfono de alguien que no
  /// va a ir a su casa es peor que decir «asignando».
  ({String name, String specialty, String phone})? get _professional {
    final r = widget.request;
    if (r.professionalName != null && r.professionalName!.isNotEmpty) {
      return (
        name: r.professionalName!,
        specialty: r.professionalSpecialty ?? '',
        phone: r.professionalPhone ?? '',
      );
    }
    final simulated = widget.state.assignedProfessionalName;
    if (simulated != null && simulated.isNotEmpty) {
      return (
        name: simulated,
        specialty: widget.state.assignedProfessionalSpecialty ?? '',
        phone: widget.state.assignedProfessionalPhone ?? '',
      );
    }
    return null;
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No pudimos abrir el teléfono. Marca $phone.')),
      );
    }
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final active = widget.state.activeRequests
        .where((r) =>
            r.status != RequestStatus.completed &&
            r.status != RequestStatus.cancelled)
        .toList();

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
              // Cambiar entre atenciones simultáneas. `selectChatRequest`
              // mueve también `currentRequest`, así que esto cambia de verdad
              // toda la pantalla, no solo el hilo del chat.
              if (active.length > 1) ...[
                _ServiceSwitcher(
                  state: widget.state,
                  active: active,
                  currentId: request.id,
                ),
                const SizedBox(height: AuraSpace.lg),
              ],

              _StatusCard(
                request: request,
                minutesLeft: _minutesLeft,
                arrivalAt: _arrivalAt,
                showCountdown: _isOnTheWay,
              ),
              const SizedBox(height: AuraSpace.md),

              if (!_isFinished) _professionalBlock(),

              const SizedBox(height: AuraSpace.md),
              ClipRRect(
                borderRadius: AuraRadius.allLg,
                child: TrackingMap(
                  addressText: request.addressText,
                  patientLat: request.patientLat,
                  patientLng: request.patientLng,
                  professionalLat: request.professionalLat,
                  professionalLng: request.professionalLng,
                  height: 200,
                ),
              ),

              const SizedBox(height: AuraSpace.md),
              _Timeline(step: request.currentStep),

              const SizedBox(height: AuraSpace.md),
              _detailsBlock(request),

              const SizedBox(height: AuraSpace.xl),
              if (_isFinished)
                _ratingBlock(request)
              else
                _cancelBlock(),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------- profesional UI

  Widget _professionalBlock() {
    final prof = _professional;

    if (prof == null) {
      return AuraCard(
        child: Row(
          children: [
            SizedBox(
              height: AuraIcon.md,
              width: AuraIcon.md,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: p.accent),
            ),
            const SizedBox(width: AuraSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Buscando a quien te atienda',
                    style: AppType.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: p.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AuraSpace.xxxs),
                  Text(
                    'Avisamos a los profesionales de tu zona. Te lo confirmamos aquí.',
                    style: AppType.bodySmall.copyWith(color: p.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final profile = widget.request.professionalProfile;

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: p.accentSurface,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    prof.name.isNotEmpty ? prof.name[0].toUpperCase() : '?',
                    style: AppType.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: p.accentText,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AuraSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prof.name,
                      style: AppType.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: p.textPrimary,
                      ),
                    ),
                    if (prof.specialty.isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.xxxs),
                      Text(
                        prof.specialty,
                        style: AppType.bodySmall.copyWith(color: p.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          if (profile != null) ...[
            const SizedBox(height: AuraSpace.xs),
            AuraButton.tertiary(
              label: 'Ver su ficha profesional',
              icon: Icons.badge_outlined,
              onPressed: () => DoctorProfileScreen.showModal(
                context,
                profile,
                phone: prof.phone.isEmpty ? null : prof.phone,
              ),
            ),
          ],

          const SizedBox(height: AuraSpace.md),
          // Escribir es la vía principal: queda registro, sobrevive a que
          // cierres la app y el contador de no leídos lo cuenta. Llamar es la
          // alternativa, no la acción de igual peso que era antes.
          AuraButton(
            label: 'Escribir un mensaje',
            icon: Icons.chat_bubble_rounded,
            kind: AuraButtonKind.primary,
            size: AuraButtonSize.medium,
            onPressed: widget.onNavigateToChat,
          ),
          if (prof.phone.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.xs),
            AuraButton.secondary(
              label: 'Llamar por teléfono',
              icon: Icons.call_rounded,
              onPressed: () => _call(prof.phone),
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------ detalle

  Widget _detailsBlock(ServiceRequest request) {
    final patientName = widget.dependent?.name ??
        (widget.state.userName.trim().isEmpty
            ? 'Tú'
            : widget.state.userName.trim());

    return AuraCard(
      outlined: true,
      padding: const EdgeInsets.symmetric(horizontal: AuraSpace.xs),
      child: AuraDisclosure(
        title: 'Detalle de la atención',
        icon: Icons.receipt_long_rounded,
        child: Column(
          children: [
            AuraSummaryRow(label: 'Paciente', value: patientName),
            AuraSummaryRow(label: 'Dirección', value: request.addressText),
            if (request.symptomsDescription != null &&
                request.symptomsDescription!.isNotEmpty)
              AuraSummaryRow(
                label: 'Motivo',
                value: request.symptomsDescription!,
              ),
            AuraSummaryRow(
              label: 'Total',
              value: Money.format(request.finalPrice, withCode: true),
              strong: true,
            ),
            // La insignia de pago solo aparece cuando el pago está realmente
            // aprobado. Antes se pintaba «Pago Confirmado» siempre, incluso
            // sobre una solicitud que estaba esperando el cobro.
            if (request.paymentStatus == 'approved') ...[
              const SizedBox(height: AuraSpace.xs),
              const Align(
                alignment: Alignment.centerLeft,
                child: AuraBadge(
                  label: 'Pago confirmado',
                  tone: AuraTone.success,
                  icon: Icons.verified_rounded,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ cancelar

  Widget _cancelBlock() {
    return AuraButton.tertiary(
      label: 'Cancelar esta atención',
      onPressed: _cancelling ? null : _confirmCancel,
      expand: true,
    );
  }

  Future<void> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar esta atención?'),
        content: const Text(
          'El profesional dejará de venir. Si ya pagaste, te contactamos para '
          'devolverte el dinero.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No, mantenerla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: p.error),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _cancelling = true);
    await widget.state.cancelRequest();
    if (mounted) setState(() => _cancelling = false);
  }

  // ----------------------------------------------------------- calificación

  Widget _ratingBlock(ServiceRequest request) {
    if (_ratingSubmitted) {
      return AuraSuccessState(
        title: 'Gracias',
        message: 'Tu opinión nos ayuda a elegir mejor a quién te enviamos.',
        primaryLabel: 'Volver al inicio',
        onPrimary: () {
          widget.state.completeSimulation();
          widget.state.setTab('home');
        },
      );
    }

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¿Cómo fue la atención?',
            style: AppType.titleSmall.copyWith(
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: AuraSpace.sm),
          Row(
            children: List.generate(5, (i) {
              final value = i + 1;
              final filled = _selectedRating >= value;
              return AuraIconButton(
                icon: filled ? Icons.star_rounded : Icons.star_outline_rounded,
                tooltip: '$value ${value == 1 ? "estrella" : "estrellas"}',
                color: filled ? p.warning : p.borderStrong,
                size: AuraIcon.lg,
                onPressed: () => setState(() => _selectedRating = value),
              );
            }),
          ),
          const SizedBox(height: AuraSpace.sm),
          AuraField.multiline(
            label: 'Cuéntanos algo más (opcional)',
            hint: 'Lo que quieras contarnos',
            controller: _ratingFeedbackCtrl,
            maxLines: 3,
            maxLength: 300,
          ),
          const SizedBox(height: AuraSpace.md),
          AuraButton.primary(
            label: 'Enviar mi opinión',
            size: AuraButtonSize.medium,
            loading: _submittingRating,
            // Deshabilitado hasta elegir estrellas: antes arrancaba en 5 y
            // enviar sin tocar nada registraba un cinco que nadie dio.
            onPressed: _selectedRating == 0 ? null : () => _submitRating(request),
          ),
          const SizedBox(height: AuraSpace.xxs),
          AuraButton.tertiary(
            label: 'Ahora no',
            expand: true,
            onPressed: () {
              widget.state.completeSimulation();
              widget.state.setTab('home');
            },
          ),
        ],
      ),
    );
  }

  Future<void> _submitRating(ServiceRequest request) async {
    setState(() => _submittingRating = true);
    final error = await widget.state.submitRating(
      bookingId: request.id,
      rating: _selectedRating,
      feedback: _ratingFeedbackCtrl.text.trim().isEmpty
          ? null
          : _ratingFeedbackCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _submittingRating = false;
      _ratingSubmitted = error == null;
    });
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: p.error,
        ),
      );
    }
  }
}

// ====================================================================== piezas

/// La tarjeta que responde «¿qué está pasando y cuándo llega?».
///
/// Es lo primero y lo más grande porque es lo único que la persona vino a ver.
class _StatusCard extends StatelessWidget {
  final ServiceRequest request;
  final int? minutesLeft;
  final DateTime? arrivalAt;
  final bool showCountdown;

  const _StatusCard({
    required this.request,
    required this.minutesLeft,
    required this.arrivalAt,
    required this.showCountdown,
  });

  /// El texto del tiempo, con las tres situaciones posibles resueltas.
  ///
  /// Devuelve `null` cuando no hay nada honesto que decir, y entonces la
  /// tarjeta simplemente no enseña un tiempo.
  String? _timeText() {
    if (!showCountdown) return null;

    final left = minutesLeft;
    if (left == null) {
      // No se pudo reconstruir la hora de inicio. Se dice la estimación
      // original y no se finge una cuenta atrás.
      return request.etaMinutes > 0
          ? 'Llega en unos ${request.etaMinutes} minutos'
          : null;
    }
    if (left <= 0) return 'Está por llegar';
    if (left < 60) return 'Llega en unos $left minutos';

    final hours = left ~/ 60;
    final minutes = left % 60;
    return minutes == 0
        ? 'Llega en unas $hours ${hours == 1 ? "hora" : "horas"}'
        : 'Llega en unas $hours h $minutes min';
  }

  String? _arrivalClock() {
    final a = arrivalAt;
    if (a == null || !showCountdown) return null;
    final hh = a.hour.toString().padLeft(2, '0');
    final mm = a.minute.toString().padLeft(2, '0');
    return 'Alrededor de las $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final time = _timeText();
    final clock = _arrivalClock();

    return AuraCard(
      emphasis: true,
      padding: const EdgeInsets.all(AuraSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                serviceIconFor('', serviceId: request.serviceId),
                color: p.onBrandDeep,
                size: AuraIcon.md,
              ),
              const SizedBox(width: AuraSpace.xs),
              Expanded(
                child: Text(
                  serviceShortName(request.serviceId, 'Tu atención'),
                  style: AppType.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: p.onBrandDeep.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.sm),
          Semantics(
            liveRegion: true,
            child: Text(
              request.status.label,
              style: AppType.titleLarge.copyWith(
                fontWeight: FontWeight.w800,
                color: p.onBrandDeep,
              ),
            ),
          ),
          if (time != null) ...[
            const SizedBox(height: AuraSpace.xs),
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: AuraIcon.sm,
                  color: p.onBrandDeep.withValues(alpha: 0.85),
                ),
                const SizedBox(width: AuraSpace.xxs),
                Expanded(
                  child: Text(
                    time,
                    style: AppType.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: p.onBrandDeep,
                    ),
                  ),
                ),
              ],
            ),
            if (clock != null) ...[
              const SizedBox(height: AuraSpace.xxxs),
              Padding(
                padding: const EdgeInsets.only(left: AuraIcon.sm + AuraSpace.xxs),
                child: Text(
                  clock,
                  style: AppType.bodySmall.copyWith(
                    color: p.onBrandDeep.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Selector entre atenciones simultáneas.
class _ServiceSwitcher extends StatelessWidget {
  final AppState state;
  final List<ServiceRequest> active;
  final String currentId;

  const _ServiceSwitcher({
    required this.state,
    required this.active,
    required this.currentId,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tienes ${active.length} atenciones en curso',
          style: AppType.bodySmall.copyWith(
            fontWeight: FontWeight.w700,
            color: p.textSecondary,
          ),
        ),
        const SizedBox(height: AuraSpace.xs),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: active.map((r) {
              final selected = r.id == currentId;
              final unread = state.unreadFor(r.id);
              return Padding(
                padding: const EdgeInsets.only(right: AuraTap.gap),
                child: Semantics(
                  button: true,
                  selected: selected,
                  label: unread > 0
                      ? '${serviceShortName(r.serviceId, "Atención")}, $unread mensajes sin leer'
                      : serviceShortName(r.serviceId, 'Atención'),
                  child: ExcludeSemantics(
                    child: Material(
                      color: selected ? p.accent : p.card,
                      borderRadius: AuraRadius.allSm,
                      child: InkWell(
                        onTap: () => state.selectChatRequest(r.id),
                        borderRadius: AuraRadius.allSm,
                        child: Container(
                          constraints: const BoxConstraints(
                            minHeight: AuraTap.min,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AuraSpace.sm,
                            vertical: AuraSpace.xs,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: AuraRadius.allSm,
                            border: Border.all(
                              color: selected ? p.accent : p.borderStrong,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                serviceIconFor('', serviceId: r.serviceId),
                                size: AuraIcon.sm,
                                color: selected
                                    ? context.scheme.onPrimary
                                    : p.textSecondary,
                              ),
                              const SizedBox(width: AuraSpace.xxs),
                              Text(
                                serviceShortName(r.serviceId, 'Atención'),
                                style: AppType.bodySmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? context.scheme.onPrimary
                                      : p.textPrimary,
                                ),
                              ),
                              if (unread > 0) ...[
                                const SizedBox(width: AuraSpace.xxs),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: p.error,
                                    borderRadius: AuraRadius.allPill,
                                  ),
                                  child: Text(
                                    '$unread',
                                    style: AppType.label.copyWith(
                                      color: context.scheme.onError,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

/// Los cinco pasos de una atención.
///
/// El paso actual se ve; los ya pasados quedan marcados y en gris; los que
/// faltan, apagados. Antes los cinco pesaban igual y había que leerlos todos
/// para saber en cuál se estaba.
class _Timeline extends StatelessWidget {
  final int step;
  const _Timeline({required this.step});

  static const _steps = [
    (label: 'Solicitud enviada', icon: Icons.check_rounded),
    (label: 'Profesional asignado', icon: Icons.person_rounded),
    (label: 'En camino', icon: Icons.directions_car_rounded),
    (label: 'En tu domicilio', icon: Icons.home_rounded),
    (label: 'Atención terminada', icon: Icons.verified_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(_steps.length, (i) {
          final s = _steps[i];
          final done = i < step;
          final current = i == step;
          final color = done
              ? p.success
              : (current ? p.accent : p.borderStrong);

          return Semantics(
            label: '${s.label}. '
                '${done ? "Completado" : (current ? "En curso" : "Pendiente")}',
            child: ExcludeSemantics(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: i == _steps.length - 1 ? 0 : AuraSpace.sm,
                ),
                child: Row(
                  children: [
                    Container(
                      height: 32,
                      width: 32,
                      decoration: BoxDecoration(
                        color: done
                            ? p.successSurface
                            : (current ? p.accentSurface : p.fill),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        done ? Icons.check_rounded : s.icon,
                        size: AuraIcon.sm,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: AuraSpace.sm),
                    Expanded(
                      child: Text(
                        s.label,
                        style: AppType.bodyMedium.copyWith(
                          fontWeight:
                              current ? FontWeight.w700 : FontWeight.w400,
                          color: current
                              ? p.textPrimary
                              : (done ? p.textSecondary : p.textMuted),
                        ),
                      ),
                    ),
                    // El estado no depende solo del color: el paso en curso lo
                    // dice con palabras.
                    if (current)
                      const AuraBadge(label: 'Ahora', tone: AuraTone.info),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
