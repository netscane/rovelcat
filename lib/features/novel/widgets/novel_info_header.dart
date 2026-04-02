import 'package:flutter/material.dart';
import '../../../data/models/novel.dart';
import '../../../data/models/novel_brief.dart';
import '../../../data/models/play_history.dart';

/// 小说详情信息头部卡片 - 现代化设计
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 统计数据行 - 3 个独立卡片
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.format_list_numbered_rounded,
                label: '总段落',
                value: '${brief.totalUtterances}',
                color: colorScheme.primary,
                bgColor: colorScheme.primaryContainer,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon: Icons.people_rounded,
                label: '角色',
                value: '${brief.speakerCount}',
                color: colorScheme.tertiary,
                bgColor: colorScheme.tertiaryContainer,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon: Icons.record_voice_over_rounded,
                label: '已配音',
                value: '${brief.assignedSpeakerCount}',
                color: colorScheme.secondary,
                bgColor: colorScheme.secondaryContainer,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 状态信息区
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              // 解析状态
              _InfoRow(
                icon: brief.isParseCompleted
                    ? Icons.check_circle_rounded
                    : Icons.autorenew_rounded,
                iconColor: brief.isParseCompleted
                    ? Colors.green
                    : colorScheme.primary,
                text: brief.isParseCompleted
                    ? '角色解析完成${brief.canAssignVoice ? ' · 可分配音色' : ''}'
                    : _parsePhaseLabel(brief),
                spinning: !brief.isParseCompleted,
              ),

              // 上次播放记录
              if (history != null) ...[
                Divider(
                  height: 20,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                ),
                _InfoRow(
                  icon: Icons.history_rounded,
                  iconColor: colorScheme.onSurfaceVariant,
                  text: '上次听到第 ${history!.utteranceIndex + 1} 段'
                      '${history!.voiceName.isNotEmpty ? ' · ${history!.voiceName}' : ''}',
                ),
              ],

              // 创建日期
              if (novel.formattedDate.isNotEmpty) ...[
                Divider(
                  height: 20,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                ),
                _InfoRow(
                  icon: Icons.calendar_today_rounded,
                  iconColor: colorScheme.onSurfaceVariant,
                  text: '创建于 ${novel.formattedDate}',
                ),
              ],
            ],
          ),
        ),
      ],
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
          return '角色解析中... 已发现 ${brief.worker.totalCharacters} 个角色';
        }
        return '解析中...';
    }
  }
}

/// 统计数据卡片
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color bgColor;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                  height: 1,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

/// 信息行
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;
  final bool spinning;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.text,
    this.spinning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (spinning)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: iconColor,
            ),
          )
        else
          Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.3,
                ),
          ),
        ),
      ],
    );
  }
}
