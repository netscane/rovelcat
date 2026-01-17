/// 播放会话数据模型
class PlaySession {
  final String sessionId;
  final String novelId;
  final String voiceId;
  final int currentIndex;

  const PlaySession({
    required this.sessionId,
    required this.novelId,
    required this.voiceId,
    required this.currentIndex,
  });

  factory PlaySession.fromJson(Map<String, dynamic> json) {
    return PlaySession(
      sessionId: json['session_id'] as String,
      novelId: json['novel_id'] as String,
      voiceId: json['voice_id'] as String,
      currentIndex: json['current_index'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'novel_id': novelId,
      'voice_id': voiceId,
      'current_index': currentIndex,
    };
  }

  PlaySession copyWith({
    String? sessionId,
    String? novelId,
    String? voiceId,
    int? currentIndex,
  }) {
    return PlaySession(
      sessionId: sessionId ?? this.sessionId,
      novelId: novelId ?? this.novelId,
      voiceId: voiceId ?? this.voiceId,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }
}
