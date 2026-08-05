import 'package:flutter/material.dart';
import 'package:aura/theme/app_theme.dart';
import '../models/appointment.dart';
import '../models/professional.dart';
import '../state/app_state.dart';
import '../utils/symptom_validation.dart';
import '../utils/text_search.dart';
import 'appointments_screen.dart' show formatAppointmentDate, formatClp;
import 'doctor_profile_screen.dart';

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

  bool _loadingProfessionals = true;
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
    _loadProfessionals();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadProfessionals() async {
    await widget.state.fetchProfessionals();
    if (!mounted) return;
    setState(() => _loadingProfessionals = false);

    // With a single matching professional there is nothing to choose: jump
    // straight to the calendar.
    final list = _visibleProfessionals;
    if (list.length == 1) _selectProfessional(list.first);
  }

  /// Professionals matching [BookAppointmentScreen.specialtyFilter], accent-
  /// and case-insensitively. Falls back to the full list when the filter
  /// matches nobody so the user is never left with an empty screen.
  List<Professional> get _visibleProfessionals {
    final filter = widget.specialtyFilter;
    if (filter == null || filter.isEmpty) return widget.state.professionals;

    final matches = widget.state.professionals.where((professional) {
      final haystack =
          normalizeForSearch('${professional.specialty} ${professional.name}');
      return filter.any(
        (term) => haystack.contains(normalizeForSearch(term)),
      );
    }).toList();

    return matches.isEmpty ? widget.state.professionals : matches;
  }

  Future<void> _selectProfessional(Professional professional) async {
    setState(() {
      _professional = professional;
      _slot = null;
    });
    await _loadSlots();
  }

  Future<void> _selectDate(DateTime date) async {
    setState(() {
      _date = date;
      _slot = null;
    });
    await _loadSlots();
  }

  Future<void> _loadSlots() async {
    if (_professional == null) return;
    setState(() => _loadingSlots = true);
    final slots = await widget.state.fetchSlots(_professional!.id, _date);
    if (mounted) {
      setState(() {
        _slots = slots;
        _loadingSlots = false;
      });
    }
  }

  Future<void> _confirm() async {
    if (_professional == null || _slot == null || _submitting) return;

    // The consultation reason opens the clinical history, so it is required
    // and must name at least two symptoms. Mirrors the server rule.
    final reasonError = validateSymptoms(_reasonController.text.trim());
    if (reasonError != null) {
      setState(() => _reasonError = reasonError);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reasonError),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() {
      _reasonError = null;
      _submitting = true;
    });

    final (appointment, error) = await widget.state.createAppointment(
      professionalId: _professional!.id,
      scheduledAt: _slot!,
      reason: _reasonController.text.trim(),
      type: _type,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (appointment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'No se pudo agendar la cita.')),
      );
      if (error != null && error.contains('horario')) _loadSlots();
      return;
    }

    if (appointment.status == AppointmentStatus.pendingPayment &&
        appointment.paymentUrl != null) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirma el monto'),
          content: Text(
            'Tu hora del ${formatAppointmentDate(appointment.scheduledAt)} con '
            '${_professional!.name} quedó reservada por '
            '${formatClp(_professional!.consultationPrice)}.\n\n'
            'Al aceptar te llevaremos a Mercado Pago. Si prefieres, puedes '
            'cancelar la reserva ahora sin costo.',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await widget.state.cancelAppointment(appointment.id);
              },
              child: const Text(
                'Cancelar reserva',
                style: TextStyle(color: Color(0xFFDC2626)),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF009EE3)),
              onPressed: () {
                Navigator.pop(context);
                widget.state.openCheckoutUrl(appointment.paymentUrl!);
              },
              child: const Text('Aceptar y pagar'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Cita confirmada!')),
      );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        elevation: 0,
        foregroundColor: p.textPrimary,
        title: Text(
          widget.headerTitle ?? 'Agendar cita',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: p.accent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: _slot == null || _submitting ? null : _confirm,
            child: Text(
              _submitting
                  ? 'Agendando…'
                  : _professional == null
                      ? 'Elige un profesional'
                      : _slot == null
                          ? 'Elige un horario'
                          : 'Confirmar cita · ${formatClp(_professional!.consultationPrice)}',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
      body: _loadingProfessionals
          ? Center(
              child: CircularProgressIndicator(color: p.accent))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _sectionTitle('Tipo de consulta'),
                Row(
                  children: [
                    Expanded(
                      child: _buildTypeOption(
                        'presencial',
                        Icons.home_filled,
                        'Presencial',
                        'En tu domicilio o consulta',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTypeOption(
                        'video',
                        Icons.videocam,
                        'Videoconsulta',
                        'Por videollamada segura',
                      ),
                    ),
                  ],
                ),
                _sectionTitle('1 · Profesional'),
                ..._visibleProfessionals.map(_buildProfessionalCard),
                if (_visibleProfessionals.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No hay profesionales disponibles por ahora.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.textMuted),
                    ),
                  ),
                if (_professional != null) ...[
                  _sectionTitle('2 · Fecha'),
                  _buildDatePicker(),
                  _sectionTitle('3 · Horario'),
                  _buildSlots(),
                  _sectionTitle('Motivo de la consulta'),
                  TextField(
                    controller: _reasonController,
                    maxLength: 500,
                    maxLines: 2,
                    onChanged: (value) {
                      if (_reasonError != null && hasTwoSymptoms(value)) {
                        setState(() => _reasonError = null);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Ej: dolor de cabeza y fiebre',
                      filled: true,
                      fillColor: p.card,
                      counterText: '',
                      errorText: _reasonError,
                      helperText: _reasonError == null
                          ? 'Indica al menos dos síntomas, separados por coma o «y».'
                          : null,
                      helperMaxLines: 2,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            BorderSide(color: p.border),
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: p.textMuted,
          ),
        ),
      );

  Widget _buildTypeOption(
      String value, IconData icon, String title, String subtitle) {
    final selected = _type == value;
    return GestureDetector(
      onTap: () => setState(() => _type = value),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? p.accent : p.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? p.accent : p.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon,
                size: 22,
                color: selected ? Colors.white : p.accent),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: selected ? Colors.white : p.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color:
                    selected ? Colors.white.withValues(alpha: 0.85) : p.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalCard(Professional professional) {
    final selected = _professional?.id == professional.id;
    return GestureDetector(
      onTap: () => _selectProfessional(professional),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? p.accent : p.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: p.accent.withValues(alpha: 0.12),
              child: Text(
                professional.name.isNotEmpty
                    ? professional.name
                        .replaceAll(RegExp(r'^(Dr[a]?|Klg[oa]|Enf)\.\s*'), '')
                        .substring(0, 1)
                    : '?',
                style: TextStyle(
                  color: p.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    professional.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: p.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    professional.specialty,
                    style: TextStyle(
                        fontSize: 12, color: p.textMuted),
                  ),
                  const SizedBox(height: 4),
                  // B.3 — conocer al profesional antes de agendar con él.
                  // El toque abre la ficha sin seleccionar la tarjeta: mirar
                  // un currículum no debería comprometer una reserva.
                  GestureDetector(
                    onTap: () => DoctorProfileScreen.showModal(
                      context,
                      professional,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.badge_outlined, size: 12, color: p.accent),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                          'Ver ficha',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: p.accent,
                          ),
                        ),
                        ),
                        if (professional.hasRating) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.star_rounded,
                              size: 12, color: Colors.amber),
                          const SizedBox(width: 2),
                          Text(
                            professional.ratingAvg!.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: p.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatClp(professional.consultationPrice),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: p.textPrimary,
                  ),
                ),
                Text(
                  '${professional.consultationDurationMinutes} min',
                  style: TextStyle(
                      fontSize: 12, color: p.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    final today = DateTime.now();
    // Igual que el selector de laboratorio: el alto sigue al escalado de
    // fuente, o el calendario recorta el día al subir la letra.
    final scale = MediaQuery.textScalerOf(context).scale(1.0);

    return SizedBox(
      height: 76 * scale,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 14,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final date = DateTime(today.year, today.month, today.day)
              .add(Duration(days: index));
          final selected = date.year == _date.year &&
              date.month == _date.month &&
              date.day == _date.day;
          return GestureDetector(
            onTap: () => _selectDate(date),
            child: Container(
              width: 64,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: selected ? p.accent : p.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? p.accent
                      : p.border,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _daysEs[date.weekday - 1],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white70 : p.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : p.textPrimary,
                    ),
                  ),
                  Text(
                    _monthsEs[date.month - 1],
                    style: TextStyle(
                      fontSize: 12,
                      color: selected ? Colors.white70 : p.textFaint,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlots() {
    if (_loadingSlots) {
      return Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: p.accent),
          ),
        ),
      );
    }
    if (_slots.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'No hay horarios disponibles para este día. Prueba otra fecha.',
          style: TextStyle(color: p.textMuted, fontSize: 13),
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _slots.map((slot) {
        final selected = _slot == slot;
        final label =
            '${slot.hour.toString().padLeft(2, '0')}:${slot.minute.toString().padLeft(2, '0')}';
        return ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => setState(() => _slot = slot),
          selectedColor: p.accent,
          backgroundColor: p.card,
          labelStyle: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: selected ? Colors.white : p.textSecondary,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: selected ? p.accent : p.border,
            ),
          ),
          showCheckmark: false,
        );
      }).toList(),
    );
  }
}
