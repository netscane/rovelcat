/// 段落数据模型
class Segment {
  final int index;
  final String content;
  final int charCount;

  const Segment({
    required this.index,
    required this.content,
    this.charCount = 0,
  });

  factory Segment.fromJson(Map<String, dynamic> json) {
    return Segment(
      index: json['index'] as int,
      content: json['content'] as String,
      charCount: json['char_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'content': content,
      'char_count': charCount,
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
    final segmentsList = (json['segments'] as List?)
        ?.map((e) => Segment.fromJson(e as Map<String, dynamic>))
        .toList() ?? [];
    return SegmentsResponse(
      segments: segmentsList,
      total: json['total'] as int? ?? segmentsList.length,
    );
  }
}
