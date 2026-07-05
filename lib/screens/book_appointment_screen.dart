import 'package:flutter/material.dart';
import '../models/appointment.dart';
import '../models/professional.dart';
import '../state/app_state.dart';
import 'appointments_screen.dart' show formatAppointmentDate, formatClp;

class BookAppointmentScreen extends StatefulWidget {
  final AppState state;

  const BookAppointmentScreen({super.key, required this.state});

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  static const _daysEs = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  static const _monthsEs = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  final _reasonController = TextEditingController();

  bool _loadingProfessionals = true;
  bool _loadingSlots = false;
  bool _submitting = false;

  Professional? _professional;
  DateTime _date = DateTime.now();
  List<DateTime> _slots = [];
  DateTime? _slot;

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
    if (mounted) setState(() => _loadingProfessionals = false);
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
    setState(() => _submitting = true);

    final (appointment, error) = await widget.state.createAppointment(
      professionalId: _professional!.id,
      scheduledAt: _slot!,
      reason: _reasonController.text.trim(),
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
          title: const Text('Reserva creada'),
          content: Text(
            'Tu hora del ${formatAppointmentDate(appointment.scheduledAt)} quedó '
            'reservada. Para confirmarla, completa el pago con Mercado Pago.',
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF009EE3)),
              onPressed: () {
                Navigator.pop(context);
                widget.state.openCheckoutUrl(appointment.paymentUrl!);
              },
              child: const Text('Pagar ahora'),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        foregroundColor: const Color(0xFF0F172A),
        title: const Text(
          'Agendar cita',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
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
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0D9488)))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _sectionTitle('1 · Profesional'),
                ...widget.state.professionals.map(_buildProfessionalCard),
                if (widget.state.professionals.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No hay profesionales disponibles por ahora.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  ),
                if (_professional != null) ...[
                  _sectionTitle('2 · Fecha'),
                  _buildDatePicker(),
                  _sectionTitle('3 · Horario'),
                  _buildSlots(),
                  _sectionTitle('Motivo de la consulta (opcional)'),
                  TextField(
                    controller: _reasonController,
                    maxLength: 500,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Ej: control de presión, dolor lumbar…',
                      filled: true,
                      fillColor: Colors.white,
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: Color(0xFFE2E8F0)),
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
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: Color(0xFF64748B),
          ),
        ),
      );

  Widget _buildProfessionalCard(Professional professional) {
    final selected = _professional?.id == professional.id;
    return GestureDetector(
      onTap: () => _selectProfessional(professional),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFF0D9488) : const Color(0xFFE2E8F0),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFF0D9488).withValues(alpha: 0.12),
              child: Text(
                professional.name.isNotEmpty
                    ? professional.name
                        .replaceAll(RegExp(r'^(Dr[a]?|Klg[oa]|Enf)\.\s*'), '')
                        .substring(0, 1)
                    : '?',
                style: const TextStyle(
                  color: Color(0xFF0D9488),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    professional.specialty,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatClp(professional.consultationPrice),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  '${professional.consultationDurationMinutes} min',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF64748B)),
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
    return SizedBox(
      height: 76,
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
                color: selected ? const Color(0xFF0D9488) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF0D9488)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _daysEs[date.weekday - 1],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white70 : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    _monthsEs[date.month - 1],
                    style: TextStyle(
                      fontSize: 10,
                      color: selected ? Colors.white70 : const Color(0xFF94A3B8),
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
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: Color(0xFF0D9488)),
          ),
        ),
      );
    }
    if (_slots.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'No hay horarios disponibles para este día. Prueba otra fecha.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
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
          selectedColor: const Color(0xFF0D9488),
          backgroundColor: Colors.white,
          labelStyle: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: selected ? Colors.white : const Color(0xFF334155),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: selected ? const Color(0xFF0D9488) : const Color(0xFFE2E8F0),
            ),
          ),
          showCheckmark: false,
        );
      }).toList(),
    );
  }
}
