class SavedPaymentMethod {
  final String id;
  final String type; // 'visa' | 'mastercard' | 'mercadopago'
  final String? last4;

  const SavedPaymentMethod({
    required this.id,
    required this.type,
    this.last4,
  });

  factory SavedPaymentMethod.fromJson(Map<String, dynamic> json) {
    return SavedPaymentMethod(
      id: json['id'] as String,
      type: json['type'] as String,
      last4: json['last4'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'last4': last4,
    };
  }
}
