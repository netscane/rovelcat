import 'package:flutter/material.dart';
import '../../../data/models/segment.dart';
import '../../../data/models/segment_task.dart';

/// 段落列表组件
class SegmentList extends StatefulWidget {
  final List<Segment> segments;
  final int currentIndex;
  final int loadedStart;
  final Map<int, SegmentTask> tasks;
  final bool hasMore;
  final bool loadingMore;
  final ScrollController scrollController;
  final Function(int) onSegmentTap;
  final int? scrollToIndex;
  final VoidCallback? onScrollCompleted;

  const SegmentList({
    super.key,
    required this.segments,
    required this.currentIndex,
    required this.loadedStart,
    required this.tasks,
    required this.hasMore,
    required this.loadingMore,
    required this.scrollController,
    required this.onSegmentTap,
    this.scrollToIndex,
    this.onScrollCompleted,
  });

  @override
  State<SegmentList> createState() => _SegmentListState();
}

class _SegmentListState extends State<SegmentList> {
  final Map<int, GlobalKey> _itemKeys = {};
  int? _lastScrolledToIndex;

  GlobalKey _getKeyForIndex(int segmentIndex) {
    return _itemKeys.putIfAbsent(segmentIndex, () => GlobalKey());
  }

  @override
  void didUpdateWidget(SegmentList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当 scrollToIndex 改变时触发滚动
    if (widget.scrollToIndex != null && 
        widget.scrollToIndex != _lastScrolledToIndex) {
      _lastScrolledToIndex = widget.scrollToIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSegment(widget.scrollToIndex!);
      });
    }
  }

  void _scrollToSegment(int segmentIndex) {
    final key = _itemKeys[segmentIndex];
    if (key?.currentContext == null) return;
    
    Scrollable.ensureVisible(
      key!.currentContext!,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: 0.15, // 将目标项放在视口 15% 的位置（靠近顶部）
    ).then((_) {
      widget.onScrollCompleted?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: widget.segments.length + (widget.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= widget.segments.length) {
          return _buildLoadingIndicator(context);
        }
        
        final segment = widget.segments[index];
        final isPlaying = segment.index == widget.currentIndex;
        final task = widget.tasks[segment.index];
        
        return _SegmentItem(
          key: _getKeyForIndex(segment.index),
          segment: segment,
          isPlaying: isPlaying,
          task: task,
          onTap: () => widget.onSegmentTap(segment.index),
        );
      },
    );
  }

  Widget _buildLoadingIndicator(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: widget.loadingMore
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '加载更多...',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              )
            : Text(
                '上拉加载更多',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
      ),
    );
  }
}

class _SegmentItem extends StatelessWidget {
  final Segment segment;
  final bool isPlaying;
  final SegmentTask? task;
  final VoidCallback onTap;

  const _SegmentItem({
    super.key,
    required this.segment,
    required this.isPlaying,
    this.task,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: isPlaying
            ? colorScheme.primaryContainer.withValues(alpha: 0.5)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: isPlaying
                  ? Border.all(color: colorScheme.primary, width: 2)
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 索引标记
                Container(
                  width: 40,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isPlaying
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: isPlaying
                      ? Icon(
                          Icons.play_arrow,
                          size: 20,
                          color: colorScheme.onPrimary,
                        )
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${segment.index + 1}',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                            maxLines: 1,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                // 文本内容
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        segment.content,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isPlaying
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurface,
                              height: 1.5,
                            ),
                      ),
                      if (task != null) ...[
                        const SizedBox(height: 8),
                        _TaskStatusIndicator(task: task!),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskStatusIndicator extends StatelessWidget {
  final SegmentTask task;

  const _TaskStatusIndicator({required this.task});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color bgColor;
    Color textColor;
    IconData icon;
    String label;

    switch (task.state) {
      case TaskState.pending:
        bgColor = colorScheme.surfaceContainerHighest;
        textColor = colorScheme.onSurfaceVariant;
        icon = Icons.schedule;
        label = '等待中';
        break;
      case TaskState.inferring:
        bgColor = colorScheme.tertiaryContainer;
        textColor = colorScheme.onTertiaryContainer;
        icon = Icons.hourglass_top;
        label = '生成中';
        break;
      case TaskState.ready:
        bgColor = colorScheme.primaryContainer;
        textColor = colorScheme.onPrimaryContainer;
        icon = Icons.check_circle;
        label = '已就绪';
        break;
      case TaskState.failed:
        bgColor = colorScheme.errorContainer;
        textColor = colorScheme.onErrorContainer;
        icon = Icons.error_outline;
        label = task.error ?? '失败';
        break;
      case TaskState.cancelled:
        bgColor = colorScheme.surfaceContainerHighest;
        textColor = colorScheme.onSurfaceVariant;
        icon = Icons.cancel_outlined;
        label = '已取消';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
        child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (task.state == TaskState.inferring)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: textColor,
              ),
            )
          else
            Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: textColor,
                ),
          ),
        ],
      ),
    );
  }
}
