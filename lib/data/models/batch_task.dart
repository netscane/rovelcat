/// 批量任务状态枚举
enum BatchTaskStatus {
  running,
  paused,
  cancelled,
  completed,
  failed;

  static BatchTaskStatus fromString(String s) {
    switch (s.toLowerCase()) {
      case 'running':
        return BatchTaskStatus.running;
      case 'paused':
        return BatchTaskStatus.paused;
      case 'cancelled':
        return BatchTaskStatus.cancelled;
      case 'completed':
        return BatchTaskStatus.completed;
      case 'failed':
        return BatchTaskStatus.failed;
      default:
        return BatchTaskStatus.running;
    }
  }

  String toJson() => name;

  String get displayName {
    switch (this) {
      case BatchTaskStatus.running:
        return '运行中';
      case BatchTaskStatus.paused:
        return '已暂停';
      case BatchTaskStatus.cancelled:
        return '已取消';
      case BatchTaskStatus.completed:
        return '已完成';
      case BatchTaskStatus.failed:
        return '失败';
    }
  }
}

/// 批量任务数据模型
class BatchTask {
  final String taskId;
  final String novelId;
  final String voiceId;
  final int segmentStart;
  final int segmentEnd;
  final int currentIndex;
  final int totalSegments;
  final BatchTaskStatus status;
  final double progressPercent;
  final String? errorMessage;

  const BatchTask({
    required this.taskId,
    required this.novelId,
    required this.voiceId,
    required this.segmentStart,
    required this.segmentEnd,
    required this.currentIndex,
    required this.totalSegments,
    required this.status,
    required this.progressPercent,
    this.errorMessage,
  });

  factory BatchTask.fromJson(Map<String, dynamic> json) {
    return BatchTask(
      taskId: json['task_id'] as String,
      novelId: json['novel_id'] as String,
      voiceId: json['voice_id'] as String,
      segmentStart: json['segment_start'] as int,
      segmentEnd: json['segment_end'] as int,
      currentIndex: json['current_index'] as int,
      totalSegments: json['total_segments'] as int,
      status: BatchTaskStatus.fromString(json['status'] as String),
      progressPercent: (json['progress_percent'] as num).toDouble(),
      errorMessage: json['error_message'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'task_id': taskId,
      'novel_id': novelId,
      'voice_id': voiceId,
      'segment_start': segmentStart,
      'segment_end': segmentEnd,
      'current_index': currentIndex,
      'total_segments': totalSegments,
      'status': status.toJson(),
      'progress_percent': progressPercent,
      'error_message': errorMessage,
    };
  }

  BatchTask copyWith({
    String? taskId,
    String? novelId,
    String? voiceId,
    int? segmentStart,
    int? segmentEnd,
    int? currentIndex,
    int? totalSegments,
    BatchTaskStatus? status,
    double? progressPercent,
    String? errorMessage,
  }) {
    return BatchTask(
      taskId: taskId ?? this.taskId,
      novelId: novelId ?? this.novelId,
      voiceId: voiceId ?? this.voiceId,
      segmentStart: segmentStart ?? this.segmentStart,
      segmentEnd: segmentEnd ?? this.segmentEnd,
      currentIndex: currentIndex ?? this.currentIndex,
      totalSegments: totalSegments ?? this.totalSegments,
      status: status ?? this.status,
      progressPercent: progressPercent ?? this.progressPercent,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// 是否可以暂停
  bool get canPause => status == BatchTaskStatus.running;

  /// 是否可以恢复
  bool get canResume => status == BatchTaskStatus.paused;

  /// 是否可以取消
  bool get canCancel =>
      status == BatchTaskStatus.running || status == BatchTaskStatus.paused;

  /// 是否已结束
  bool get isFinished =>
      status == BatchTaskStatus.completed ||
      status == BatchTaskStatus.cancelled ||
      status == BatchTaskStatus.failed;
}
