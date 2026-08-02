/// Modelos del Módulo E — laboratorio.
///
/// La toma de muestras no se despacha como urgencia: el paciente elige un cupo
/// que el laboratorista publicó antes. Por eso tiene sus propios modelos y no
/// reutiliza [ServiceRequest], que asume "alguien va en camino ahora".
library;

/// Un cupo libre publicado por un laboratorista.
class LabSlot {
  final int scheduleId;
  final String professionalId;
  final String professionalName;
  final String? zone;
  final DateTime startsAt;
  final DateTime endsAt;

  /// Etiqueta corta del bloque, p. ej. "08:00 - 08:30".
  final String label;

  /// Tomas que aún admite el cupo.
  final int remaining;

  const LabSlot({
    required this.scheduleId,
    required this.professionalId,
    required this.professionalName,
    required this.startsAt,
    required this.endsAt,
    required this.label,
    required this.remaining,
    this.zone,
  });

  factory LabSlot.fromJson(Map<String, dynamic> json) {
    return LabSlot(
      scheduleId: (json['schedule_id'] as num).toInt(),
      professionalId: json['professional_id'] as String,
      professionalName: (json['professional_name'] ?? 'Laboratorio') as String,
      zone: json['zone'] as String?,
      startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
      endsAt: DateTime.parse(json['ends_at'] as String).toLocal(),
      label: (json['label'] ?? '') as String,
      remaining: (json['remaining'] as num?)?.toInt() ?? 1,
    );
  }
}

/// Una toma de muestras agendada.
class LabRequest {
  final String id;
  final String status;
  final DateTime? scheduledAt;

  /// Fecha ya redactada por el servidor ("jueves 7 de agosto a las 08:30"),
  /// para no reimplementar el formato en español en el cliente.
  final String? scheduledLabel;
  final String addressText;
  final String? zone;
  final String? examRequired;
  final String? clinicalNotes;
  final String? professionalName;
  final int finalPrice;
  final String? paymentUrl;
  final String? paymentStatus;
  final int resultsCount;

  const LabRequest({
    required this.id,
    required this.status,
    required this.addressText,
    required this.finalPrice,
    this.scheduledAt,
    this.scheduledLabel,
    this.zone,
    this.examRequired,
    this.clinicalNotes,
    this.professionalName,
    this.paymentUrl,
    this.paymentStatus,
    this.resultsCount = 0,
  });

  factory LabRequest.fromJson(Map<String, dynamic> json) {
    return LabRequest(
      id: json['id'] as String,
      status: (json['status'] ?? 'pending_payment') as String,
      scheduledAt: json['scheduled_at'] != null
          ? DateTime.parse(json['scheduled_at'] as String).toLocal()
          : null,
      scheduledLabel: json['scheduled_label'] as String?,
      addressText: (json['address_text'] ?? '') as String,
      zone: json['zone'] as String?,
      examRequired: json['exam_required'] as String?,
      clinicalNotes: json['clinical_notes'] as String?,
      professionalName: json['professional_name'] as String?,
      finalPrice: (json['final_price'] as num?)?.toInt() ?? 0,
      paymentUrl: json['payment_url'] as String?,
      paymentStatus: json['payment_status'] as String?,
      resultsCount: (json['results_count'] as num?)?.toInt() ?? 0,
    );
  }

  bool get awaitsPayment => status == 'pending_payment';

  bool get isCancellable =>
      status == 'pending_payment' || status == 'scheduled' || status == 'accepted';

  String get statusLabel => switch (status) {
        'pending_payment' => 'Pago pendiente',
        'scheduled' => 'Agendada',
        'accepted' => 'Confirmada',
        'en_camino' => 'En camino',
        'en_atencion' => 'En tu domicilio',
        'completed' => 'Realizada',
        'cancelled' => 'Cancelada',
        _ => status,
      };
}

/// Un informe de laboratorio disponible en "Mis Exámenes".
class LabResult {
  final String id;
  final String serviceRequestId;
  final String title;
  final String? notes;
  final String fileName;
  final int fileSize;
  final DateTime? issuedAt;
  final DateTime? emailedAt;

  /// URL autenticada de descarga. Requiere la sesión del paciente: no es un
  /// enlace público y no debe compartirse como si lo fuera.
  final String downloadUrl;

  const LabResult({
    required this.id,
    required this.serviceRequestId,
    required this.title,
    required this.fileName,
    required this.downloadUrl,
    this.notes,
    this.fileSize = 0,
    this.issuedAt,
    this.emailedAt,
  });

  factory LabResult.fromJson(Map<String, dynamic> json) {
    return LabResult(
      id: json['id'] as String,
      serviceRequestId: (json['service_request_id'] ?? '') as String,
      title: (json['title'] ?? 'Informe de laboratorio') as String,
      notes: json['notes'] as String?,
      fileName: (json['file_name'] ?? 'informe.pdf') as String,
      fileSize: (json['file_size'] as num?)?.toInt() ?? 0,
      issuedAt: json['issued_at'] != null
          ? DateTime.parse(json['issued_at'] as String).toLocal()
          : null,
      emailedAt: json['emailed_at'] != null
          ? DateTime.parse(json['emailed_at'] as String).toLocal()
          : null,
      downloadUrl: (json['download_url'] ?? '') as String,
    );
  }

  /// Tamaño legible; devuelve null cuando el servidor no lo informó.
  String? get readableSize {
    if (fileSize <= 0) return null;
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).round()} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
