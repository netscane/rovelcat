import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/history_provider.dart';
import '../../../core/providers/novel_provider.dart';
import '../../../data/models/play_history.dart';
import '../../player/player_page.dart';

/// 播放历史对话框
class HistoryListDialog extends ConsumerWidget {
  const HistoryListDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyState = ref.watch(historyProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Text(
                    '播放历史',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),
                  if (historyState.histories.isNotEmpty)
                    TextButton(
                      onPressed: () => _confirmClearHistory(context, ref),
                      child: Text(
                        '清空',
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 列表
            Flexible(
              child: historyState.histories.isEmpty
                  ? _EmptyState()
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: historyState.histories.length,
                      itemBuilder: (context, index) {
                        final history = historyState.histories[index];
                        return _HistoryItem(
                          history: history,
                          onTap: () => _resumePlayback(context, ref, history),
                          onDelete: () => _deleteHistory(ref, history),
                        );
                      },
                    ),
            ),
            // 关闭按钮
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('关闭'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _resumePlayback(BuildContext context, WidgetRef ref, PlayHistory history) {
    // 查找对应的小说
    final novelState = ref.read(novelListProvider);
    final novel = novelState.novels.where((n) => n.id == history.novelId).firstOrNull;

    if (novel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('小说不存在或已删除')),
      );
      return;
    }

    if (!novel.canPlay) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('小说尚未准备就绪')),
      );
      return;
    }

    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PlayerPage(
          novel: novel,
          startIndex: history.segmentIndex,
        ),
      ),
    );
  }

  void _deleteHistory(WidgetRef ref, PlayHistory history) {
    ref.read(historyProvider.notifier).removeHistory(history.novelId);
  }

  void _confirmClearHistory(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空历史'),
        content: const Text('确定要清空所有播放历史吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(historyProvider.notifier).clearHistory();
    }
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无播放历史',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '播放过的小说会在这里显示',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
          ),
        ],
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final PlayHistory history;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryItem({
    required this.history,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = history.totalSegments > 0
        ? history.segmentIndex / history.totalSegments
        : 0.0;

    return Dismissible(
      key: Key(history.novelId),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: colorScheme.errorContainer,
        child: Icon(
          Icons.delete,
          color: colorScheme.onErrorContainer,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        leading: Container(
          width: 48,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primaryContainer,
                colorScheme.secondaryContainer,
              ],
            ),
          ),
          child: Center(
            child: Text(
              history.novelTitle.isNotEmpty ? history.novelTitle[0] : 'N',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
        title: Text(
          history.novelTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.record_voice_over,
                  size: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  history.voiceName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${history.segmentIndex + 1}/${history.totalSegments}段',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // 进度条
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: colorScheme.surfaceContainerHighest,
                color: colorScheme.primary,
                minHeight: 3,
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatDate(history.playedAt),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 4),
            Icon(
              Icons.play_circle_filled,
              color: colorScheme.primary,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays == 1) {
      return '昨天';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${date.month}/${date.day}';
    }
  }
}
