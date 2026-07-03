enum RequestStatus {
  pending,
  pendingPayment,
  accepted,
  enCamino,
  enAtencion,
  completed,
  cancelled;

  String toJson() {
    switch (this) {
      case RequestStatus.pending:
        return 'pending';
      case RequestStatus.pendingPayment:
        return 'pending_payment';
      case RequestStatus.accepted:
        return 'accepted';
      case RequestStatus.enCamino:
        return 'en_camino';
      case RequestStatus.enAtencion:
        return 'en_atencion';
      case RequestStatus.completed:
        return 'completed';
      case RequestStatus.cancelled:
        return 'cancelled';
    }
  }

  static RequestStatus fromJson(String value) {
    switch (value) {
      case 'pending':
        return RequestStatus.pending;
      case 'pending_payment':
        return RequestStatus.pendingPayment;
      case 'accepted':
        return RequestStatus.accepted;
      case 'en_camino':
        return RequestStatus.enCamino;
      case 'en_atencion':
        return RequestStatus.enAtencion;
      case 'completed':
        return RequestStatus.completed;
      case 'cancelled':
        return RequestStatus.cancelled;
      default:
        return RequestStatus.pending;
    }
  }
}

class ServiceRequest {
  final String id;
  final String serviceId;
  final RequestStatus status;
  final String patientType; // 'self' | 'dependent'
  final String? dependentId;
  final String addressText;
  final String? originAddress; // used for ambulance
  final String? destinationAddress; // used for ambulance
  final String? ambulanceType; // 'basic' | 'medicalized'
  final String? symptomsDescription;
  final String? prescriptionName;
  final String? prescriptionPreview;
  final String? prescriptionFile;
  final String? examRequired;
  final String paymentMethod; // 'credit' | 'mercadopago' | 'cash'
  final String? paymentUrl; // Mercado Pago checkout link while pending_payment
  final String? paymentStatus; // 'pending' | 'approved' | 'rejected'
  final int finalPrice;
  final String startTime;
  final int etaMinutes;
  final int currentStep; // 0: Solicitado, 1: Asignado, 2: En Camino, 3: En Atención, 4: Completado

  const ServiceRequest({
    required this.id,
    required this.serviceId,
    required this.status,
    required this.patientType,
    this.dependentId,
    required this.addressText,
    this.originAddress,
    this.destinationAddress,
    this.ambulanceType,
    this.symptomsDescription,
    this.prescriptionName,
    this.prescriptionPreview,
    this.prescriptionFile,
    this.examRequired,
    required this.paymentMethod,
    this.paymentUrl,
    this.paymentStatus,
    required this.finalPrice,
    required this.startTime,
    required this.etaMinutes,
    required this.currentStep,
  });

  ServiceRequest copyWith({
    String? id,
    String? serviceId,
    RequestStatus? status,
    String? patientType,
    String? dependentId,
    String? addressText,
    String? originAddress,
    String? destinationAddress,
    String? ambulanceType,
    String? symptomsDescription,
    String? prescriptionName,
    String? prescriptionPreview,
    String? prescriptionFile,
    String? examRequired,
    String? paymentMethod,
    String? paymentUrl,
    String? paymentStatus,
    int? finalPrice,
    String? startTime,
    int? etaMinutes,
    int? currentStep,
  }) {
    return ServiceRequest(
      id: id ?? this.id,
      serviceId: serviceId ?? this.serviceId,
      status: status ?? this.status,
      patientType: patientType ?? this.patientType,
      dependentId: dependentId ?? this.dependentId,
      addressText: addressText ?? this.addressText,
      originAddress: originAddress ?? this.originAddress,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      ambulanceType: ambulanceType ?? this.ambulanceType,
      symptomsDescription: symptomsDescription ?? this.symptomsDescription,
      prescriptionName: prescriptionName ?? this.prescriptionName,
      prescriptionPreview: prescriptionPreview ?? this.prescriptionPreview,
      prescriptionFile: prescriptionFile ?? this.prescriptionFile,
      examRequired: examRequired ?? this.examRequired,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentUrl: paymentUrl ?? this.paymentUrl,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      finalPrice: finalPrice ?? this.finalPrice,
      startTime: startTime ?? this.startTime,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      currentStep: currentStep ?? this.currentStep,
    );
  }

  factory ServiceRequest.fromJson(Map<String, dynamic> json) {
    return ServiceRequest(
      id: json['id'] as String,
      serviceId: (json['service_id'] ?? json['serviceId']) as String,
      status: RequestStatus.fromJson(json['status'] as String),
      patientType: (json['patient_type'] ?? json['patientType']) as String,
      dependentId: (json['dependent_id'] ?? json['dependentId']) as String?,
      addressText: (json['address_text'] ?? json['addressText']) as String,
      originAddress: (json['origin_address'] ?? json['originAddress']) as String?,
      destinationAddress: (json['destination_address'] ?? json['destinationAddress']) as String?,
      ambulanceType: (json['ambulance_type'] ?? json['ambulanceType']) as String?,
      symptomsDescription: (json['symptoms_description'] ?? json['symptomsDescription']) as String?,
      prescriptionName: (json['prescription_name'] ?? json['prescriptionName']) as String?,
      prescriptionPreview: (json['prescription_preview'] ?? json['prescriptionPreview']) as String?,
      prescriptionFile: (json['prescription_file'] ?? json['prescriptionFile']) as String?,
      examRequired: (json['exam_required'] ?? json['examRequired']) as String?,
      paymentMethod: (json['payment_method'] ?? json['paymentMethod']) as String,
      paymentUrl: (json['payment_url'] ?? json['paymentUrl']) as String?,
      paymentStatus: (json['payment_status'] ?? json['paymentStatus']) as String?,
      finalPrice: (json['final_price'] ?? json['finalPrice']) as int,
      startTime: (json['start_time'] ?? json['startTime']) as String,
      etaMinutes: (json['eta_minutes'] ?? json['etaMinutes']) as int,
      currentStep: (json['current_step'] ?? json['currentStep']) as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'service_id': serviceId,
      'status': status.toJson(),
      'patient_type': patientType,
      'dependent_id': dependentId,
      'address_text': addressText,
      'origin_address': originAddress,
      'destination_address': destinationAddress,
      'ambulance_type': ambulanceType,
      'symptoms_description': symptomsDescription,
      'prescription_name': prescriptionName,
      'prescription_preview': prescriptionPreview,
      'prescription_file': prescriptionFile,
      'exam_required': examRequired,
      'payment_method': paymentMethod,
      'payment_url': paymentUrl,
      'payment_status': paymentStatus,
      'final_price': finalPrice,
      'start_time': startTime,
      'eta_minutes': etaMinutes,
      'current_step': currentStep,
    };
  }
}
