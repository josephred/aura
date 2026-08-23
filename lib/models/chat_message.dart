class ChatMessage {
  final String id;
  final String sender; // 'patient' | 'provider' | 'system'
  final String? senderName; // Real name of the professional, when known
  final String text;
  final String timestamp;

  const ChatMessage({
    required this.id,
    required this.sender,
    this.senderName,
    required this.text,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: (json['id'] ?? '').toString(),
      sender: (json['sender'] ?? 'system').toString(),
      senderName: json['sender_name']?.toString(),
      text: (json['text'] ?? '').toString(),
      timestamp: (json['timestamp'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender': sender,
      'sender_name': senderName,
      'text': text,
      'timestamp': timestamp,
    };
  }
}
