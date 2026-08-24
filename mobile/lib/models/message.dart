class Message {
  final int id;
  final String role;
  final String content;
  final String status;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.role,
    required this.content,
    required this.status,
    this.metadata,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as int,
      role: json['role'] as String,
      content: json['content'] as String? ?? '',
      status: json['status'] as String? ?? 'completed',
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'content': content,
      'status': status,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isPending => status == 'pending' || status == 'processing';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
}
