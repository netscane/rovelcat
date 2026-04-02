/// 播放历史数据模型
class PlayHistory {
  final String novelId;
  final String novelTitle;
  final String? coverUrl;
  final int utteranceIndex;
  final String voiceId;
  final String voiceName;
  final int totalUtterances;
  final DateTime playedAt;

  const PlayHistory({
    required this.novelId,
    required this.novelTitle,
    this.coverUrl,
    required this.utteranceIndex,
    required this.voiceId,
    required this.voiceName,
    required this.totalUtterances,
    required this.playedAt,
  });

  factory PlayHistory.fromJson(Map<String, dynamic> json) {
    return PlayHistory(
      novelId: json['novel_id'] as String,
      novelTitle: json['novel_title'] as String,
      coverUrl: json['cover_url'] as String?,
      utteranceIndex: json['utterance_index'] as int? ?? json['segment_index'] as int,
      voiceId: json['voice_id'] as String,
      voiceName: json['voice_name'] as String,
      totalUtterances: json['total_utterances'] as int? ?? json['total_segments'] as int,
      playedAt: DateTime.parse(json['played_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'novel_id': novelId,
      'novel_title': novelTitle,
      'cover_url': coverUrl,
      'utterance_index': utteranceIndex,
      'voice_id': voiceId,
      'voice_name': voiceName,
      'total_utterances': totalUtterances,
      'played_at': playedAt.toIso8601String(),
    };
  }

  /// 播放进度百分比
  double get progress => totalUtterances > 0 ? utteranceIndex / totalUtterances : 0;

  /// 格式化播放时间
  String get formattedPlayedAt {
    final now = DateTime.now();
    final diff = now.difference(playedAt);

    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${playedAt.month}月${playedAt.day}日';
    }
  }

  /// 格式化进度文本
  String get progressText => '${utteranceIndex + 1}/$totalUtterances';
}
