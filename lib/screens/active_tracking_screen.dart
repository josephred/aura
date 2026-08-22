import 'dart:async';
import 'package:aura/theme/app_theme.dart';
import 'package:flutter/material.dart';
import '../utils/money.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/dependent.dart';
import '../models/service_request.dart';
import '../state/app_state.dart';
import '../widgets/tracking_map.dart';
import 'doctor_profile_screen.dart';

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
  Timer? _timer;
  int _secondsLeft = 53;
  int _minutesLeft = 15;

  int _selectedRating = 5;
  final TextEditingController _ratingFeedbackCtrl = TextEditingController();
  bool _ratingSubmitted = false;
  bool _submittingRating = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void didUpdateWidget(covariant ActiveTrackingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.simulationSpeed != widget.state.simulationSpeed) {
      _startCountdown();
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    final intervalMs = (1000 / widget.state.simulationSpeed).round();
    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
      if (mounted) {
        setState(() {
          if (_secondsLeft > 1) {
            _secondsLeft--;
          } else {
            if (_minutesLeft > 0) {
              _minutesLeft--;
              _secondsLeft = 59;
            } else {
              _secondsLeft = 0;
              _timer?.cancel();
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Identity of the professional attending, taken from the request itself.
  ///
  /// Returns null while nobody has taken the request yet. There is deliberately
  /// no placeholder: telling the patient a name and a phone number for someone
  /// who is not coming to their home is worse than saying "still assigning".
  Map<String, String>? _getAssignedProfessional() {
    final request = widget.request;

    // The backend sends the real identity in `assigned_professional`.
    if (request.professionalName != null && request.professionalName!.isNotEmpty) {
      return {
        'name': request.professionalName!,
        'specialty': request.professionalSpecialty ?? '',
        'phone': request.professionalPhone ?? '',
      };
    }

    // Offline fallback simulation keeps its own copy in app state.
    final simulatedName = widget.state.assignedProfessionalName;
    if (simulatedName != null && simulatedName.isNotEmpty) {
      return {
        'name': simulatedName,
        'specialty': widget.state.assignedProfessionalSpecialty ?? '',
        'phone': widget.state.assignedProfessionalPhone ?? '',
      };
    }

    return null;
  }

  /// Shown while the request sits in the zone queue and nobody has taken it.
  Widget _buildAwaitingProfessionalCard() {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: p.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Asignando profesional',
                  style: AppType.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: p.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Tu solicitud está en la cola de tu sector. Te mostraremos '
                  'quién te atenderá apenas la tome un prestador en turno.',
                  style: AppType.bodySmall.copyWith( color: p.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final request = widget.request;
    final prof = _getAssignedProfessional();

    final steps = [
      {
        'title': 'Solicitado',
        'desc': 'En cola de tu zona, a la espera del próximo prestador en turno',
      },
      {
        'title': 'Confirmado',
        'desc': 'Personal clínico asignado y preparando insumos',
      },
      {
        'title': 'En Camino',
        'desc': 'Profesional viaja en dirección a su domicilio',
      },
      {
        'title': 'En Atención',
        'desc': 'Servicio clínico iniciándose en su hogar',
      },
      {'title': 'Completado', 'desc': 'Prestación realizada con éxito'},
    ];

    final isNotFinished =
        request.status != RequestStatus.completed &&
        request.status != RequestStatus.cancelled;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header tracking row. The service status now advances only from the
          // real professional's actions on the doctor portal, streamed here via
          // SSE — there is no client-side "advance" shortcut.
          Row(
            children: [
              Container(
                height: 10,
                width: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981), // emerald-500
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                'Seguimiento Clínico',
                style: AppType.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: p.textPrimary,
                ),
              ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Main Countdown target card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              // Intentionally always-dark branded card (light content sits on it
              // in both themes), so it must NOT follow the text/background token.
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              children: [
                // Top stripe gradient indicator
                Container(
                  height: 3,
                  width: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF2DD4BF),
                        Color(0xFF10B981),
                        p.accent,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 14),
                // Soft notice banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: p.textSecondary.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFF99F6E4),
                        size: 18,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ESTADO DEL TRASLADO / ATENCIÓN',
                              style: AppType.label.copyWith(
                                color: Color(0xFF2DD4BF),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Evaluación en progreso. Complete el registro si requiere reembolso aseguradora.',
                              style: AppType.bodySmall.copyWith(
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Timer circular display
                Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFF090D16),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: p.accent,
                      width: 3,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.access_time,
                          color: p.accent,
                          size: 14,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '00:${_secondsLeft < 10 ? '0$_secondsLeft' : _secondsLeft}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'TIEMPO ESPERADO DE DEMORA',
                  style: AppType.label.copyWith(
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_minutesLeft min',
                  style: AppType.titleLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                // Payment summary
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF334155).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'VALOR DE LA PRESTACIÓN',
                            style: AppType.bodySmall.copyWith(
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            Money.format(request.finalPrice, withCode: true),
                            style: AppType.bodyLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF0F766E,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(
                              0xFF0F766E,
                            ).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.shield_rounded,
                              color: Color(0xFF2DD4BF),
                              size: 12,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Pago Confirmado',
                              style: AppType.bodySmall.copyWith(
                                color: Color(0xFF2DD4BF),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Live route tracking. Despite the old name, this has never been a
          // mock: it wraps the real TrackingMap (OSM tiles + OSRM route + the
          // professional's live GPS) with a status header.
          if (request.currentStep >= 1 &&
              request.status != RequestStatus.cancelled) ...[
            _buildTrackingSection(request.currentStep, request.serviceId),
            const SizedBox(height: 16),
          ],

          // Professional assigned details — only once somebody has actually
          // taken the request. While `prof` is null the placeholder below
          // explains that the zone queue is still looking for someone.
          if (request.currentStep >= 1 &&
              request.status != RequestStatus.cancelled &&
              prof == null) ...[
            _buildAwaitingProfessionalCard(),
            const SizedBox(height: 16),
          ],

          if (request.currentStep >= 1 &&
              request.status != RequestStatus.cancelled &&
              prof != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: p.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: p.accentSurface,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'PROFESIONAL CLÍNICO ASIGNADO',
                              style: AppType.label.copyWith(
                                color: p.accent,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            prof['name']!,
                            style: AppType.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: p.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            prof['specialty']!,
                            style: AppType.bodySmall.copyWith(
                              color: p.textMuted,
                            ),
                          ),
                          // B.3 — el paciente puede conocer la experiencia y el
                          // registro de quien va a entrar a su casa, antes de
                          // que llegue. Solo aparece con datos del servidor: en
                          // el modo de respaldo local no hay ficha que mostrar.
                          if (request.professionalProfile != null) ...[
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () => DoctorProfileScreen.showModal(
                                context,
                                request.professionalProfile!,
                                phone: request.professionalPhone,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.badge_outlined,
                                      size: 13, color: p.accent),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Ver ficha profesional',
                                    style: AppType.bodySmall.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: p.accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          color: p.accentSurface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person,
                          color: p.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: ElevatedButton(
                            onPressed: widget.onNavigateToChat,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: p.accentSurface,
                              foregroundColor: p.accent,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 14,
                                ),
                                SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                  'Chatear',
                                  style: AppType.bodySmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: ElevatedButton(
                            onPressed: () async {
                              final Uri launchUri = Uri(
                                scheme: 'tel',
                                path: prof['phone']!,
                              );
                              try {
                                if (await canLaunchUrl(launchUri)) {
                                  await launchUrl(launchUri);
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'No se pudo abrir el marcador telefónico para llamar al ${prof['phone']!}',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Error al intentar realizar la llamada: $e',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: p.fill,
                              foregroundColor: const Color(0xFF475569),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.phone_outlined, size: 14),
                                SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                  'Llamar',
                                  style: AppType.bodySmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Steps timeline
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: p.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PROGRESO DEL SERVICIO',
                  style: AppType.label.copyWith(
                    fontWeight: FontWeight.bold,
                    color: p.textFaint,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: steps.length,
                  itemBuilder: (context, idx) {
                    final step = steps[idx];
                    final isCompleted = request.currentStep >= idx;
                    final isCurrent = request.currentStep == idx;

                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Vertical line + marker
                          Column(
                            children: [
                              Container(
                                height: 14,
                                width: 14,
                                decoration: BoxDecoration(
                                  color: isCompleted
                                      ? p.accent
                                      : Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isCompleted
                                        ? p.accent
                                        : p.borderStrong,
                                    width: 2,
                                  ),
                                ),
                                child: isCompleted
                                    ? Center(
                                        child: Icon(
                                          Icons.check,
                                          color: p.card,
                                          size: 8,
                                        ),
                                      )
                                    : null,
                              ),
                              if (idx < steps.length - 1)
                                Expanded(
                                  child: Container(
                                    width: 2,
                                    color: isCompleted
                                        ? p.accent
                                        : p.border,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 18.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                        step['title']!,
                                        style: AppType.bodySmall.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: isCurrent
                                              ? p.textPrimary
                                              : (isCompleted
                                                    ? p.textSecondary
                                                    : p.textFaint),
                                        ),
                                      ),
                                      ),
                                      if (isCurrent) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 1.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: p.accentSurface,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            'ACTUAL',
                                            style: AppType.bodySmall.copyWith(
                                              color: p.accent,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    step['desc']!,
                                    style: AppType.bodySmall.copyWith(
                                      color: p.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Metadata block
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: p.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DETALLES DE LA CITA',
                  style: AppType.label.copyWith(
                    fontWeight: FontWeight.bold,
                    color: p.textFaint,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.person,
                      color: Color(0xFF10B981),
                      size: 16,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PACIENTE',
                            style: AppType.bodySmall.copyWith(
                              color: p.textFaint,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.dependent != null
                                ? '${widget.dependent!.name} (${widget.dependent!.relationship})'
                                : 'Usuario Principal',
                            style: AppType.bodySmall.copyWith(
                              fontWeight: FontWeight.bold,
                              color: p.textSecondary,
                            ),
                          ),
                          if (widget.dependent != null)
                            Text(
                              widget.dependent!.medicalConditions,
                              style: AppType.bodySmall.copyWith(
                                color: p.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                Divider(height: 20, color: p.fill),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Color(0xFFF43F5E),
                      size: 16,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DOMICILIO',
                            style: AppType.bodySmall.copyWith(
                              color: p.textFaint,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            request.addressText,
                            style: AppType.bodySmall.copyWith(
                              fontWeight: FontWeight.bold,
                              color: p.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Cancel or Finish buttons
          if (isNotFinished)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Cancelar Solicitud'),
                      content: const Text(
                        '¿Está seguro de querer cancelar esta solicitud de atención clínica? Se podría aplicar un recargo por respuesta técnica si el profesional ya va en camino.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Volver'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            widget.state.cancelRequest();
                          },
                          child: const Text(
                            'Cancelar Servicio',
                            style: TextStyle(color: Color(0xFFF43F5E)),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF43F5E).withValues(alpha: 0.12),
                  foregroundColor: const Color(0xFFE11D48),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: const Color(0xFFF43F5E).withValues(alpha: 0.25),
                    ),
                  ),
                ),
                child: Text(
                  'Cancelar Solicitud de Servicio',
                  style: AppType.bodySmall.copyWith(fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          else ...[
            _buildRatingSection(context, widget.request),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  widget.state.completeSimulation();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: p.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Volver al inicio',
                  style: AppType.bodySmall.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildRatingSection(BuildContext context, ServiceRequest request) {
    final prof = _getAssignedProfessional();
    final profName = prof?['name'] ?? 'el profesional';

    if (_ratingSubmitted) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¡Gracias por tu evaluación!',
                    style: AppType.bodySmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF166534),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: List.generate(
                      5,
                      (i) => Icon(
                        i < _selectedRating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Califica la atención de $profName',
            style: AppType.titleSmall.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Tu opinión ayuda a mantener la calidad y excelencia de Aura.',
            style: AppType.bodySmall.copyWith(color: p.textMuted),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starNumber = index + 1;
              return IconButton(
                onPressed: () {
                  setState(() {
                    _selectedRating = starNumber;
                  });
                },
                icon: Icon(
                  starNumber <= _selectedRating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 32,
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _ratingFeedbackCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Comentario u observaciones (opcional)...',
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: p.border),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submittingRating
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      setState(() {
                        _submittingRating = true;
                      });
                      final error = await widget.state.submitRating(
                        bookingId: request.id,
                        rating: _selectedRating,
                        feedback: _ratingFeedbackCtrl.text.trim(),
                      );
                      if (mounted) {
                        setState(() {
                          _submittingRating = false;
                          if (error == null) {
                            _ratingSubmitted = true;
                          }
                        });
                        if (error != null) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(error),
                              backgroundColor: const Color(0xFFDC2626),
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _submittingRating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Enviar calificación',
                      style: AppType.button.copyWith(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Status header around the live [TrackingMap].
  Widget _buildTrackingSection(int step, String serviceId) {
    String statusText = 'Preparando insumos clínicos';
    if (step == 2) {
      statusText = 'Vehículo de asistencia en trayecto';
    } else if (step == 3) {
      statusText = 'Especialista en su domicilio';
    } else if (step >= 4) {
      statusText = 'Atención médica finalizada';
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SEGUIMIENTO EN TIEMPO REAL',
                      style: AppType.label.copyWith(
                        fontWeight: FontWeight.bold,
                        color: p.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statusText,
                      style: AppType.bodySmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: p.textPrimary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: p.accentSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        serviceId == 'ambulancia'
                            ? Icons.local_shipping
                            : Icons.directions_run,
                        color: p.accentText,
                        size: 11,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'GPS ACTIVO',
                        style: AppType.bodySmall.copyWith(
                          color: p.accentText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Real OpenStreetMap tracking: patient home + live professional GPS
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: p.border),
                bottom: BorderSide(color: p.border),
              ),
            ),
            child: TrackingMap(
              addressText: widget.request.addressText,
              patientLat: widget.request.patientLat,
              patientLng: widget.request.patientLng,
              professionalLat: widget.request.professionalLat,
              professionalLng: widget.request.professionalLng,
              height: 180,
            ),
          ),

          // Footer
          if (step == 2)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: p.accent,
                    size: 12,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'El vehículo clínico se desplaza por autopista principal. Tránsito fluido.',
                      style: AppType.bodySmall.copyWith(
                        color: p.accent.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
