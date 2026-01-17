/// 音色数据模型
class Voice {
  final String id;
  final String name;
  final String? description;
  final String createdAt;
  final String? coverUrl;

  const Voice({
    required this.id,
    required this.name,
    this.description,
    this.createdAt = '',
    this.coverUrl,
  });

  factory Voice.fromJson(Map<String, dynamic> json) {
    return Voice(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      coverUrl: json['cover_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'created_at': createdAt,
      'cover_url': coverUrl,
    };
  }

  Voice copyWith({
    String? id,
    String? name,
    String? description,
    String? createdAt,
    String? coverUrl,
  }) {
    return Voice(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      coverUrl: coverUrl ?? this.coverUrl,
    );
  }

  /// 格式化创建日期
  String get formattedDate {
    if (createdAt.isEmpty) return '';
    return createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt;
  }
}
