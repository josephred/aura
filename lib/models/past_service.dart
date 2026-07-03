class PastService {
  final String id;
  final String serviceTitle;
  final String serviceId;
  final String date;
  final String patient;
  final int price;
  final String status;
  final String details;
  final String professional;

  const PastService({
    required this.id,
    required this.serviceTitle,
    required this.serviceId,
    required this.date,
    required this.patient,
    required this.price,
    required this.status,
    required this.details,
    required this.professional,
  });

  factory PastService.fromJson(Map<String, dynamic> json) {
    return PastService(
      id: json['id'] as String,
      serviceTitle: json['service_title'] as String,
      serviceId: json['service_id'] as String,
      date: json['date'] as String,
      patient: json['patient'] as String,
      price: json['price'] as int,
      status: json['status'] as String,
      details: json['details'] as String,
      professional: json['professional'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'service_title': serviceTitle,
      'service_id': serviceId,
      'date': date,
      'patient': patient,
      'price': price,
      'status': status,
      'details': details,
      'professional': professional,
    };
  }
}
