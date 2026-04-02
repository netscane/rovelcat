class Utterance {
  final int index;
  final String content;
  final int charCount;
  final String? speaker;
  final String? voiceId;

  const Utterance({
    required this.index,
    required this.content,
    this.charCount = 0,
    this.speaker,
    this.voiceId,
  });

  factory Utterance.fromJson(Map<String, dynamic> json) {
    return Utterance(
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

class UtterancesResponse {
  final List<Utterance> utterances;
  final int total;

  const UtterancesResponse({
    required this.utterances,
    required this.total,
  });

  factory UtterancesResponse.fromJson(Map<String, dynamic> json) {
    final rawList = json['utterances'] as List? ?? json['segments'] as List? ?? [];
    final utterancesList = rawList
        .map((e) => Utterance.fromJson(e as Map<String, dynamic>))
        .toList();
    return UtterancesResponse(
      utterances: utterancesList,
      total: json['total'] as int? ?? utterancesList.length,
    );
  }
}
