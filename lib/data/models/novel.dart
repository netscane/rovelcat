import 'package:uuid/uuid.dart';

/// 小说状态枚举
enum NovelStatus {
  uploading,
  processing,
  ready,
  error,
  deleting;

  static NovelStatus fromString(String s) {
    switch (s) {
      case 'uploading':
        return NovelStatus.uploading;
      case 'processing':
        return NovelStatus.processing;
      case 'ready':
        return NovelStatus.ready;
      case 'error':
        return NovelStatus.error;
      case 'deleting':
        return NovelStatus.deleting;
      default:
        return NovelStatus.ready;
    }
  }

  String toJson() => name;
}

/// 小说数据模型
class Novel {
  final String id;
  final String title;
  final int totalSegments;
  final NovelStatus status;
  final String createdAt;
  final bool isTemporary;
  final String? coverUrl;

  const Novel({
    required this.id,
    required this.title,
    this.totalSegments = 0,
    this.status = NovelStatus.ready,
    this.createdAt = '',
    this.isTemporary = false,
    this.coverUrl,
  });

  factory Novel.fromJson(Map<String, dynamic> json) {
    return Novel(
      id: json['id'] as String,
      title: json['title'] as String,
      totalSegments: json['total_segments'] as int? ?? 0,
      status: NovelStatus.fromString(json['status'] as String? ?? 'ready'),
      createdAt: json['created_at'] as String? ?? '',
      isTemporary: json['is_temporary'] as bool? ?? false,
      coverUrl: json['cover_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'total_segments': totalSegments,
      'status': status.toJson(),
      'created_at': createdAt,
      'is_temporary': isTemporary,
      'cover_url': coverUrl,
    };
  }

  factory Novel.createTemporary(String title) {
    return Novel(
      id: const Uuid().v4(),
      title: title,
      totalSegments: 0,
      status: NovelStatus.uploading,
      createdAt: DateTime.now().toIso8601String(),
      isTemporary: true,
    );
  }

  Novel copyWith({
    String? id,
    String? title,
    int? totalSegments,
    NovelStatus? status,
    String? createdAt,
    bool? isTemporary,
    String? coverUrl,
  }) {
    return Novel(
      id: id ?? this.id,
      title: title ?? this.title,
      totalSegments: totalSegments ?? this.totalSegments,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      isTemporary: isTemporary ?? this.isTemporary,
      coverUrl: coverUrl ?? this.coverUrl,
    );
  }

  /// 是否可以播放
  bool get canPlay => status == NovelStatus.ready;

  /// 格式化创建日期
  String get formattedDate {
    if (createdAt.isEmpty) return '';
    return createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt;
  }
}
