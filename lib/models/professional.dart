class Professional {
  final String id;
  final String name;
  final String specialty;
  final String? bio;
  final int consultationPrice;
  final int consultationDurationMinutes;

  Professional({
    required this.id,
    required this.name,
    required this.specialty,
    this.bio,
    required this.consultationPrice,
    required this.consultationDurationMinutes,
  });

  factory Professional.fromJson(Map<String, dynamic> json) {
    return Professional(
      id: json['id'] as String,
      name: json['name'] as String,
      specialty: json['specialty'] as String,
      bio: json['bio'] as String?,
      consultationPrice: (json['consultation_price'] as num).toInt(),
      consultationDurationMinutes:
          (json['consultation_duration_minutes'] as num?)?.toInt() ?? 30,
    );
  }
}
