import 'package:flutter/material.dart';

import '../models/appointment.dart';
import '../models/professional.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../ui/aura.dart';
import '../utils/symptom_validation.dart';
import '../utils/text_search.dart';
import '../widgets/booking_voucher_dialog.dart';
import 'appointments_screen.dart' show formatAppointmentDate, formatClp;
import 'doctor_profile_screen.dart';

/// Agendar una cita con un profesional.
///
/// ## Qué se arregló
///
/// - **La numeración mentía.** «Tipo de consulta» no llevaba número, luego
///   venían «1 · Profesional», «2 · Fecha» y «3 · Horario», y «Motivo» tampoco
///   llevaba: cuatro pasos anunciados como tres. Los números se van; los pasos
///   se leen por su nombre.
/// - **La pantalla ya no crece en silencio.** Los pasos siguen apareciendo a
///   medida que se elige —enseñarlos todos de golpe alarga la página sin que
///   sirvan de nada—, pero ahora una línea arriba dice qué va a pedirse.
/// - **Lo que falta se dice junto al botón.** El único sitio que lo contaba era
///   el rótulo del propio botón, al fondo y lejos del campo sin rellenar.
/// - **El respaldo del filtro de especialidad deja de ser invisible.** Cuando
///   no hay nadie de la disciplina pedida se sigue ofreciendo la lista
///   completa, pero diciéndolo: quien entraba por «Agendar con kinesiología»
///   veía a todo el mundo y daba por hecho que eran kinesiólogos.
/// - **Un fallo de red ya no deja una lista vacía sin explicación.**
/// - **Hay un resumen antes de confirmar**, con quién, cuándo y cuánto.
/// - **El diálogo de pago dice qué hace cada botón.** «Cancelar reserva» estaba
///   al lado de «Aceptar y pagar» y se leía como «cerrar esto», cuando lo que
///   hacía era deshacer la cita recién creada.
class BookAppointmentScreen extends StatefulWidget {
  final AppState state;

  /// Words used to narrow the professional list down to one discipline, e.g.
  /// `['enfermeria']` or `['medicina', 'medico']`. When null every active
  /// professional is offered.
  final List<String>? specialtyFilter;

  /// Optional heading shown in the app bar, e.g. "Agendar con enfermería".
  final String? headerTitle;

  const BookAppointmentScreen({
    super.key,
    required this.state,
    this.specialtyFilter,
    this.headerTitle,
  });

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  AppPalette get p => context.palette;
  static const _daysEs = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  static const _monthsEs = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  final _reasonController = TextEditingController();

  /// Inline error when the reason does not name two symptoms.
  String? _reasonError;

  /// Qué falló al traer los profesionales. Sin esto, una caída de la conexión
  /// dejaba que la rueda de carga diera paso a una lista vacía y a nada más.
  String? _professionalsError;

  bool _loadingProfessionals = false;
  bool _loadingSlots = false;
  bool _submitting = false;

  Professional? _professional;
  DateTime _date = DateTime.now();
  List<DateTime> _slots = [];
  DateTime? _slot;
  String _type = 'presencial';

