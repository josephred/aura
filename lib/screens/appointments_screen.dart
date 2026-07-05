import 'package:flutter/material.dart';
import '../models/appointment.dart';
import '../state/app_state.dart';
import 'book_appointment_screen.dart';

const _kDaysEs = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
const _kMonthsEs = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

String formatAppointmentDate(DateTime dt) {
  final day = _kDaysEs[dt.weekday - 1];
  final month = _kMonthsEs[dt.month - 1];
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$day ${dt.day} $month · $hour:$minute';
}

String formatClp(int amount) {
  final digits = amount.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return '\$$buffer';
}

class AppointmentsScreen extends StatefulWidget {
  final AppState state;

  const AppointmentsScreen({super.key, required this.state});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onStateChange);
    _refresh();
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateChange);
    super.dispose();
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    await widget.state.fetchAppointments();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _cancel(Appointment appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar cita'),
        content: Text(
          '¿Cancelar tu cita con ${appointment.professionalName ?? 'el profesional'} '
          'del ${formatAppointmentDate(appointment.scheduledAt)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar cita'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final error = await widget.state.cancelAppointment(appointment.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Cita cancelada.')),
    );
  }

  Future<void> _verifyPayment(Appointment appointment) async {
    final approved = await widget.state.verifyAppointmentPayment(appointment.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(approved
            ? '¡Pago confirmado! Tu cita quedó agendada.'
            : 'Aún no vemos el pago. Si ya pagaste, espera un momento y reintenta.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final upcoming =
        widget.state.appointments.where((a) => a.isUpcoming).toList().reversed.toList();
    final past =
        widget.state.appointments.where((a) => !a.isUpcoming).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        foregroundColor: const Color(0xFF0F172A),
        title: const Text(
          'Mis citas',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0D9488),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.calendar_month),
        label: const Text('Agendar cita'),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BookAppointmentScreen(state: widget.state),
            ),
          );
          _refresh();
        },
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0D9488)))
          : RefreshIndicator(
              color: const Color(0xFF0D9488),
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  if (upcoming.isEmpty && past.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: Column(
                        children: [
                          Icon(Icons.event_available,
                              size: 56, color: Colors.teal.shade200),
                          const SizedBox(height: 12),
                          const Text(
                            'Aún no tienes citas agendadas.',
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  if (upcoming.isNotEmpty) ...[
                    _sectionTitle('Próximas'),
                    ...upcoming.map(_buildCard),
                  ],
                  if (past.isNotEmpty) ...[
                    _sectionTitle('Anteriores'),
                    ...past.map(_buildCard),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
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

  Widget _buildCard(Appointment appointment) {
    final (chipText, chipColor) = switch (appointment.status) {
      AppointmentStatus.confirmed => ('Confirmada', const Color(0xFF0D9488)),
      AppointmentStatus.pendingPayment => ('Pago pendiente', const Color(0xFFF59E0B)),
      AppointmentStatus.completed => ('Completada', const Color(0xFF10B981)),
      AppointmentStatus.cancelled => ('Cancelada', const Color(0xFFEF4444)),
      AppointmentStatus.noShow => ('No asistió', const Color(0xFFEF4444)),
      AppointmentStatus.unknown => ('—', const Color(0xFF64748B)),
    };

    final isPendingPayment =
        appointment.status == AppointmentStatus.pendingPayment;
    final canCancel = appointment.isUpcoming;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  appointment.professionalName ?? 'Profesional Aura',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: chipColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  chipText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: chipColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            appointment.specialty ?? '',
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.schedule, size: 15, color: Color(0xFF0D9488)),
              const SizedBox(width: 6),
              Text(
                formatAppointmentDate(appointment.scheduledAt),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
              const Spacer(),
              Text(
                formatClp(appointment.price),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          if (isPendingPayment || canCancel) const SizedBox(height: 12),
          if (isPendingPayment)
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF009EE3), // MP blue
                    ),
                    onPressed: appointment.paymentUrl == null
                        ? null
                        : () =>
                            widget.state.openCheckoutUrl(appointment.paymentUrl!),
                    icon: const Icon(Icons.account_balance_wallet, size: 16),
                    label: const Text('Pagar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _verifyPayment(appointment),
                    child: const Text('Ya pagué'),
                  ),
                ),
              ],
            ),
          if (canCancel)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444)),
                onPressed: () => _cancel(appointment),
                child: const Text('Cancelar cita'),
              ),
            ),
        ],
      ),
    );
  }
}
