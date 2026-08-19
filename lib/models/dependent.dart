class Dependent {
  final String id;
  final String name;
  final String relationship;
  final int age;
  final String healthInsurance;
  final String medicalConditions;
  final DateTime? birthDate;
  final int? ageMonths;

  const Dependent({
    required this.id,
    required this.name,
    required this.relationship,
    required this.age,
    required this.healthInsurance,
    required this.medicalConditions,
    this.birthDate,
    this.ageMonths,
  });

  /// Edad precisa en meses basada en birthDate o ageMonths.
  int get calculatedAgeMonths {
    if (birthDate != null) {
      final now = DateTime.now();
      int months = (now.year - birthDate!.year) * 12 + (now.month - birthDate!.month);
      if (now.day < birthDate!.day) {
        months--;
      }
      return months >= 0 ? months : 0;
    }
    return ageMonths ?? (age * 12);
  }

  Dependent copyWith({
    String? id,
    String? name,
    String? relationship,
    int? age,
    String? healthInsurance,
    String? medicalConditions,
    DateTime? birthDate,
    int? ageMonths,
  }) {
    return Dependent(
      id: id ?? this.id,
      name: name ?? this.name,
      relationship: relationship ?? this.relationship,
      age: age ?? this.age,
      healthInsurance: healthInsurance ?? this.healthInsurance,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      birthDate: birthDate ?? this.birthDate,
      ageMonths: ageMonths ?? this.ageMonths,
    );
  }

  factory Dependent.fromJson(Map<String, dynamic> json) {
    DateTime? parsedBirthDate;
    if (json['birth_date'] != null) {
      parsedBirthDate = DateTime.tryParse(json['birth_date'].toString());
    }

    return Dependent(
      id: json['id'] as String,
      name: json['name'] as String,
      relationship: json['relationship'] as String,
      age: (json['age'] as num?)?.toInt() ?? 0,
      healthInsurance: json['health_insurance'] as String? ?? 'Fonasa',
      medicalConditions: json['medical_conditions'] as String? ?? '',
      birthDate: parsedBirthDate,
      ageMonths: (json['age_months'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'relationship': relationship,
      'age': age,
      'health_insurance': healthInsurance,
      'medical_conditions': medicalConditions,
      if (birthDate != null) 'birth_date': birthDate!.toIso8601String().split('T').first,
      if (ageMonths != null) 'age_months': ageMonths,
    };
  }
}
