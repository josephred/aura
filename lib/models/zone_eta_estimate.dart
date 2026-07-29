/// Live wait estimate for a clinical service in a dispatch zone (comuna).
///
/// Produced by `GET /api/dispatch/eta`, which weighs the requests currently
/// open in the zone against the professionals on duty there.
class ZoneEtaEstimate {
  final String zone;
  final String serviceId;

  /// Requests placed but not yet under way.
  final int waiting;

  /// Requests already en route or being attended.
  final int inProgress;

  /// Professionals of this discipline on shift covering the zone, whether or
  /// not they are mid-visit right now.
  final int availableProfessionals;

  /// Subset of the above that is free at this instant.
  final int freeProfessionals;

  /// 'low' | 'medium' | 'high'
  final String demandLevel;

  final int etaMinMinutes;
  final int etaMaxMinutes;

  /// Ready-to-display sentence explaining the estimate.
  final String message;

  const ZoneEtaEstimate({
    required this.zone,
    required this.serviceId,
    required this.waiting,
    required this.inProgress,
    required this.availableProfessionals,
    required this.freeProfessionals,
    required this.demandLevel,
    required this.etaMinMinutes,
    required this.etaMaxMinutes,
    required this.message,
  });

  factory ZoneEtaEstimate.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic value) =>
        value is int ? value : int.tryParse('${value ?? 0}') ?? 0;

    return ZoneEtaEstimate(
      zone: json['zone'] as String? ?? 'General',
      serviceId: json['service_id'] as String? ?? '',
      waiting: asInt(json['waiting']),
      inProgress: asInt(json['in_progress']),
      availableProfessionals: asInt(json['available_professionals']),
      freeProfessionals: asInt(json['free_professionals']),
      demandLevel: json['demand_level'] as String? ?? 'low',
      etaMinMinutes: asInt(json['eta_min_minutes']),
      etaMaxMinutes: asInt(json['eta_max_minutes']),
      message: json['message'] as String? ?? '',
    );
  }

  /// Total load currently being served in the zone.
  int get activeLoad => waiting + inProgress;

  String get rangeLabel => etaMinMinutes == etaMaxMinutes
      ? '$etaMinMinutes min'
      : '$etaMinMinutes - $etaMaxMinutes min';

  String get demandLabel => switch (demandLevel) {
        'high' => 'Alta demanda',
        'medium' => 'Demanda moderada',
        _ => 'Buena disponibilidad',
      };
}
