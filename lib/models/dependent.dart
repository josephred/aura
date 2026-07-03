class Dependent {
  final String id;
  final String name;
  final String relationship;
  final int age;
  final String healthInsurance;
  final String medicalConditions;

  const Dependent({
    required this.id,
    required this.name,
    required this.relationship,
    required this.age,
    required this.healthInsurance,
    required this.medicalConditions,
  });

  Dependent copyWith({
    String? id,
    String? name,
    String? relationship,
    int? age,
    String? healthInsurance,
    String? medicalConditions,
  }) {
    return Dependent(
      id: id ?? this.id,
      name: name ?? this.name,
      relationship: relationship ?? this.relationship,
      age: age ?? this.age,
      healthInsurance: healthInsurance ?? this.healthInsurance,
      medicalConditions: medicalConditions ?? this.medicalConditions,
    );
  }

  factory Dependent.fromJson(Map<String, dynamic> json) {
    return Dependent(
      id: json['id'] as String,
      name: json['name'] as String,
      relationship: json['relationship'] as String,
      age: json['age'] as int,
      healthInsurance: json['health_insurance'] as String,
      medicalConditions: json['medical_conditions'] as String? ?? '',
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
    };
  }
}
