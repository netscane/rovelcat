import 'package:flutter/material.dart';
import '../../../data/models/novel_brief.dart';

/// 角色（Speaker）列表组件 - 现代化设计
class SpeakerListWidget extends StatelessWidget {
  final List<SpeakerInfo> speakers;
  final Function(SpeakerInfo) onAssignVoice;
  final bool enabled;

  const SpeakerListWidget({
    super.key,
    required this.speakers,
    required this.onAssignVoice,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final sortedSpeakers = List<SpeakerInfo>.from(speakers)
      ..sort((a, b) => b.utteranceCount.compareTo(a.utteranceCount));

    return Column(
      children: sortedSpeakers.map((speaker) {
        return _SpeakerTile(
          speaker: speaker,
          onAssignVoice: () => onAssignVoice(speaker),
          enabled: enabled,
          maxCount: sortedSpeakers.first.utteranceCount,
        );
      }).toList(),
    );
  }
}

class _SpeakerTile extends StatelessWidget {
  final SpeakerInfo speaker;
  final VoidCallback onAssignVoice;
  final bool enabled;
  final int maxCount;

  const _SpeakerTile({
    required this.speaker,
    required this.onAssignVoice,
    required this.enabled,
    required this.maxCount,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasVoice = speaker.hasVoice;
    final ratio = maxCount > 0 ? speaker.utteranceCount / maxCount : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: enabled ? onAssignVoice : null,
          borderRadius: BorderRadius.circular(14),
          child: Opacity(
            opacity: enabled ? 1.0 : 0.55,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: hasVoice
                    ? colorScheme.primaryContainer.withValues(alpha: 0.15)
                    : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                border: Border.all(
                  color: hasVoice
                      ? colorScheme.primary.withValues(alpha: 0.2)
                      : colorScheme.outlineVariant.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  // 角色头像 - 带渐变背景
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: hasVoice
                          ? LinearGradient(
                              colors: [
                                colorScheme.primary.withValues(alpha: 0.8),
                                colorScheme.tertiary.withValues(alpha: 0.6),
                              ],
                            )
                          : null,
                      color: hasVoice ? null : colorScheme.surfaceContainerHighest,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      speaker.name.isNotEmpty ? speaker.name[0] : '?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: hasVoice
                            ? Colors.white
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
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                        const SizedBox(height: 6),
                        // 台词量条 + 音色信息
                        Row(
                          children: [
                            // 小型进度条表示台词占比
                            SizedBox(
                              width: 48,
                              height: 4,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: ratio,
                                  backgroundColor: colorScheme.outlineVariant.withValues(alpha: 0.2),
                                  color: hasVoice ? colorScheme.primary : colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${speaker.utteranceCount} 句',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            if (hasVoice) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.mic_rounded,
                                size: 11,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  speaker.voiceName ?? '已分配',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.w600,
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

                  const SizedBox(width: 4),
                  // 操作图标
                  if (enabled)
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: hasVoice
                            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                            : colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        hasVoice ? Icons.swap_horiz_rounded : Icons.add_rounded,
                        size: 16,
                        color: hasVoice
                            ? colorScheme.onSurfaceVariant
                            : colorScheme.primary,
                      ),
                    )
                  else
                    Icon(
                      Icons.lock_rounded,
                      size: 16,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                ],
              ),
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
    Color textColor;
    String label;
    switch (importance) {
      case 'main':
        bgColor = colorScheme.primaryContainer;
        textColor = colorScheme.onPrimaryContainer;
        label = '主角';
      case 'supporting':
        bgColor = colorScheme.secondaryContainer;
        textColor = colorScheme.onSecondaryContainer;
        label = '配角';
      case 'minor':
        bgColor = colorScheme.surfaceContainerHighest;
        textColor = colorScheme.onSurfaceVariant;
        label = '次要';
      default:
        bgColor = colorScheme.surfaceContainerHighest;
        textColor = colorScheme.onSurfaceVariant;
        label = importance;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
      ),
    );
  }
}