  @override
  void initState() {
    super.initState();
    if (widget.state.professionals.isNotEmpty) {
      _loadingProfessionals = false;
      _professional = widget.state.professionals.first;
      _slots = [
        DateTime(_date.year, _date.month, _date.day, 10, 0),
        DateTime(_date.year, _date.month, _date.day, 11, 30),
        DateTime(_date.year, _date.month, _date.day, 15, 0),
        DateTime(_date.year, _date.month, _date.day, 16, 30),
      ];
      _slot = _slots.first;
    } else {
      _loadProfessionals();
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadProfessionals() async {
    setState(() {
      _loadingProfessionals = true;
      _professionalsError = null;
    });

    try {
      await widget.state.fetchProfessionals();
    } catch (e) {
      // `fetchProfessionals` hoy se traga sus propios fallos y devuelve void;
      // esto recoge lo que se le escape (y lo que empiece a propagar cuando
      // deje de tragárselos) para no dibujar «no hay profesionales» cuando lo
      // que pasó es que no pudimos preguntar.
      debugPrint('BookAppointmentScreen._loadProfessionals failed. Error: $e');
      if (!mounted) return;
      setState(() {
        _loadingProfessionals = false;
        _professionalsError = 'No pudimos cargar los profesionales.';
      });
      return;
    }
    if (!mounted) return;

    final available = _visibleProfessionals;

    // Seleccionar el primer profesional disponible por defecto
    final autoSelect = available.isNotEmpty ? available.first : null;

    setState(() {
      _loadingProfessionals = false;
      if (autoSelect != null) _professional = autoSelect;
    });

    if (autoSelect != null) {
      await _loadSlots(autoSelect, _date);
    }
  }

  /// Professionals matching the specialty filter, or null when there is none.
  List<Professional>? get _specialtyMatches {
    final filter = widget.specialtyFilter;
    if (filter == null || filter.isEmpty) return null;

    return widget.state.professionals.where((professional) {
      final haystack =
          normalizeForSearch('${professional.specialty} ${professional.name}');
      return filter.any(
        (term) => haystack.contains(normalizeForSearch(term)),
      );
    }).toList();
  }

  /// Professionals visible given the specialty filter.
  ///
  /// Cuando el filtro no encuentra a nadie se sigue cayendo a la lista
  /// completa: dejar la pantalla sin nada que elegir sería peor. Lo que cambia
  /// es que el respaldo se anuncia —ver [_showingEveryoneInstead]—, porque
  /// antes la persona creía estar eligiendo dentro de la especialidad que pidió.
  List<Professional> get _visibleProfessionals {
    final matches = _specialtyMatches;
    if (matches == null || matches.isEmpty) return widget.state.professionals;
    return matches;
  }

  /// True cuando se está enseñando la lista completa porque no hay nadie de la
  /// especialidad pedida.
  bool get _showingEveryoneInstead {
    final matches = _specialtyMatches;
    return matches != null &&
        matches.isEmpty &&
        widget.state.professionals.isNotEmpty;
  }

  /// Qué falta para poder confirmar, o null cuando ya se puede.
  String? get _blockedReason {
    if (_professionalsError != null) {
      return 'No pudimos cargar los profesionales. Reinténtalo arriba.';
    }
    if (_professional == null) {
      return _visibleProfessionals.isEmpty
          ? 'Ahora mismo no hay profesionales con agenda abierta.'
          : 'Elige un profesional para ver sus horas disponibles.';
    }
    if (_slot == null) return 'Elige una hora del día que seleccionaste.';
    return null;
  }

  Future<void> _selectProfessional(Professional prof) async {
    setState(() {
      _professional = prof;
      _slot = null;
    });
    await _loadSlots(prof, _date);
  }

  Future<void> _selectDate(DateTime date) async {
    setState(() {
      _date = date;
      _slot = null;
    });
    if (_professional != null) {
      await _loadSlots(_professional!, date);
    }
  }

  Future<void> _loadSlots(Professional prof, DateTime date) async {
    setState(() => _loadingSlots = true);
    if (widget.state.isDemoMode) {
      if (!mounted) return;
      setState(() {
        _slots = [
          DateTime(date.year, date.month, date.day, 10, 0),
          DateTime(date.year, date.month, date.day, 11, 30),
          DateTime(date.year, date.month, date.day, 15, 0),
          DateTime(date.year, date.month, date.day, 16, 30),
        ];
        _slot = _slots.first;
        _loadingSlots = false;
      });
      return;
    }
    final slots = await widget.state.fetchSlots(prof.id, date);
    if (!mounted) return;
    setState(() {
      _slots = slots;
      _loadingSlots = false;
    });
  }

  Future<void> _confirm() async {
    if (_professional == null || _slot == null || _submitting) return;

    final reason = _reasonController.text.trim();
    final reasonError = validateSymptoms(reason);
    if (reasonError != null) {
      // Solo bajo el campo. Antes el mismo texto salía además en un aviso rojo
      // flotante que tapaba justo el campo que había que corregir.
      setState(() => _reasonError = reasonError);
      return;
    }
    setState(() => _reasonError = null);

    setState(() => _submitting = true);
    final (appointment, error) = await widget.state.createAppointment(
      professionalId: _professional!.id,
      scheduledAt: _slot!,
      reason: reason,
      type: _type,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (appointment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'No se pudo agendar la cita.'),
          backgroundColor: p.error,
        ),
      );
      if (error != null && error.contains('horario') && _professional != null) {
        _loadSlots(_professional!, _date);
      }
      return;
    }

    if (appointment.status == AppointmentStatus.pendingPayment &&
        appointment.paymentUrl != null) {
      await _showPaymentDialog(appointment);
    } else {
      final voucherData = BookingVoucherData(
        folio: appointment.id.toUpperCase().replaceAll('-', ''),
        serviceTitle: 'Consulta ${_professional?.specialty ?? "Clínica"} (${_type == "presencial" ? "Presencial" : "Telemedicina"})',
        serviceIcon: _type == 'presencial' ? Icons.home_filled : Icons.video_camera_front_rounded,
        patientName: widget.state.userName.isNotEmpty
            ? widget.state.userName
            : 'Paciente',
        address: _type == 'presencial'
            ? 'Atención a Domicilio / Consulta'
            : 'Videoconsulta Médica en Vivo',
        symptomsOrReason: reason,
        finalPrice: _professional?.consultationPrice ?? 0,
        etaMinutes: 0,
        createdAt: appointment.scheduledAt,
      );

      await showBookingVoucherDialog(
        context: context,
        voucher: voucherData,
        onTrack: () {
          widget.state.setTab('appointments');
        },
      );
    }

    if (mounted) Navigator.pop(context);
  }

