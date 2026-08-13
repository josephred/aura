import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/staff_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Work area for professionals and ambulance drivers.
///
/// Every card here comes from `/api/staff/bookings` — the same queue the web
/// portal shows. Accepting or advancing a visit writes to the server; nothing
/// is faked locally.
class StaffDashboard extends StatefulWidget {
  final AppState state;

  /// Ambulance drivers only care about transfers, so the queue is filtered.
  final bool ambulanceOnly;

  const StaffDashboard({
    super.key,
    required this.state,
    this.ambulanceOnly = false,
  });

  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> {
  AppPalette get p => context.palette;
  Timer? _pollTimer;
  String? _busyBookingId;

  /// The record can get long, so it starts folded to the most recent visits.
  bool _showAllCompleted = false;
  static const _completedPreviewCount = 5;

  @override
  void initState() {
    super.initState();
    widget.state.refreshStaffArea();
    // The queue moves while the professional is looking at it.
    _pollTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => widget.state.refreshStaffArea(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  List<StaffBooking> _filter(List<StaffBooking> bookings) {
    if (!widget.ambulanceOnly) return bookings;
    return bookings.where((b) => b.serviceId == 'ambulancia').toList();
  }

  Future<void> _advance(StaffBooking booking, String status) async {
    setState(() => _busyBookingId = booking.id);
    final error = await widget.state.updateStaffBookingStatus(booking.id, status);
    if (!mounted) return;
    setState(() => _busyBookingId = null);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Atención actualizada.'),
        backgroundColor:
            error == null ? const Color(0xFF0F766E) : const Color(0xFFDC2626),
      ),
    );
  }

  Future<void> _toggleDuty(bool goOnDuty) async {
    final error = await widget.state
        .setStaffDutyStatus(goOnDuty ? 'disponible' : 'desconectado');
    if (!mounted || error == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error), backgroundColor: const Color(0xFFDC2626)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final profile = state.staffProfile;

    if (state.staffError != null) {
      return _buildErrorState(state.staffError!);
    }

    if (profile == null && state.staffLoading) {
      return Center(child: CircularProgressIndicator(color: p.accent));
    }

    final inZone = _filter(state.staffBookingsInZone);
    final outside = _filter(state.staffBookingsOutsideZone);
    final completed = _filter(state.staffBookingsCompleted);

    return RefreshIndicator(
      color: p.accent,
      onRefresh: state.refreshStaffArea,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          _buildHeader(profile),
          const SizedBox(height: 16),
          if (profile != null) _buildDutyCard(profile),
          const SizedBox(height: 24),

          Text(
            widget.ambulanceOnly
                ? 'Traslados en tu zona'
                : 'Solicitudes en tu zona',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          if (inZone.isEmpty)
            _buildEmpty(
              profile != null && !profile.isOnDuty
                  ? 'Estás fuera de turno. Actívalo para recibir solicitudes.'
                  : 'No hay solicitudes pendientes en tu zona por ahora.',
            )
          else
            ...inZone.map(_buildBookingCard),

          if (outside.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Fuera de tu zona (${outside.length})',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: p.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Puedes tomarlas si nadie del sector responde.',
              style: TextStyle(fontSize: 12, color: p.textFaint),
            ),
            const SizedBox(height: 12),
            ...outside.map(_buildBookingCard),
          ],

          const SizedBox(height: 28),
          _buildCompletedSection(completed),
        ],
      ),
    );
  }

  /// The professional's own record: visits they already closed.
  Widget _buildCompletedSection(List<StaffBooking> completed) {
    final showing = _showAllCompleted
        ? completed
        : completed.take(_completedPreviewCount).toList();
    final hidden = completed.length - showing.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.ambulanceOnly
                    ? 'Traslados realizados'
                    : 'Atenciones realizadas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: p.textPrimary,
                ),
              ),
            ),
            if (completed.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: p.accentSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${completed.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: p.accentText,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (completed.isEmpty)
          _buildEmpty(
            widget.ambulanceOnly
                ? 'Todavía no has cerrado ningún traslado.'
                : 'Todavía no has cerrado ninguna atención. Aquí quedará el registro de cada visita que finalices.',
          )
        else ...[
          ...showing.map(_buildCompletedCard),
          if (hidden > 0)
            TextButton(
              onPressed: () => setState(() => _showAllCompleted = true),
              child: Text('Ver todas ($hidden más)'),
            )
          else if (_showAllCompleted && completed.length > _completedPreviewCount)
            TextButton(
              onPressed: () => setState(() => _showAllCompleted = false),
              child: const Text('Mostrar menos'),
            ),
        ],
      ],
    );
  }

  Widget _buildCompletedCard(StaffBooking booking) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: p.accentSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.check_circle_outline_rounded,
              size: 18,
              color: p.accentText,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.serviceTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: p.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  booking.patientName,
                  style: TextStyle(fontSize: 12, color: p.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  booking.addressText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: p.textFaint),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${booking.finalPrice}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _formatVisitDate(booking),
                style: TextStyle(fontSize: 12, color: p.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Written out by hand instead of `DateFormat`: the app never calls
  /// `initializeDateFormatting`, so a locale-aware pattern would fall back to
  /// English month names.
  static const _months = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  String _formatVisitDate(StaffBooking booking) {
    final date = booking.createdAt;
    if (date == null) return booking.startTime;

    final label = '${date.day} ${_months[date.month - 1]}';
    return date.year == DateTime.now().year ? label : '$label ${date.year}';
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 40, color: p.textFaint),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: p.textMuted, height: 1.4),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: widget.state.refreshStaffArea,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(StaffProfile? profile) {
    final initial = (profile?.name ?? 'A').trim();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.ambulanceOnly
              ? const [Color(0xFF0F766E), Color(0xFF1E3A8A)]
              : const [Color(0xFF0F172A), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFF2DD4BF),
            child: widget.ambulanceOnly
                ? const Icon(Icons.local_shipping, color: Color(0xFF0F172A))
                : Text(
                    initial.isEmpty ? 'A' : initial[0].toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile?.name ?? 'Equipo Aura',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile?.specialty ?? 'Prestador clínico',
                  style: const TextStyle(color: Color(0xFFCCFBF1), fontSize: 12),
                ),
                if (profile != null && profile.coverageZones.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Cubre: ${profile.coverageZones.join(', ')}',
                    style: const TextStyle(color: Color(0xFF99F6E4), fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDutyCard(StaffProfile profile) {
    final onDuty = profile.isOnDuty;
    final busy = profile.dutyStatus == 'ocupado';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.circle,
                size: 12,
                color: busy
                    ? const Color(0xFFF59E0B)
                    : onDuty
                        ? const Color(0xFF10B981)
                        : p.textFaint,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  busy
                      ? 'En atención'
                      : onDuty
                          ? 'En turno'
                          : 'Fuera de turno',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Switch(
                value: onDuty,
                activeThumbColor: const Color(0xFF0F766E),
                onChanged: busy ? null : _toggleDuty,
              ),
            ],
          ),
          Divider(height: 20, color: p.border),
          Row(
            children: [
              Expanded(
                child: _miniStat('Atendidas hoy', '${profile.completedToday}'),
              ),
              Expanded(
                child: _miniStat('En curso', '${profile.openNow}'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: p.textPrimary,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: p.textMuted)),
      ],
    );
  }

  Widget _buildEmpty(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: p.textMuted),
      ),
    );
  }

  Widget _buildBookingCard(StaffBooking booking) {
    final isBusy = _busyBookingId == booking.id;
    final canAccept = booking.isUnassigned && booking.status == 'accepted';
    final next = booking.nextStatus;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: booking.outsideZone ? p.border : p.accent.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  booking.serviceTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF0F766E),
                  ),
                ),
              ),
              Flexible(
                child: Text(
                '\$${booking.finalPrice}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: p.textPrimary,
                ),
              ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _detailRow(Icons.person_outline, booking.patientName),
          _detailRow(Icons.location_on_outlined, booking.addressText),
          if (booking.zone != 'General')
            _detailRow(Icons.map_outlined, 'Zona: ${booking.zone}'),
          if (booking.destinationAddress != null)
            _detailRow(Icons.flag_outlined, 'Destino: ${booking.destinationAddress}'),
          if (booking.symptomsDescription != null &&
              booking.symptomsDescription!.isNotEmpty)
            _detailRow(Icons.notes_outlined, booking.symptomsDescription!),

          if (booking.symptomAudioUrl != null || booking.prescriptionUrl != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (booking.symptomAudioUrl != null)
                  _attachmentChip(
                    Icons.mic,
                    'Nota de voz',
                    booking.symptomAudioUrl!,
                  ),
                if (booking.prescriptionUrl != null)
                  _attachmentChip(
                    Icons.description_outlined,
                    booking.prescriptionName ?? 'Orden médica',
                    booking.prescriptionUrl!,
                  ),
              ],
            ),
          ],

          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: p.fill,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  booking.statusLabel.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: p.textMuted,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const Spacer(),
              if (booking.startTime.isNotEmpty)
                Text(
                  'Solicitada ${booking.startTime}',
                  style: TextStyle(fontSize: 12, color: p.textFaint),
                ),
            ],
          ),

          if (next != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isBusy ? null : () => _advance(booking, next),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isBusy
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(canAccept ? 'Tomar y salir' : booking.nextActionLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: p.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: p.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _attachmentChip(IconData icon, String label, String url) {
    return ActionChip(
      avatar: Icon(icon, size: 14, color: p.accent),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: p.accentSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: () async {
        try {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo abrir el archivo.')),
          );
        }
      },
    );
  }
}
