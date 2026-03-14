/// 音色数据模型
class Voice {
  final String id;
  final String name;
  final String? description;
  final String createdAt;
  final String? coverUrl;
  final String? gender;
  final String? ageGroup;
  final List<String> tags;

  const Voice({
    required this.id,
    required this.name,
    this.description,
    this.createdAt = '',
    this.coverUrl,
    this.gender,
    this.ageGroup,
    this.tags = const [],
  });

  factory Voice.fromJson(Map<String, dynamic> json) {
    return Voice(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      coverUrl: json['cover_url'] as String?,
      gender: json['gender'] as String?,
      ageGroup: json['age_group'] as String?,
      tags: (json['tags'] as List?)?.map((e) => e as String).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'created_at': createdAt,
      'cover_url': coverUrl,
      if (gender != null) 'gender': gender,
      if (ageGroup != null) 'age_group': ageGroup,
      if (tags.isNotEmpty) 'tags': tags,
    };
  }

  Voice copyWith({
    String? id,
    String? name,
    String? description,
    String? createdAt,
    String? coverUrl,
    String? gender,
    String? ageGroup,
    List<String>? tags,
  }) {
    return Voice(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      coverUrl: coverUrl ?? this.coverUrl,
      gender: gender ?? this.gender,
      ageGroup: ageGroup ?? this.ageGroup,
      tags: tags ?? this.tags,
    );
  }

  /// 格式化创建日期
  String get formattedDate {
    if (createdAt.isEmpty) return '';
    return createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt;
  }

  /// 性别显示标签
  String get genderLabel {
    switch (gender) {
      case 'male':
        return '男';
      case 'female':
        return '女';
      default:
        return '';
    }
  }

  /// 年龄段显示标签
  String get ageGroupLabel {
    switch (ageGroup) {
      case 'child':
        return '儿童';
      case 'young':
        return '青年';
      case 'middle':
        return '中年';
      case 'elder':
        return '老年';
      default:
        return '';
    }
  }

  /// 获取所有显示标签（包含性别、年龄段和自定义标签）
  List<String> get allDisplayTags {
    final result = <String>[];
    if (genderLabel.isNotEmpty) result.add(genderLabel);
    if (ageGroupLabel.isNotEmpty) result.add(ageGroupLabel);
    result.addAll(tags);
    return result;
  }
}
