class SavedAddress {
  final String id;
  final String label;
  final String text;

  const SavedAddress({
    required this.id,
    required this.label,
    required this.text,
  });

  SavedAddress copyWith({
    String? id,
    String? label,
    String? text,
  }) {
    return SavedAddress(
      id: id ?? this.id,
      label: label ?? this.label,
      text: text ?? this.text,
    );
  }

  factory SavedAddress.fromJson(Map<String, dynamic> json) {
    return SavedAddress(
      id: json['id'] as String,
      label: json['label'] as String,
      text: json['text'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'text': text,
    };
  }
}
