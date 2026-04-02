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

class UtteranceTask {
  final String sessionId;
  final String taskId;
  final int utteranceIndex;
  final TaskState state;
  final int? durationMs;
  final String? error;
  final DateTime createdAt;
  final int version;

  const UtteranceTask({
    required this.sessionId,
    this.taskId = '',
    required this.utteranceIndex,
    this.state = TaskState.pending,
    this.durationMs,
    this.error,
    required this.createdAt,
    this.version = 0,
  });

  UtteranceTask copyWith({
    String? sessionId,
    String? taskId,
    int? utteranceIndex,
    TaskState? state,
    int? durationMs,
    String? error,
    DateTime? createdAt,
    int? version,
  }) {
    return UtteranceTask(
      sessionId: sessionId ?? this.sessionId,
      taskId: taskId ?? this.taskId,
      utteranceIndex: utteranceIndex ?? this.utteranceIndex,
      state: state ?? this.state,
      durationMs: durationMs ?? this.durationMs,
      error: error ?? this.error,
      createdAt: createdAt ?? this.createdAt,
      version: version ?? this.version,
    );
  }
}

class TaskInfo {
  final String taskId;
  final int utteranceIndex;
  final String state;
  final String? cacheKey;
  final int? durationMs;
  final String? error;

  const TaskInfo({
    required this.taskId,
    this.utteranceIndex = -1,
    required this.state,
    this.cacheKey,
    this.durationMs,
    this.error,
  });

  factory TaskInfo.fromJson(Map<String, dynamic> json) {
    return TaskInfo(
      taskId: json['task_id'] as String? ?? json['id'] as String? ?? '',
      utteranceIndex: json['utterance_index'] as int? ?? json['segment_index'] as int? ?? json['index'] as int? ?? -1,
      state: json['state'] as String? ?? json['status'] as String? ?? 'pending',
      cacheKey: json['cache_key'] as String?,
      durationMs: json['duration_ms'] as int?,
      error: json['error'] as String?,
    );
  }
}
