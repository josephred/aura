import 'dart:async';

import 'package:flutter/material.dart';

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

          if (profile?.providesLab == true) ...[
            const SizedBox(height: 28),
            _buildLabCollectionsSection(state.staffLabCollections),
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
                  style: AppType.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: p.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  booking.patientName,
                  style: AppType.bodySmall.copyWith(color: p.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  booking.addressText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.label.copyWith(color: p.textFaint),
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
                style: AppType.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _formatVisitDate(booking),
                style: AppType.label.copyWith(color: p.textMuted),
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
              style: AppType.bodySmall.copyWith(color: p.textMuted, height: 1.4),
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
    final photo = profile?.photoUrl;

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
            foregroundImage: (photo != null && photo.isNotEmpty)
                ? NetworkImage(photo)
                : null,
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
                  style: AppType.titleMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile?.specialty ?? 'Prestador clínico',
                  style: AppType.label.copyWith(color: const Color(0xFFCCFBF1)),
                ),
                if (profile != null && profile.coverageZones.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Cubre: ${profile.coverageZones.join(', ')}',
                    style: AppType.label.copyWith(color: const Color(0xFF99F6E4)),
                  ),
                ],
              ],
            ),
          ),
          if (profile != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.white70),
              tooltip: 'Editar perfil y currículum',
              onPressed: () => _showEditProfileModal(profile),
            ),
        ],
      ),
    );
  }

  Future<void> _showEditProfileModal(StaffProfile profile) async {
    final bioCtrl = TextEditingController(text: profile.bio ?? '');
    final regCtrl = TextEditingController(text: profile.registrationNumber ?? '');
    final expCtrl = TextEditingController(
      text: profile.yearsOfExperience != null ? '${profile.yearsOfExperience}' : '',
    );
    final phoneCtrl = TextEditingController(text: profile.phone ?? '');
    final zonesCtrl = TextEditingController(text: profile.coverageZones.join(', '));
    final photoCtrl = TextEditingController(text: profile.photoUrl ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Mi Perfil y Hoja de Vida',
                  style: AppType.titleMedium.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Esta información es visible para los pacientes antes de la atención.',
                  style: AppType.bodySmall.copyWith(color: p.textMuted),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: bioCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Biografía / Reseña profesional',
                    hintText: 'Ej. Médico internista con 10 años de experiencia...',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: regCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nº Registro Superintendencia de Salud',
                    hintText: 'Ej. SIS-123456',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: expCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Años de experiencia clínica',
                    hintText: 'Ej. 8',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono de contacto durante atención',
                    hintText: 'Ej. +56 9 1234 5678',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: zonesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Zonas de cobertura (separadas por coma)',
                    hintText: 'Ej. Providencia, Las Condes, Ñuñoa',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: photoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'URL de fotografía de perfil',
                    hintText: 'https://...',
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(context);
                      final error = await widget.state.updateStaffProfile(
                        bio: bioCtrl.text.trim(),
                        registrationNumber: regCtrl.text.trim(),
                        yearsOfExperience: int.tryParse(expCtrl.text.trim()),
                        phone: phoneCtrl.text.trim(),
                        coverageZones: zonesCtrl.text
                            .split(',')
                            .map((z) => z.trim())
                            .where((z) => z.isNotEmpty)
                            .toList(),
                        photoUrl: photoCtrl.text.trim(),
                      );
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(error ?? 'Perfil actualizado correctamente.'),
                            backgroundColor: error == null
                                ? const Color(0xFF0F766E)
                                : const Color(0xFFDC2626),
                          ),
                        );
                      }
                    },
                    child: Text(
                      'Guardar cambios',
                      style: AppType.button.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
                  style: AppType.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
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
          style: AppType.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: p.textPrimary,
          ),
        ),
        Text(label, style: AppType.label.copyWith(color: p.textMuted)),
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
        style: AppType.bodySmall.copyWith(color: p.textMuted),
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
                  style: AppType.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F766E),
                  ),
                ),
              ),
              Flexible(
                child: Text(
                '\$${booking.finalPrice}',
                style: AppType.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
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
                  style: AppType.label.copyWith(
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
                  style: AppType.label.copyWith(color: p.textFaint),
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
                    : Text(
                        canAccept ? 'Tomar y salir' : booking.nextActionLabel,
                        style: AppType.button.copyWith(fontWeight: FontWeight.bold),
                      ),
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
              style: AppType.bodySmall.copyWith(color: p.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _attachmentChip(IconData icon, String label, String url) {
    return ActionChip(
      avatar: Icon(icon, size: 14, color: p.accent),
      label: Text(label, style: AppType.label),
      backgroundColor: p.accentSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: () async {
        final opened = await widget.state.openMediaAttachment(url);
        if (!opened && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo abrir el archivo clínico.')),
          );
        }
      },
    );
  }

  Widget _buildLabCollectionsSection(List<StaffLabCollection> collections) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Tomas de Muestra Asignadas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: p.textPrimary,
                ),
              ),
            ),
            if (collections.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: p.accentSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${collections.length}',
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
        if (collections.isEmpty)
          _buildEmpty('No tienes tomas de muestra asignadas para hoy.')
        else
          ...collections.map(_buildLabCollectionCard),
      ],
    );
  }

  Widget _buildLabCollectionCard(StaffLabCollection col) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  col.patientName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: p.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: col.hasResult ? const Color(0xFF0F766E).withValues(alpha: 0.15) : p.accentSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  col.hasResult ? 'Informe emitido' : 'Pendiente',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: col.hasResult ? const Color(0xFF0F766E) : p.accentText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.biotech_outlined, size: 14, color: p.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  col.examRequired,
                  style: TextStyle(fontSize: 13, color: p.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.place_outlined, size: 14, color: p.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  col.addressText,
                  style: TextStyle(fontSize: 12, color: p.textMuted),
                ),
              ),
            ],
          ),
          if (col.clinicalNotes != null && col.clinicalNotes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: Colors.amber),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Notas: ${col.clinicalNotes}',
                      style: const TextStyle(fontSize: 11, color: Colors.brown),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
