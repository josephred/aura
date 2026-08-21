class SubscriptionPlan {
  final String id;
  final String name;
  final String description;
  final int monthlyPrice;
  final int includedConsultations;
  final int discountPercentage;
  final List<String> features;
  final bool active;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.monthlyPrice,
    required this.includedConsultations,
    required this.discountPercentage,
    required this.features,
    required this.active,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    var rawFeatures = json['features'];
    List<String> featureList = [];
    if (rawFeatures is List) {
      featureList = rawFeatures.map((e) => e.toString()).toList();
    }

    return SubscriptionPlan(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      monthlyPrice: (json['monthly_price'] as num?)?.toInt() ?? 0,
      includedConsultations: (json['included_consultations'] as num?)?.toInt() ?? 0,
      discountPercentage: (json['discount_percentage'] as num?)?.toInt() ?? 0,
      features: featureList,
      active: json['active'] == true || json['active'] == 1,
    );
  }
}

class UserSubscriptionInfo {
  final bool hasSubscription;
  final String status;
  final SubscriptionPlan? plan;
  final int includedConsultations;
  final int usedConsultations;
  final int remainingConsultations;
  final int discountPercentage;
  final DateTime? nextBillingDate;
  final DateTime? expiresAt;

  const UserSubscriptionInfo({
    required this.hasSubscription,
    required this.status,
    this.plan,
    required this.includedConsultations,
    required this.usedConsultations,
    required this.remainingConsultations,
    required this.discountPercentage,
    this.nextBillingDate,
    this.expiresAt,
  });

  factory UserSubscriptionInfo.fromJson(Map<String, dynamic> json) {
    return UserSubscriptionInfo(
      hasSubscription: json['has_subscription'] == true,
      status: json['status'] as String? ?? 'none',
      plan: json['plan'] != null ? SubscriptionPlan.fromJson(json['plan'] as Map<String, dynamic>) : null,
      includedConsultations: (json['included_consultations'] as num?)?.toInt() ?? 0,
      usedConsultations: (json['used_consultations'] as num?)?.toInt() ?? 0,
      remainingConsultations: (json['remaining_consultations'] as num?)?.toInt() ?? 0,
      discountPercentage: (json['discount_percentage'] as num?)?.toInt() ?? 0,
      nextBillingDate: json['next_billing_date'] != null ? DateTime.tryParse(json['next_billing_date'].toString()) : null,
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at'].toString()) : null,
    );
  }
}
