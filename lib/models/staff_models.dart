/// Models for the staff area of the app (professional, operator, driver).
///
/// They mirror what `/api/staff/*` returns, which is the very same payload the
/// web portal consumes — there is a single backend implementation of the
/// clinical rules and both clients read it.
library;

int _asInt(dynamic value) =>
    value is int ? value : int.tryParse('${value ?? 0}') ?? 0;

/// A care request as seen by the professional attending it.
class StaffBooking {
  final String id;
  final String serviceId;
  final String serviceTitle;
  final String status;
  final int currentStep;

  final String patientName;
  final String addressText;
  final String? originAddress;
  final String? destinationAddress;
  final String? ambulanceType;

  final String? symptomsDescription;
  final String? symptomAudioUrl;
  final String? prescriptionName;
  final String? prescriptionUrl;

  final String zone;

  /// True when the request falls outside the professional's coverage. Still
  /// shown, so a comuna nobody covers never ends up orphaned.
  final bool outsideZone;

  final int finalPrice;
  final int etaMinutes;
  final String startTime;
  final String? professionalId;

  /// When the request was created. `startTime` only carries the time of day,
  /// which is enough for a live queue but not to date a closed visit.
  final DateTime? createdAt;

  const StaffBooking({
    required this.id,
    required this.serviceId,
    required this.serviceTitle,
    required this.status,
    required this.currentStep,
    required this.patientName,
    required this.addressText,
    required this.zone,
    required this.outsideZone,
    required this.finalPrice,
    required this.etaMinutes,
    required this.startTime,
    this.originAddress,
    this.destinationAddress,
    this.ambulanceType,
    this.symptomsDescription,
    this.symptomAudioUrl,
    this.prescriptionName,
    this.prescriptionUrl,
    this.professionalId,
    this.createdAt,
  });

  factory StaffBooking.fromJson(Map<String, dynamic> json) {
    final service = json['service'];
    final dependent = json['dependent'];
    final user = json['user'];

    String patient = 'Paciente';
    if (json['patient_type'] == 'dependent' && dependent is Map) {
      final relationship = dependent['relationship'];
      patient = relationship == null
          ? '${dependent['name']}'
          : '${dependent['name']} ($relationship)';
    } else if (user is Map && user['name'] != null) {
      patient = '${user['name']}';
    }

    return StaffBooking(
      id: json['id'] as String,
      serviceId: json['service_id'] as String? ?? '',
      serviceTitle: service is Map
          ? (service['short_title'] ?? service['title'] ?? 'Atención') as String
          : 'Atención',
      status: json['status'] as String? ?? 'pending_payment',
      currentStep: _asInt(json['current_step']),
      patientName: patient,
      addressText: json['address_text'] as String? ?? 'Sin dirección',
      originAddress: json['origin_address'] as String?,
      destinationAddress: json['destination_address'] as String?,
      ambulanceType: json['ambulance_type'] as String?,
      symptomsDescription: json['symptoms_description'] as String?,
      symptomAudioUrl: json['symptom_audio_url'] as String?,
      prescriptionName: json['prescription_name'] as String?,
      prescriptionUrl: json['prescription_file'] as String?,
      zone: json['zone'] as String? ?? 'General',
      outsideZone: json['outside_zone'] == true,
      finalPrice: _asInt(json['final_price']),
      etaMinutes: _asInt(json['eta_minutes']),
      startTime: json['start_time'] as String? ?? '',
      professionalId: json['professional_id'] as String?,
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}')?.toLocal(),
    );
  }

  /// Waiting to be taken by somebody on shift.
  bool get isUnassigned => professionalId == null || professionalId!.isEmpty;

  bool get isOpen =>
      status != 'completed' && status != 'cancelled';

  /// A visit already carried out — what the professional's own record is made of.
  /// Cancelled requests are excluded on purpose: nobody attended them.
  bool get isCompleted => status == 'completed';

  /// The status this request moves to when the professional advances it,
  /// or null when there is nothing left to do.
  String? get nextStatus => switch (status) {
        'accepted' => 'en_camino',
        'en_camino' => 'en_atencion',
        'en_atencion' => 'completed',
        _ => null,
      };

  String get nextActionLabel => switch (status) {
        'pending_payment' => 'Esperando pago',
        'accepted' => 'Iniciar traslado',
        'en_camino' => 'Llegué al domicilio',
        'en_atencion' => 'Finalizar atención',
        _ => 'Sin acciones',
      };

  String get statusLabel => switch (status) {
        'pending_payment' => 'Pago pendiente',
        'accepted' => 'Confirmada',
        'en_camino' => 'En camino',
        'en_atencion' => 'En atención',
        'completed' => 'Completada',
        'cancelled' => 'Cancelada',
        _ => status,
      };
}

/// The professional's own shift, from `GET /api/staff/duty`.
class StaffProfile {
  final String name;
  final String? specialty;
  final String role;
  final bool isOperator;
  final String? professionalId;
  final String dutyStatus; // disponible | ocupado | desconectado
  final List<String> coverageZones;
  final int completedToday;
  final int openNow;

  /// Hoja de vida y perfil público verificable (REQ-08)
  final String? bio;
  final String? registrationNumber;
  final int? yearsOfExperience;
  final String? phone;
  final String? photoUrl;
  final double? ratingAvg;
  final int ratingCount;

  final bool providesLab;

