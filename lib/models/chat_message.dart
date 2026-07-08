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
      id: json['id'] as String,
      sender: json['sender'] as String,
      senderName: json['sender_name'] as String?,
      text: json['text'] as String,
      timestamp: json['timestamp'] as String,
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
