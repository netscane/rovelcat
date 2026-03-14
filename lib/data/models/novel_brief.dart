/// Speaker 信息（来自 novel/brief API）
class SpeakerInfo {
  final String name;
  final int utteranceCount;
  final String? voiceId;
  final String? voiceName;
  final String? importance;

  const SpeakerInfo({
    required this.name,
    this.utteranceCount = 0,
    this.voiceId,
    this.voiceName,
    this.importance,
  });

  factory SpeakerInfo.fromJson(Map<String, dynamic> json) {
    return SpeakerInfo(
      name: json['name'] as String? ?? json['speaker'] as String? ?? '未知',
      utteranceCount: json['utterance_count'] as int? ?? json['count'] as int? ?? 0,
      voiceId: json['voice_id'] as String?,
      voiceName: json['voice_name'] as String?,
      importance: json['importance'] as String?,
    );
  }

  /// 是否已分配音色
  bool get hasVoice => voiceId != null && voiceId!.isNotEmpty;
}

/// Worker 解析状态
class WorkerStatus {
  final int totalCharacters;
  final int newCharacters;
  final int stableCharacters;
  final int conflictCharacters;
  final bool parseCompleted;

  const WorkerStatus({
    this.totalCharacters = 0,
    this.newCharacters = 0,
    this.stableCharacters = 0,
    this.conflictCharacters = 0,
    this.parseCompleted = false,
  });

  factory WorkerStatus.fromJson(Map<String, dynamic> json) {
    return WorkerStatus(
      totalCharacters: json['total_characters'] as int? ?? 0,
      newCharacters: json['new_characters'] as int? ?? 0,
      stableCharacters: json['stable_characters'] as int? ?? 0,
      conflictCharacters: json['conflict_characters'] as int? ?? 0,
      parseCompleted: json['parse_completed'] as bool? ?? false,
    );
  }
}

/// 音色分配摘要
class AssignmentSummary {
  final int assignedCount;
  final int unassignedCount;
  final int manualCount;
  final int autoCount;
  final int poolCount;
  final int conflictCount;

  const AssignmentSummary({
    this.assignedCount = 0,
    this.unassignedCount = 0,
    this.manualCount = 0,
    this.autoCount = 0,
    this.poolCount = 0,
    this.conflictCount = 0,
  });

  factory AssignmentSummary.fromJson(Map<String, dynamic> json) {
    return AssignmentSummary(
      assignedCount: json['assigned_count'] as int? ?? 0,
      unassignedCount: json['unassigned_count'] as int? ?? 0,
      manualCount: json['manual_count'] as int? ?? 0,
      autoCount: json['auto_count'] as int? ?? 0,
      poolCount: json['pool_count'] as int? ?? 0,
      conflictCount: json['conflict_count'] as int? ?? 0,
    );
  }

  /// 总角色数
  int get totalCount => assignedCount + unassignedCount;
}

/// 小说概要信息（来自 /novel/brief API）
class NovelBrief {
  final String id;
  final String title;
  final String status;
  final int totalUtterances;
  final WorkerStatus worker;
  final AssignmentSummary summary;
  final List<SpeakerInfo> speakers;

  const NovelBrief({
    required this.id,
    required this.title,
    this.status = '',
    this.totalUtterances = 0,
    this.worker = const WorkerStatus(),
    this.summary = const AssignmentSummary(),
    this.speakers = const [],
  });

  factory NovelBrief.fromJson(Map<String, dynamic> json) {
    return NovelBrief(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? '',
      totalUtterances: json['total_utterances'] as int? ?? 0,
      worker: json['worker'] != null
          ? WorkerStatus.fromJson(json['worker'] as Map<String, dynamic>)
          : const WorkerStatus(),
      summary: json['summary'] != null
          ? AssignmentSummary.fromJson(json['summary'] as Map<String, dynamic>)
          : const AssignmentSummary(),
      speakers: (json['speakers'] as List?)
              ?.map((e) => SpeakerInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// 是否已解析完成
  bool get isParseCompleted => worker.parseCompleted;

  /// 角色数量
  int get speakerCount => speakers.length;

  /// 已分配音色的角色数量
  int get assignedSpeakerCount => speakers.where((s) => s.hasVoice).length;
}
