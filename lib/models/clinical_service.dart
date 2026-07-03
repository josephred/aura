class ClinicalService {
  final String id;
  final String title;
  final String shortTitle;
  final String subtitle;
  final String description;
  final int basePrice;
  final String baseEta;
  final bool requiresPrescription;
  final String iconName;
  final String? warningInfo;
  final String? placeholderText;

  const ClinicalService({
    required this.id,
    required this.title,
    required this.shortTitle,
    required this.subtitle,
    required this.description,
    required this.basePrice,
    required this.baseEta,
    required this.requiresPrescription,
    required this.iconName,
    this.warningInfo,
    this.placeholderText,
  });

  factory ClinicalService.fromJson(Map<String, dynamic> json) {
    return ClinicalService(
      id: json['id'] as String,
      title: json['title'] as String,
      shortTitle: json['short_title'] as String,
      subtitle: json['subtitle'] as String,
      description: json['description'] as String,
      basePrice: json['base_price'] as int,
      baseEta: json['base_eta'] as String,
      requiresPrescription: (json['requires_prescription'] == 1 || json['requires_prescription'] == true),
      iconName: json['icon_name'] as String,
      warningInfo: json['warning_info'] as String?,
      placeholderText: json['placeholder_text'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'short_title': shortTitle,
      'subtitle': subtitle,
      'description': description,
      'base_price': basePrice,
      'base_eta': baseEta,
      'requires_prescription': requiresPrescription ? 1 : 0,
      'icon_name': iconName,
      'warning_info': warningInfo,
      'placeholder_text': placeholderText,
    };
  }
}
