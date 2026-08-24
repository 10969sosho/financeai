import 'category.dart';

class Transaction {
  final int id;
  final String type;
  final int amount;
  final String description;
  final Category? category;
  final DateTime occurredAt;
  final String source;

  Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    this.category,
    required this.occurredAt,
    required this.source,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as int,
      type: json['type'] as String,
      amount: json['amount'] as int,
      description: json['description'] as String,
      category: json['category'] != null
          ? Category.fromJson(json['category'] as Map<String, dynamic>)
          : null,
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      source: json['source'] as String? ?? 'manual',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'description': description,
      'category': category?.toJson(),
      'occurred_at': occurredAt.toIso8601String(),
      'source': source,
    };
  }

  String get formattedAmount {
    return 'Rp${amount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        )}';
  }
}
