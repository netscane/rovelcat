/// 段落数据模型
class Segment {
  final int index;
  final String content;
  final int charCount;
  final String? speaker;
  final String? voiceId;

  const Segment({
    required this.index,
    required this.content,
    this.charCount = 0,
    this.speaker,
    this.voiceId,
  });

  factory Segment.fromJson(Map<String, dynamic> json) {
    return Segment(
      index: json['index'] as int,
      content: json['content'] as String? ?? json['text'] as String? ?? '',
      charCount: json['char_count'] as int? ?? 0,
      speaker: json['speaker'] as String?,
      voiceId: json['voice_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'content': content,
      'char_count': charCount,
      if (speaker != null) 'speaker': speaker,
      if (voiceId != null) 'voice_id': voiceId,
    };
  }
}

/// 段落列表响应
class SegmentsResponse {
  final List<Segment> segments;
  final int total;

  const SegmentsResponse({
    required this.segments,
    required this.total,
  });

  factory SegmentsResponse.fromJson(Map<String, dynamic> json) {
    // 支持新字段名 'utterances' 和旧字段名 'segments'
    final rawList = json['utterances'] as List? ?? json['segments'] as List? ?? [];
    final segmentsList = rawList
        .map((e) => Segment.fromJson(e as Map<String, dynamic>))
        .toList();
    return SegmentsResponse(
      segments: segmentsList,
      total: json['total'] as int? ?? segmentsList.length,
    );
  }
}
