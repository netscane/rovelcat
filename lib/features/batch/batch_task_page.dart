import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/batch_task_provider.dart';
import '../../core/providers/novel_provider.dart';
import '../../core/providers/voice_provider.dart';
import '../../data/models/batch_task.dart';
import '../home/home_page.dart';

/// 批量任务管理页面
class BatchTaskPage extends ConsumerStatefulWidget {
  const BatchTaskPage({super.key});

  @override
  ConsumerState<BatchTaskPage> createState() => _BatchTaskPageState();
}

class _BatchTaskPageState extends ConsumerState<BatchTaskPage> {
  static const int _batchTabIndex = 2; // 任务 tab 的索引
  bool _isPolling = false;

  @override
  void initState() {
    super.initState();
    debugPrint('BatchTaskPage.initState()');
    // 首次构建后开始轮询
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updatePolling();
    });
  }

  @override
  void dispose() {
    debugPrint('BatchTaskPage.dispose()');
    // 页面完全销毁时停止轮询
    ref.read(batchTaskListProvider.notifier).stopPolling();
    super.dispose();
  }

  /// 根据当前是否可见更新轮询状态
  void _updatePolling() {
    final currentIndex = ref.read(homeNavIndexProvider);
    final shouldBePolling = currentIndex == _batchTabIndex;

    debugPrint('BatchTaskPage._updatePolling() - currentIndex=$currentIndex, shouldBePolling=$shouldBePolling, _isPolling=$_isPolling');

    if (shouldBePolling && !_isPolling) {
      debugPrint('BatchTaskPage - starting polling');
      ref.read(batchTaskListProvider.notifier).startPolling();
      _isPolling = true;
    } else if (!shouldBePolling && _isPolling) {
      debugPrint('BatchTaskPage - stopping polling');
      ref.read(batchTaskListProvider.notifier).stopPolling();
      _isPolling = false;
    }
  }

  Future<void> _onRefresh() async {
    await ref.read(batchTaskListProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(batchTaskListProvider);
    final navIndex = ref.watch(homeNavIndexProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // 监听导航索引变化，控制轮询
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updatePolling();
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '批量任务',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: colorScheme.primary,
        child: _buildContent(state),
      ),
    );
  }

  Widget _buildContent(BatchTaskListState state) {
    if (state.isLoading && state.tasks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              '加载失败',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              state.error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => ref.read(batchTaskListProvider.notifier).loadTasks(),
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (state.tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.flash_off,
              size: 80,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              '暂无批量任务',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '长按小说可以创建批量预热任务',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: state.tasks.length,
      itemBuilder: (context, index) {
        return _BatchTaskItem(task: state.tasks[index]);
      },
    );
  }
}

class _BatchTaskItem extends ConsumerWidget {
  final BatchTask task;

  const _BatchTaskItem({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final novelState = ref.watch(novelListProvider);
    final voiceState = ref.watch(voiceListProvider);

    // 查找小说和音色名称
    final novel = novelState.novels.where((n) => n.id == task.novelId).firstOrNull;
    final voice = voiceState.voices.where((v) => v.id == task.voiceId).firstOrNull;

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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          novel?.title ?? '未知小说',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '音色: ${voice?.name ?? '未知'}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  _StatusChip(status: task.status),
                ],
              ),
              const SizedBox(height: 16),

              // 进度条
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '第 ${task.segmentStart + 1} - ${task.segmentEnd + 1} 段',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                      Text(
                        '${task.progressPercent.toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: task.progressPercent / 100,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '已处理 ${task.currentIndex - task.segmentStart} / ${task.totalSegments} 段',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),

              // 错误信息
              if (task.errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 16,
                        color: colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          task.errorMessage!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.error,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 操作按钮
              if (!task.isFinished || task.canRetry || task.canCancel) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (task.canPause)
                      TextButton.icon(
                        onPressed: () => _pauseTask(ref, task.taskId, context),
                        icon: const Icon(Icons.pause, size: 18),
                        label: const Text('暂停'),
                      ),
                    if (task.canResume)
                      TextButton.icon(
                        onPressed: () => _resumeTask(ref, task.taskId, context),
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('恢复'),
                      ),
                    if (task.canRetry)
                      TextButton.icon(
                        onPressed: () => _retryTask(ref, task.taskId, context),
                        icon: Icon(Icons.refresh, size: 18, color: colorScheme.primary),
                        label: Text('重试', style: TextStyle(color: colorScheme.primary)),
                      ),
                    if (task.canCancel)
                      TextButton.icon(
                        onPressed: () => _cancelTask(ref, task.taskId, context),
                        icon: Icon(Icons.close, size: 18, color: colorScheme.error),
                        label: Text('取消', style: TextStyle(color: colorScheme.error)),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pauseTask(WidgetRef ref, String taskId, BuildContext context) async {
    final error = await ref.read(batchTaskListProvider.notifier).pauseTask(taskId);
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('暂停失败: $error')),
      );
    }
  }

  Future<void> _resumeTask(WidgetRef ref, String taskId, BuildContext context) async {
    final error = await ref.read(batchTaskListProvider.notifier).resumeTask(taskId);
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('恢复失败: $error')),
      );
    }
  }

  Future<void> _cancelTask(WidgetRef ref, String taskId, BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取消任务'),
        content: const Text('确定要取消此批量任务吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('返回'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('取消任务'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final error = await ref.read(batchTaskListProvider.notifier).cancelTask(taskId);
      if (error != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('取消失败: $error')),
        );
      }
    }
  }

  Future<void> _retryTask(WidgetRef ref, String taskId, BuildContext context) async {
    final error = await ref.read(batchTaskListProvider.notifier).retryTask(taskId);
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('重试失败: $error')),
      );
    }
  }
}

class _StatusChip extends StatelessWidget {
  final BatchTaskStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (status) {
      case BatchTaskStatus.running:
        backgroundColor = colorScheme.primaryContainer;
        textColor = colorScheme.onPrimaryContainer;
        icon = Icons.play_circle_outline;
        break;
      case BatchTaskStatus.paused:
        backgroundColor = colorScheme.secondaryContainer;
        textColor = colorScheme.onSecondaryContainer;
        icon = Icons.pause_circle_outline;
        break;
      case BatchTaskStatus.completed:
        backgroundColor = Colors.green.withValues(alpha: 0.15);
        textColor = Colors.green.shade700;
        icon = Icons.check_circle_outline;
        break;
      case BatchTaskStatus.cancelled:
        backgroundColor = colorScheme.surfaceContainerHighest;
        textColor = colorScheme.onSurfaceVariant;
        icon = Icons.cancel_outlined;
        break;
      case BatchTaskStatus.failed:
        backgroundColor = colorScheme.errorContainer;
        textColor = colorScheme.onErrorContainer;
        icon = Icons.error_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            status.displayName,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}
