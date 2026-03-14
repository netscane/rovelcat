import 'package:flutter/material.dart';
import '../../../data/models/novel_brief.dart';

/// 角色（Speaker）列表组件
class SpeakerListWidget extends StatelessWidget {
  final List<SpeakerInfo> speakers;
  final Function(SpeakerInfo) onAssignVoice;

  const SpeakerListWidget({
    super.key,
    required this.speakers,
    required this.onAssignVoice,
  });

  @override
  Widget build(BuildContext context) {
    // 按台词数量排序（从多到少）
    final sortedSpeakers = List<SpeakerInfo>.from(speakers)
      ..sort((a, b) => b.utteranceCount.compareTo(a.utteranceCount));

    return Column(
      children: sortedSpeakers.map((speaker) {
        return _SpeakerTile(
          speaker: speaker,
          onAssignVoice: () => onAssignVoice(speaker),
        );
      }).toList(),
    );
  }
}

class _SpeakerTile extends StatelessWidget {
  final SpeakerInfo speaker;
  final VoidCallback onAssignVoice;

  const _SpeakerTile({
    required this.speaker,
    required this.onAssignVoice,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasVoice = speaker.hasVoice;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: hasVoice
                ? colorScheme.primary.withValues(alpha: 0.2)
                : colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: onAssignVoice,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // 角色头像
                CircleAvatar(
                  radius: 20,
                  backgroundColor: hasVoice
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  child: Text(
                    speaker.name.isNotEmpty ? speaker.name[0] : '?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: hasVoice
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // 角色信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              speaker.name,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (speaker.importance != null) ...[
                            const SizedBox(width: 6),
                            _ImportanceBadge(importance: speaker.importance!),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // 台词数量
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${speaker.utteranceCount} 句台词',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                          // 音色信息
                          if (hasVoice) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.record_voice_over,
                              size: 12,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                speaker.voiceName ?? '已分配',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // 操作按钮
                Icon(
                  hasVoice ? Icons.edit_outlined : Icons.add_circle_outline,
                  size: 20,
                  color: hasVoice
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 角色重要性标签
class _ImportanceBadge extends StatelessWidget {
  final String importance;

  const _ImportanceBadge({required this.importance});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color bgColor;
    String label;
    switch (importance) {
      case 'main':
        bgColor = colorScheme.primaryContainer;
        label = '主角';
      case 'supporting':
        bgColor = colorScheme.secondaryContainer;
        label = '配角';
      case 'minor':
        bgColor = colorScheme.surfaceContainerHighest;
        label = '次要';
      default:
        bgColor = colorScheme.surfaceContainerHighest;
        label = importance;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }
}
