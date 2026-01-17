/// 任务状态枚举
enum TaskState {
  pending,
  inferring,
  ready,
  failed,
  cancelled;

  static TaskState fromString(String s) {
    switch (s) {
      case 'pending':
        return TaskState.pending;
      case 'inferring':
        return TaskState.inferring;
      case 'ready':
        return TaskState.ready;
      case 'failed':
        return TaskState.failed;
      case 'cancelled':
        return TaskState.cancelled;
      default:
        return TaskState.pending;
    }
  }

  String toJson() => name;
}

/// 段落任务数据模型
class SegmentTask {
  final String sessionId;
  final String taskId;
  final int segmentIndex;
  final TaskState state;
  final int? durationMs;
  final String? error;
  final DateTime createdAt;

  const SegmentTask({
    required this.sessionId,
    this.taskId = '',
    required this.segmentIndex,
    this.state = TaskState.pending,
    this.durationMs,
    this.error,
    required this.createdAt,
  });

  SegmentTask copyWith({
    String? sessionId,
    String? taskId,
    int? segmentIndex,
    TaskState? state,
    int? durationMs,
    String? error,
    DateTime? createdAt,
  }) {
    return SegmentTask(
      sessionId: sessionId ?? this.sessionId,
      taskId: taskId ?? this.taskId,
      segmentIndex: segmentIndex ?? this.segmentIndex,
      state: state ?? this.state,
      durationMs: durationMs ?? this.durationMs,
      error: error ?? this.error,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// 任务信息（API 返回）
class TaskInfo {
  final String taskId;
  final int segmentIndex;
  final String state;

  const TaskInfo({
    required this.taskId,
    required this.segmentIndex,
    required this.state,
  });

  factory TaskInfo.fromJson(Map<String, dynamic> json) {
    return TaskInfo(
      taskId: json['task_id'] as String,
      segmentIndex: json['segment_index'] as int,
      state: json['state'] as String,
    );
  }
}