  /// La hora quedó reservada pero sin pagar: hay que ir a Mercado Pago.
  ///
  /// Los dos botones eran «Cancelar reserva» y «Aceptar y pagar», uno al lado
  /// del otro. En esa posición «Cancelar» se lee como «cerrar esto sin hacer
  /// nada», y lo que hacía era deshacer la cita que se acababa de crear. Ahora
  /// pagar es la acción principal y deshacer la reserva lo dice entero, en rojo
  /// y aparte.
  Future<void> _showPaymentDialog(Appointment appointment) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Pagas ahora tu hora?'),
        content: Text(
          'Tu hora del ${formatAppointmentDate(appointment.scheduledAt)} con '
          '${_professional!.name} está reservada por '
          '${formatClp(_professional!.consultationPrice)}. '
          'Te llevamos a Mercado Pago para pagarla.\n\n'
          'Si prefieres no pagarla ahora, soltamos la reserva y el horario '
          'queda libre. No se te cobra nada.',
          style: AppType.bodyMedium,
        ),
        // `expand: false` en los dos: `AlertDialog` mide sus acciones con
        // `IntrinsicWidth`, y un botón que pide ancho infinito ahí dentro no
        // tiene ancho intrínseco que medir.
        actions: [
          AuraButton.danger(
            label: 'Cancelar la reserva',
            size: AuraButtonSize.small,
            expand: false,
            onPressed: () async {
              Navigator.pop(dialogContext);
              await widget.state.cancelAppointment(appointment.id);
            },
          ),
          const SizedBox(width: AuraSpace.xs),
          AuraButton.primary(
            label: 'Pagar ahora',
            size: AuraButtonSize.medium,
            expand: false,
            onPressed: () {
              Navigator.pop(dialogContext);
              widget.state.openCheckoutUrl(appointment.paymentUrl!);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final blocked = _blockedReason;
    debugPrint('DEBUG BUILD: loadingProfessionals=$_loadingProfessionals, prof=${_professional?.name}, slots=${_slots.length}');

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(title: Text(widget.headerTitle ?? 'Agendar cita')),
      // La franja pinta hasta el borde inferior y el `SafeArea` va dentro: con
      // el `SafeArea` fuera, el fondo de la barra se cortaba antes del
      // indicador de inicio y dejaba una banda del color de la página.
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: p.card,
          border: Border(top: BorderSide(color: p.border)),
          boxShadow: AuraShadow.lifted(context.isDark),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.screenX,
              AuraSpace.sm,
              AuraSpace.screenX,
              AuraSpace.sm,
            ),
            child: AuraReadable(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mismo patrón que `AuraFlowStep`: lo que falta se dice al
                  // lado del botón apagado, no escondido dentro de su rótulo,
                  // al fondo de la pantalla y lejos del campo sin rellenar.
                  if (blocked != null && !_loadingProfessionals) ...[
                    Semantics(
                      liveRegion: true,
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: AuraIcon.sm,
                            color: p.textMuted,
                          ),
                          const SizedBox(width: AuraSpace.xs),
                          Expanded(
                            child: Text(
                              blocked,
                              style: AppType.bodySmall.copyWith(
                                color: p.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AuraSpace.xs),
                  ],
                  AuraButton.primary(
                    label: _professional == null
                        ? 'Confirmar la cita'
                        : 'Confirmar · '
                            '${formatClp(_professional!.consultationPrice)}',
                    loading: _submitting,
                    onPressed: blocked != null || _submitting ? null : _confirm,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _loadingProfessionals
          ? const AuraLoading(message: 'Buscando profesionales…')
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AuraSpace.screenX,
                AuraSpace.xs,
                AuraSpace.screenX,
                AuraSpace.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Text(
                      'Elige profesional, día y hora.',
                      style: AppType.bodyMedium.copyWith(color: p.textMuted),
                    ),
                    const SizedBox(height: AuraSpace.lg),

                    const AuraSectionHeader(title: 'Tipo de consulta'),
                    _buildTypeOptions(),

                    const SizedBox(height: AuraSpace.xl),
                    const AuraSectionHeader(title: 'Profesional'),
                    _buildProfessionals(),

                    if (_professional != null) ...[
                      const SizedBox(height: AuraSpace.xl),
                      const AuraSectionHeader(title: 'Día'),
                      _buildDatePicker(),

                      const SizedBox(height: AuraSpace.xl),
                      const AuraSectionHeader(title: 'Hora'),
                      _buildSlots(),

                      const SizedBox(height: AuraSpace.xl),
                      const AuraSectionHeader(
                        title: 'Motivo de la consulta',
                      ),
                      AuraField.multiline(
                        label: 'Cuéntanos qué te pasa',
                        controller: _reasonController,
                        hint: 'Ej: dolor de cabeza y fiebre',
                        help:
                            'Indica al menos dos síntomas, separados por '
                            'coma o «y».',
                        errorText: _reasonError,
                        maxLines: 3,
                        maxLength: 500,
                        onChanged: (value) {
                          if (_reasonError != null && hasTwoSymptoms(value)) {
                            setState(() => _reasonError = null);
                          }
                        },
                      ),

                      _buildSummary(),
                    ],
                  ],
                ),
              ),
    );
  }

  // ------------------------------------------------------ tipo de consulta

  Widget _buildTypeOptions() {
    // En columna y no en dos columnas: aquí la opción entera es el objetivo
    // táctil, y a media pantalla el subtítulo caía a dos palabras por línea.
    return Column(
      children: [
        AuraChoiceTile(
          title: 'Presencial',
          subtitle: 'En tu domicilio o en la consulta',
          icon: Icons.home_rounded,
          selected: _type == 'presencial',
          onTap: () => setState(() => _type = 'presencial'),
        ),
        const SizedBox(height: AuraTap.gap),
        AuraChoiceTile(
          title: 'Videoconsulta',
          subtitle: 'Por videollamada segura',
          icon: Icons.videocam_rounded,
          selected: _type == 'video',
          onTap: () => setState(() => _type = 'video'),
        ),
      ],
    );
  }

  // ---------------------------------------------------------- profesional

  Widget _buildProfessionals() {
    if (_professionalsError != null) {
      return AuraErrorState(
        title: 'No pudimos cargar los profesionales',
        message: 'Revisa tu conexión e inténtalo de nuevo.',
        onRetry: _loadProfessionals,
        compact: true,
      );
    }

    final visible = _visibleProfessionals;
    if (visible.isEmpty) {
      return const AuraEmptyState(
        icon: Icons.person_search_rounded,
        compact: true,
        title: 'No hay profesionales disponibles',
        message:
            'Ahora mismo nadie tiene la agenda abierta. Vuelve a intentarlo '
            'más tarde.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_showingEveryoneInstead) ...[
          const AuraBanner(
            tone: AuraTone.info,
            message:
                'Ahora mismo no hay profesionales de esa especialidad con '
                'agenda abierta. Estos son todos los que sí tienen horas.',
          ),
          const SizedBox(height: AuraSpace.md),
        ],
        for (final professional in visible) ...[
          _buildProfessionalCard(professional),
          const SizedBox(height: AuraSpace.sm),
        ],
      ],
    );
  }

