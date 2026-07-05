enum AppointmentStatus {
  pendingPayment,
  confirmed,
  completed,
  cancelled,
  noShow,
  unknown,
}

class Appointment {
  final String id;
  final String professionalId;
  final String? professionalName;
  final String? specialty;
  final DateTime scheduledAt;
  final int durationMinutes;
  final String? reason;
  final AppointmentStatus status;
  final int price;
  final String? paymentUrl;
  final String? paymentStatus;
  final String type; // 'presencial' | 'video'
  final bool hasVideoRoom;

  Appointment({
    required this.id,
    required this.professionalId,
    this.professionalName,
    this.specialty,
    required this.scheduledAt,
    required this.durationMinutes,
    this.reason,
    required this.status,
    required this.price,
    this.paymentUrl,
    this.paymentStatus,
    this.type = 'presencial',
    this.hasVideoRoom = false,
  });

  static AppointmentStatus _statusFrom(String? raw) {
    switch (raw) {
      case 'pending_payment':
        return AppointmentStatus.pendingPayment;
      case 'confirmed':
        return AppointmentStatus.confirmed;
      case 'completed':
        return AppointmentStatus.completed;
      case 'cancelled':
        return AppointmentStatus.cancelled;
      case 'no_show':
        return AppointmentStatus.noShow;
      default:
        return AppointmentStatus.unknown;
    }
  }

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'] as String,
      professionalId: json['professional_id'] as String,
      professionalName: json['professional_name'] as String?,
      specialty: json['specialty'] as String?,
      scheduledAt: DateTime.parse(json['scheduled_at'] as String).toLocal(),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 30,
      reason: json['reason'] as String?,
      status: _statusFrom(json['status'] as String?),
      price: (json['price'] as num).toInt(),
      paymentUrl: json['payment_url'] as String?,
      paymentStatus: json['payment_status'] as String?,
      type: (json['type'] as String?) ?? 'presencial',
      hasVideoRoom: (json['has_video_room'] as bool?) ?? false,
    );
  }

  bool get isUpcoming =>
      (status == AppointmentStatus.confirmed ||
          status == AppointmentStatus.pendingPayment) &&
      scheduledAt.isAfter(DateTime.now());

  bool get isVideo => type == 'video';

  // Join window mirrors the backend: 15 min before start until 30 min
  // after the scheduled end
  bool get canJoinVideo {
    if (!isVideo || !hasVideoRoom || status != AppointmentStatus.confirmed) {
      return false;
    }
    final now = DateTime.now();
    return now.isAfter(scheduledAt.subtract(const Duration(minutes: 15))) &&
        now.isBefore(
            scheduledAt.add(Duration(minutes: durationMinutes + 30)));
  }
}