  const StaffProfile({
    required this.name,
    required this.role,
    required this.isOperator,
    required this.dutyStatus,
    required this.coverageZones,
    required this.completedToday,
    required this.openNow,
    this.providesLab = false,
    this.specialty,
    this.professionalId,
    this.bio,
    this.registrationNumber,
    this.yearsOfExperience,
    this.phone,
    this.photoUrl,
    this.ratingAvg,
    this.ratingCount = 0,
  });

  factory StaffProfile.fromJson(Map<String, dynamic> json) {
    return StaffProfile(
      name: json['name'] as String? ?? 'Equipo Aura',
      specialty: json['specialty'] as String?,
      role: json['role'] as String? ?? 'doctor_provider',
      isOperator: json['is_operator'] == true,
      providesLab: json['provides_lab'] == true || json['role'] == 'laboratorista',
      professionalId: json['professional_id'] as String?,
      dutyStatus: json['duty_status'] as String? ?? 'desconectado',
      coverageZones: (json['coverage_zones'] as List?)
              ?.map((zone) => '$zone')
              .toList() ??
          const [],
      completedToday: _asInt(json['completed_today']),
      openNow: _asInt(json['open_now']),
      bio: json['bio'] as String?,
      registrationNumber: json['registration_number'] as String?,
      yearsOfExperience: (json['years_of_experience'] as num?)?.toInt(),
      phone: json['phone'] as String?,
      photoUrl: json['photo_url'] as String?,
      ratingAvg: (json['rating_avg'] as num?)?.toDouble(),
      ratingCount: _asInt(json['rating_count']),
    );
  }

  bool get isOnDuty => dutyStatus != 'desconectado';
  bool get hasRating => ratingCount > 0 && ratingAvg != null;
}

/// Headline numbers for the operations panel.
class OperationsMetrics {
  final int professionalsOnDuty;
  final int professionalsTotal;
  final int openRequests;
  final int completedToday;
  final int averageEtaMinutes;

  const OperationsMetrics({
    required this.professionalsOnDuty,
    required this.professionalsTotal,
    required this.openRequests,
    required this.completedToday,
    required this.averageEtaMinutes,
  });

  factory OperationsMetrics.fromJson(Map<String, dynamic> json) {
    return OperationsMetrics(
      professionalsOnDuty: _asInt(json['professionals_on_duty']),
      professionalsTotal: _asInt(json['professionals_total']),
      openRequests: _asInt(json['open_requests']),
      completedToday: _asInt(json['completed_today']),
      averageEtaMinutes: _asInt(json['average_eta_minutes']),
    );
  }
}

/// Load of a single dispatch zone.
class ZoneLoad {
  final String zone;
  final int openRequests;
  final int professionalsOnDuty;

  const ZoneLoad({
    required this.zone,
    required this.openRequests,
    required this.professionalsOnDuty,
  });

  factory ZoneLoad.fromJson(Map<String, dynamic> json) {
    return ZoneLoad(
      zone: json['zone'] as String? ?? 'General',
      openRequests: _asInt(json['open_requests']),
      professionalsOnDuty: _asInt(json['professionals_on_duty']),
    );
  }

  bool get uncovered => professionalsOnDuty == 0;
  bool get saturated => !uncovered && openRequests > professionalsOnDuty;
}

/// A provider row in the operations panel.
class ManagedProfessional {
  final String id;
  final String name;
  final String specialty;
  final String dutyStatus;
  final String? coverageZones;
  final bool active;

  const ManagedProfessional({
    required this.id,
    required this.name,
    required this.specialty,
    required this.dutyStatus,
    required this.active,
    this.coverageZones,
  });

  factory ManagedProfessional.fromJson(Map<String, dynamic> json) {
    return ManagedProfessional(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      specialty: json['specialty'] as String? ?? '',
      dutyStatus: json['duty_status'] as String? ?? 'disponible',
      coverageZones: json['coverage_zones'] as String?,
      active: json['active'] == true,
    );
  }
}

/// Una toma de muestras asignada o en curso vista por el laboratorista (REQ-15).
class StaffLabCollection {
  final String id;
  final String patientName;
  final String addressText;
  final String examRequired;
  final String status;
  final DateTime? startsAt;
  final String? clinicalNotes;
  final bool hasResult;

  const StaffLabCollection({
    required this.id,
    required this.patientName,
    required this.addressText,
    required this.examRequired,
    required this.status,
    this.startsAt,
    this.clinicalNotes,
    this.hasResult = false,
  });

  factory StaffLabCollection.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    final dependent = json['dependent'];
    String patient = 'Paciente';
    if (json['patient_type'] == 'dependent' && dependent is Map) {
      patient = '${dependent['name']} (${dependent['relationship'] ?? "Familiar"})';
    } else if (user is Map && user['name'] != null) {
      patient = '${user['name']}';
    }

    return StaffLabCollection(
      id: json['id'] as String,
      patientName: patient,
      addressText: json['address_text'] as String? ?? 'Sin dirección',
      examRequired: json['symptoms_description'] ?? json['exam_required'] ?? 'Examen de laboratorio',
      status: json['status'] as String? ?? 'scheduled',
      startsAt: json['scheduled_at'] != null ? DateTime.tryParse(json['scheduled_at'].toString()) : null,
      clinicalNotes: json['clinical_notes'] as String?,
      hasResult: json['has_result'] == true || json['result_delivered_at'] != null,
    );
  }
}
