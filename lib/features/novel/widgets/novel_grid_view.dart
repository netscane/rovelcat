import 'package:flutter/material.dart';
import '../../../data/models/novel.dart' show Novel, NovelStatus;

/// 小说网格视图（书架模式）
class NovelGridView extends StatelessWidget {
  final List<Novel> novels;
  final Function(Novel) onTap;
  final Function(Novel)? onLongPress;

  const NovelGridView({
    super.key,
    required this.novels,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: novels.length,
      itemBuilder: (context, index) {
        return _NovelGridItem(
          novel: novels[index],
          onTap: () => onTap(novels[index]),
          onLongPress: onLongPress != null ? () => onLongPress!(novels[index]) : null,
        );
      },
    );
  }
}

class _NovelGridItem extends StatelessWidget {
  final Novel novel;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _NovelGridItem({
    required this.novel,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isReady = novel.canPlay;

    return Card(
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
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 封面
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
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
                        // 占位图标
                        Icon(
                          Icons.auto_stories,
                          size: 48,
                          color: colorScheme.onPrimaryContainer.withValues(alpha: 0.3),
                        ),
                        // 书名首字
                        if (novel.title.isNotEmpty)
                          Text(
                            novel.title[0],
                            style: TextStyle(
                              fontSize: 56,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onPrimaryContainer.withValues(alpha: 0.6),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // 信息区域
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 标题
                        Text(
                          novel.title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        // 状态/段落数
                        Row(
                          children: [
                            Icon(
                              Icons.library_books_outlined,
                              size: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${novel.totalSegments} 段',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // 状态遮罩
            if (!isReady)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (novel.status == NovelStatus.deleting)
                          const CircularProgressIndicator(strokeWidth: 2)
                        else
                          CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.primary,
                          ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _getStatusText(novel.status),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getStatusText(NovelStatus status) {
    switch (status) {
      case NovelStatus.processing:
        return '处理中...';
      case NovelStatus.deleting:
        return '删除中...';
      case NovelStatus.uploading:
        return '上传中...';
      case NovelStatus.error:
        return '错误';
      default:
        return status.name;
    }
  }
}
