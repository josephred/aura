import 'dart:async';

import 'package:flutter/material.dart';

import '../models/staff_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../ui/aura.dart';

/// Operations panel for coordinators, mirroring the web `/admin` panel.
///
/// Purely administrative: shift coverage, zone load and provider status. The
/// clinical workspace lives in the professional's own area.
class OperationsDashboard extends StatefulWidget {
  final AppState state;

  const OperationsDashboard({super.key, required this.state});

  @override
  State<OperationsDashboard> createState() => _OperationsDashboardState();
}

class _OperationsDashboardState extends State<OperationsDashboard> {
  AppPalette get p => context.palette;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    widget.state.refreshOperations();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => widget.state.refreshOperations(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final metrics = state.opsMetrics;

    if (metrics == null && state.opsLoading) {
      return Center(child: CircularProgressIndicator(color: p.accent));
    }

    return RefreshIndicator(
      color: p.accent,
      onRefresh: state.refreshOperations,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [p.brandDeep, p.brandDeep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: p.onBrandDeep,
                  child: Icon(Icons.tune, color: p.brandDeep, size: AuraIcon.lg),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.staffProfile?.name ?? 'Panel de Operaciones',
                        style: AppType.titleMedium.copyWith(
                          color: p.onBrandDeep,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Coordinación · sin área clínica',
                        style: AppType.bodySmall.copyWith(color: p.onBrandDeep.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (metrics != null) _buildMetricsGrid(metrics),
          const SizedBox(height: 24),

          Text(
            'Demanda por zona',
            style: AppType.titleSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildZones(state.opsZones),
          const SizedBox(height: 24),

          Text(
            'Prestadores y turnos',
            style: AppType.titleSmall.copyWith(
              fontWeight: FontWeight.bold,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildProviders(state.opsProfessionals),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(OperationsMetrics m) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _metricCard(
          'Prestadores en turno',
          '${m.professionalsOnDuty} / ${m.professionalsTotal}',
          Icons.people,
          p.accent,
        ),
        _metricCard(
          'Solicitudes abiertas',
          '${m.openRequests}',
          Icons.assignment_turned_in,
          p.info,
        ),
        _metricCard(
          'Demora promedio',
          '${m.averageEtaMinutes} min',
          Icons.timer,
          p.warning,
        ),
        _metricCard(
          'Completadas hoy',
          '${m.completedToday}',
          Icons.check_circle_outline,
          p.success,
        ),
      ],
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: AppType.label.copyWith(
                    color: p.textMuted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppType.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: p.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZones(List<ZoneLoad> zones) {
    if (zones.isEmpty) {
      return _emptyCard('No hay solicitudes abiertas en este momento.');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: zones.map((zone) {
          final (Color color, String label) = zone.uncovered
              ? (p.error, 'Sin cobertura')
              : zone.saturated
                  ? (p.warning, 'SATURADA')
                  : (p.success, 'AL DÍA');

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        zone.zone,
                        style: AppType.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: p.textPrimary,
                        ),
                      ),
                      Text(
                        '${zone.openRequests} abiertas · ${zone.professionalsOnDuty} en turno',
                        style: AppType.bodySmall.copyWith(color: p.textMuted),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Text(
                  label,
                  style: AppType.label.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProviders(List<ManagedProfessional> providers) {
    if (providers.isEmpty) {
      return _emptyCard('Sin prestadores registrados.');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: providers.map((provider) {
          Color statusColor = p.success;
          if (provider.dutyStatus == 'ocupado') {
            statusColor = p.warning;
          } else if (provider.dutyStatus == 'desconectado') {
            statusColor = p.error;
          }

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.name,
                        style: AppType.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: p.textPrimary,
                        ),
                      ),
                      Text(
                        provider.coverageZones?.isNotEmpty == true
                            ? '${provider.specialty} · ${provider.coverageZones}'
                            : provider.specialty,
                        style: AppType.bodySmall.copyWith(color: p.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                DropdownButton<String>(
                  value: provider.dutyStatus,
                  underline: const SizedBox(),
                  style: AppType.bodySmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                  icon: Icon(Icons.arrow_drop_down_rounded,
                      color: statusColor, size: 18),
                  items: const [
                    DropdownMenuItem(
                        value: 'disponible', child: Text('Disponible')),
                    DropdownMenuItem(value: 'ocupado', child: Text('Ocupado')),
                    DropdownMenuItem(
                        value: 'desconectado', child: Text('Desconectado')),
                  ],
                  onChanged: (value) async {
                    if (value == null) return;
                    final error = await widget.state
                        .setProviderDutyStatus(provider.id, value);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          error ?? '${provider.name} cambiado a "$value".',
                        ),
                        backgroundColor: error == null
                            ? p.accent
                            : p.error,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _emptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: AppType.bodyMedium.copyWith(color: p.textMuted),
      ),
    );
  }
}
