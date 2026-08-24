class Category {
  final int id;
  final String name;
  final String type;
  final bool isDefault;

  Category({
    required this.id,
    required this.name,
    required this.type,
    required this.isDefault,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int,
      name: json['name'] as String,
      type: json['type'] as String,
      isDefault: json['is_default'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'is_default': isDefault,
    };
  }
}
