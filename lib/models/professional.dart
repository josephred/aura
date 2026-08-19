class Professional {
  final String id;
  final String name;
  final String specialty;
  final String? bio;
  final int consultationPrice;
  final int consultationDurationMinutes;

  /// Registro de la Superintendencia de Salud. Null cuando el prestador aún no
  /// lo tiene cargado: es un dato verificable y no se inventa.
  final String? registrationNumber;
  final int? yearsOfExperience;
  final String? photoUrl;

  /// Promedio de evaluación, o null si todavía nadie evaluó a este profesional.
  final double? ratingAvg;
  final int ratingCount;

  const Professional({
    required this.id,
    required this.name,
    required this.specialty,
    this.bio,
    required this.consultationPrice,
    required this.consultationDurationMinutes,
    this.registrationNumber,
    this.yearsOfExperience,
    this.photoUrl,
    this.ratingAvg,
    this.ratingCount = 0,
  });

  factory Professional.fromJson(Map<String, dynamic> json) {
    return Professional(
      id: json['id'] as String,
      name: json['name'] as String,
      specialty: json['specialty'] as String,
      bio: json['bio'] as String?,
      consultationPrice: (json['consultation_price'] as num?)?.toInt() ?? 0,
      consultationDurationMinutes:
          (json['consultation_duration_minutes'] as num?)?.toInt() ?? 30,
      registrationNumber: json['registration_number'] as String?,
      yearsOfExperience: (json['years_of_experience'] as num?)?.toInt(),
      photoUrl: json['photo_url'] as String?,
      ratingAvg: (json['rating_avg'] as num?)?.toDouble(),
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// Ficha del profesional asignado que viaja dentro de una solicitud
  /// (`assigned_professional`), donde no hay precio ni duración de consulta.
  factory Professional.fromAssignment(Map<String, dynamic> json) {
    return Professional(
      id: (json['id'] ?? '') as String,
      name: (json['name'] ?? 'Profesional asignado') as String,
      specialty: (json['specialty'] ?? '') as String,
      bio: json['bio'] as String?,
      consultationPrice: 0,
      consultationDurationMinutes: 30,
      registrationNumber: json['registration_number'] as String?,
      yearsOfExperience: (json['years_of_experience'] as num?)?.toInt(),
      photoUrl: json['photo_url'] as String?,
      ratingAvg: (json['rating_avg'] as num?)?.toDouble(),
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
    );
  }

  bool get hasRating => ratingCount > 0 && ratingAvg != null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'specialty': specialty,
      'bio': bio,
      'consultation_price': consultationPrice,
      'consultation_duration_minutes': consultationDurationMinutes,
      'registration_number': registrationNumber,
      'years_of_experience': yearsOfExperience,
      'photo_url': photoUrl,
      'rating_avg': ratingAvg,
      'rating_count': ratingCount,
    };
  }

  Map<String, dynamic> toAssignmentJson() {
    return {
      'id': id,
      'name': name,
      'specialty': specialty,
      'bio': bio,
      'registration_number': registrationNumber,
      'years_of_experience': yearsOfExperience,
      'photo_url': photoUrl,
      'rating_avg': ratingAvg,
      'rating_count': ratingCount,
    };
  }
}
