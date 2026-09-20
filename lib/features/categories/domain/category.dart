/// Represents a customizable vault category (e.g. Investments, Keys & Storage, Insurance)
class Category {
  final String id;
  final String vaultId;
  final String name;
  final String? description;
  final String icon;
  final String color;
  final int position;
  final bool isLocked;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int recordCount;

  const Category({
    required this.id,
    required this.vaultId,
    required this.name,
    this.description,
    required this.icon,
    this.color = '#1D5D5B',
    this.position = 0,
    this.isLocked = false,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.recordCount = 0,
  });

  Category copyWith({
    String? name,
    String? description,
    String? icon,
    String? color,
    int? position,
    bool? isLocked,
    int? recordCount,
  }) {
    return Category(
      id: id,
      vaultId: vaultId,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      position: position ?? this.position,
      isLocked: isLocked ?? this.isLocked,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      recordCount: recordCount ?? this.recordCount,
    );
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      vaultId: json['vault_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String? ?? 'folder',
      color: json['color'] as String? ?? '#1D5D5B',
      position: json['position'] as int? ?? 0,
      isLocked: json['is_locked'] as bool? ?? false,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      recordCount: json['record_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vault_id': vaultId,
      'name': name,
      'description': description,
      'icon': icon,
      'color': color,
      'position': position,
      'is_locked': isLocked,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
