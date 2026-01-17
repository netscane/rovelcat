import 'package:flutter/material.dart';
import '../../../data/models/novel.dart' show Novel, NovelStatus;

/// 小说列表视图
class NovelListView extends StatelessWidget {
  final List<Novel> novels;
  final Function(Novel) onTap;
  final Function(Novel)? onLongPress;

  const NovelListView({
    super.key,
    required this.novels,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: novels.length,
      itemBuilder: (context, index) {
        return _NovelListItem(
          novel: novels[index],
          onTap: () => onTap(novels[index]),
          onLongPress: onLongPress != null ? () => onLongPress!(novels[index]) : null,
        );
      },
    );
  }
}

class _NovelListItem extends StatelessWidget {
  final Novel novel;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _NovelListItem({
    required this.novel,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isReady = novel.canPlay;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: isReady ? onTap : null,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // 封面缩略图
                Container(
                  width: 64,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.primaryContainer,
                        colorScheme.secondaryContainer,
                      ],
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.auto_stories,
                        size: 24,
                        color: colorScheme.onPrimaryContainer.withValues(alpha: 0.3),
                      ),
                      if (novel.title.isNotEmpty)
                        Text(
                          novel.title[0],
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onPrimaryContainer.withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // 信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        novel.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _InfoChip(
                            icon: Icons.library_books_outlined,
                            label: '${novel.totalSegments} 段',
                            colorScheme: colorScheme,
                          ),
                          const SizedBox(width: 8),
                          _InfoChip(
                            icon: Icons.access_time,
                            label: _formatDate(novel.createdAt),
                            colorScheme: colorScheme,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 状态指示器
                if (!isReady)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _getStatusText(novel.status),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  )
                else
                  Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getStatusText(NovelStatus status) {
    switch (status) {
      case NovelStatus.processing:
        return '处理中';
      case NovelStatus.deleting:
        return '删除中';
      case NovelStatus.uploading:
        return '上传中';
      case NovelStatus.error:
        return '错误';
      default:
        return status.name;
    }
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) {
      return '今天';
    } else if (diff.inDays == 1) {
      return '昨天';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${date.month}/${date.day}';
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme colorScheme;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
