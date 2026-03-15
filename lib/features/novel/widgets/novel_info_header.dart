import 'package:flutter/material.dart';
import '../../../data/models/novel.dart';
import '../../../data/models/novel_brief.dart';
import '../../../data/models/play_history.dart';

/// 小说详情信息头部卡片
class NovelInfoHeader extends StatelessWidget {
  final Novel novel;
  final NovelBrief brief;
  final PlayHistory? history;

  const NovelInfoHeader({
    super.key,
    required this.novel,
    required this.brief,
    this.history,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 统计数据行
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    icon: Icons.format_list_numbered,
                    label: '总段落',
                    value: '${brief.totalUtterances}',
                    color: colorScheme.primary,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.people_outline,
                    label: '角色',
                    value: '${brief.speakerCount}',
                    color: colorScheme.tertiary,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.record_voice_over,
                    label: '已配音',
                    value: '${brief.assignedSpeakerCount}',
                    color: colorScheme.secondary,
                  ),
                ),
              ],
            ),

            // 解析状态
            if (!brief.isParseCompleted) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _parsePhaseLabel(brief),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                        ),
                  ),
                  const Spacer(),
                  if (brief.worker.totalCharacters > 0)
                    Text(
                      '已发现 ${brief.worker.totalCharacters} 个角色',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                ],
              ),
            ] else ...[
              // 解析完成标记
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '角色解析完成',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                        ),
                  ),
                  if (brief.canAssignVoice) ...[
                    const SizedBox(width: 8),
                    Text(
                      '· 可分配音色',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            ],

            // 上次播放记录
            if (history != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.history,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '上次听到第 ${history!.segmentIndex + 1} 段',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  if (history!.voiceName.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Icon(
                      Icons.record_voice_over,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '使用「${history!.voiceName}」',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            ],

            // 创建日期
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  '创建于 ${novel.formattedDate}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _parsePhaseLabel(NovelBrief brief) {
    switch (brief.parsePhase) {
      case 'uploading':
        return '上传中...';
      case 'parsing_text':
        return '正在解析文本...';
      case 'identifying_characters':
        return '正在识别角色...';
      case 'resolving_conflicts':
        return '正在处理角色冲突...';
      case 'assigning_voices':
        return '正在自动分配音色...';
      case 'ready_for_assignment':
        return '角色解析完成';
      default:
        if (brief.worker.newCharacters > 0) {
          return '角色解析中...';
        }
        return '解析中...';
    }
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