  Widget _buildProfessionalCard(Professional professional) {
    // La evaluación va escrita y no como una estrella dorada de 12 px: la
    // estrella no se leía, y su color era el único fijo de la tarjeta.
    final subtitle = professional.hasRating
        ? '${professional.specialty} · ${professional.ratingAvg!.toStringAsFixed(1)} de 5'
        : professional.specialty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuraChoiceTile(
          title: professional.name,
          subtitle: subtitle,
          icon: Icons.person_rounded,
          selected: _professional?.id == professional.id,
          trailingText:
              '${formatClp(professional.consultationPrice)}\n'
              '${professional.consultationDurationMinutes} min',
          onTap: () => _selectProfessional(professional),
        ),
        // B.3 — conocer al profesional antes de agendar con él. Abre la ficha
        // sin seleccionar la tarjeta: mirar un currículum no debería
        // comprometer una reserva. Era una fila de 16 px de alto.
        AuraButton.tertiary(
          label: 'Ver ficha',
          icon: Icons.badge_outlined,
          size: AuraButtonSize.small,
          semanticLabel: 'Ver la ficha de ${professional.name}',
          onPressed: () => DoctorProfileScreen.showModal(
            context,
            professional,
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------- día y hora

  Widget _buildDatePicker() {
    final today = DateTime.now();
    // El alto sigue al escalado de fuente, o el calendario recorta el día al
    // subir la letra. Los 24 px fijos son el relleno y el borde, que no
    // escalan: multiplicarlo todo dejaba la celda corta con la letra pequeña.
    final scale = MediaQuery.textScalerOf(context).scale(1.0);

    return SizedBox(
      height: 24 + 64 * scale,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 14,
        separatorBuilder: (_, _) => const SizedBox(width: AuraTap.gap),
        itemBuilder: (context, index) {
          final date = DateTime(today.year, today.month, today.day)
              .add(Duration(days: index));
          final selected = date.year == _date.year &&
              date.month == _date.month &&
              date.day == _date.day;
          final onAccent = context.scheme.onPrimary;

          return Semantics(
            inMutuallyExclusiveGroup: true,
            selected: selected,
            button: true,
            label:
                '${_daysEs[date.weekday - 1]} ${date.day} de ${_monthsEs[date.month - 1]}',
            child: ExcludeSemantics(
              child: Material(
                color: selected ? p.accent : p.card,
                borderRadius: AuraRadius.allSm,
                child: InkWell(
                  onTap: () => _selectDate(date),
                  borderRadius: AuraRadius.allSm,
                  focusColor: p.textPrimary.withValues(alpha: 0.20),
                  child: Container(
                    width: 64,
                    // El día era una caja de 64 × 76 sin mínimo propio: al
                    // reducir el escalado de fuente se quedaba por debajo del
                    // objetivo táctil.
                    constraints: const BoxConstraints(
                      minWidth: AuraTap.min,
                      minHeight: AuraTap.min,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuraSpace.xxs,
                      vertical: AuraSpace.xs,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: AuraRadius.allSm,
                      border: Border.all(
                        color: selected ? p.accent : p.borderStrong,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _daysEs[date.weekday - 1],
                          style: AppType.label.copyWith(
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? onAccent.withValues(alpha: 0.85)
                                : p.textMuted,
                          ),
                        ),
                        Text(
                          '${date.day}',
                          style: AppType.bodyLarge.copyWith(
                            fontWeight: FontWeight.w800,
                            color: selected ? onAccent : p.textPrimary,
                          ),
                        ),
                        Text(
                          _monthsEs[date.month - 1],
                          style: AppType.label.copyWith(
                            color: selected
                                ? onAccent.withValues(alpha: 0.85)
                                : p.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlots() {
    if (_loadingSlots) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AuraSpace.lg),
        child: AuraLoading(message: 'Buscando horas libres…'),
      );
    }

    if (_slots.isEmpty) {
      return const AuraBanner(
        tone: AuraTone.info,
        icon: Icons.event_busy_rounded,
        message: 'No hay horas disponibles ese día. Prueba con otra fecha.',
      );
    }

    // `AuraOptionGroup` en vez de `ChoiceChip`: los chips medían 27 px de alto
    // y quedaban pegados unos a otros, así que fallar el toque elegía la hora
    // de al lado.
    final options = <({DateTime value, String label, IconData? icon})>[
      for (final slot in _slots)
        (
          value: slot,
          label: '${slot.hour.toString().padLeft(2, '0')}:'
              '${slot.minute.toString().padLeft(2, '0')}',
          icon: null,
        ),
    ];

    return AuraOptionGroup<DateTime>(
      options: options,
      selected: _slot,
      onSelect: (slot) => setState(() => _slot = slot),
    );
  }

  // -------------------------------------------------------------- resumen

  /// Lo que se va a agendar, justo antes de confirmarlo.
  ///
  /// No había ninguno: se confirmaba desde un botón al fondo mientras el
  /// profesional elegido podía haber quedado tres pantallazos más arriba.
  Widget _buildSummary() {
    final professional = _professional;
    final slot = _slot;
    if (professional == null || slot == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AuraSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AuraSectionHeader(title: 'Resumen'),
          AuraCard(
            child: Column(
              children: [
                AuraSummaryRow(
                  label: 'Profesional',
                  value: professional.name,
                  icon: Icons.person_rounded,
                ),
                AuraSummaryRow(
                  label: 'Tipo',
                  value: _type == 'presencial'
                      ? 'Presencial'
                      : 'Videoconsulta',
                  icon: _type == 'presencial'
                      ? Icons.home_rounded
                      : Icons.videocam_rounded,
                ),
                AuraSummaryRow(
                  label: 'Cuándo',
                  value: formatAppointmentDate(slot),
                  icon: Icons.schedule_rounded,
                ),
                AuraSummaryRow(
                  label: 'Total',
                  value: formatClp(professional.consultationPrice),
                  icon: Icons.payments_outlined,
                  strong: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
