class ChatSession {
  final int id;
  final String? title;
  final DateTime? lastMessageAt;
  final DateTime createdAt;

  ChatSession({
    required this.id,
    this.title,
    this.lastMessageAt,
    required this.createdAt,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    return ChatSession(
      id: json['id'] as int,
      title: json['title'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'last_message_at': lastMessageAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
