import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/novel_provider.dart';
import '../../core/providers/voice_provider.dart';
import '../../core/providers/history_provider.dart';
import '../../data/models/novel.dart';
import '../../data/services/api_service.dart';
import '../../data/services/websocket_service.dart';
import 'widgets/novel_grid_view.dart';
import 'widgets/novel_list_view.dart';
import 'widgets/upload_novel_dialog.dart';
import '../player/player_page.dart';

/// 小说页面
class NovelPage extends ConsumerStatefulWidget {
  const NovelPage({super.key});

  @override
  ConsumerState<NovelPage> createState() => _NovelPageState();
}

class _NovelPageState extends ConsumerState<NovelPage> {
  @override
  void initState() {
    super.initState();
    // 监听 WebSocket 事件
    _setupWebSocketListener();
  }

  void _setupWebSocketListener() {
    final wsService = ref.read(webSocketServiceProvider);
    wsService.globalEvents.listen((event) {
      if (!mounted) return;
      
      if (event is NovelReadyEvent) {
        ref.read(novelListProvider.notifier).loadNovels();
      } else if (event is NovelDeletedEvent) {
        ref.read(novelListProvider.notifier).removeNovel(event.novelId);
      } else if (event is NovelDeletingEvent) {
        ref.read(novelListProvider.notifier).setNovelStatus(event.novelId, NovelStatus.deleting);
      }
    });
  }

  Future<void> _onRefresh() async {
    await ref.read(novelListProvider.notifier).refresh();
  }

  void _showUploadDialog() {
    showDialog(
      context: context,
      builder: (context) => const UploadNovelDialog(),
    );
  }

  void _openNovel(Novel novel) {
    if (!novel.canPlay) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('小说尚未准备就绪: ${novel.status.name}')),
      );
      return;
    }

    final voiceState = ref.read(voiceListProvider);
    if (voiceState.voices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先添加音色')),
      );
      return;
    }

    // 检查是否有播放历史
    final history = ref.read(historyProvider.notifier).getLastPosition(novel.id);
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PlayerPage(
          novel: novel,
          startIndex: history?.segmentIndex ?? 0,
        ),
      ),
    );
  }

  Future<void> _deleteNovel(Novel novel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除小说'),
        content: Text('确定要删除《${novel.title}》吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ref.read(novelListProvider.notifier).setNovelStatus(novel.id, NovelStatus.deleting);
      final result = await ref.read(apiServiceProvider).deleteNovel(novel.id);
      if (!mounted) return;
      result.fold(
        (error) {
          // 删除失败，恢复状态
          ref.read(novelListProvider.notifier).setNovelStatus(novel.id, NovelStatus.ready);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $error')),
          );
        },
        (_) {
          // 成功时等待 WebSocket 的 NovelDeletedEvent 来移除小说
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final novelState = ref.watch(novelListProvider);
    final viewMode = ref.watch(novelViewModeProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Rovelcat',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              viewMode == NovelViewMode.grid
                  ? Icons.view_list_rounded
                  : Icons.grid_view_rounded,
            ),
            tooltip: viewMode == NovelViewMode.grid ? '列表视图' : '书架视图',
            onPressed: () {
              ref.read(novelViewModeProvider.notifier).state =
                  viewMode == NovelViewMode.grid
                      ? NovelViewMode.list
                      : NovelViewMode.grid;
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: colorScheme.primary,
        child: _buildContent(novelState, viewMode),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: _showUploadDialog,
        icon: const Icon(Icons.add),
        label: const Text('添加小说'),
      ),
    );
  }

  Widget _buildContent(NovelListState state, NovelViewMode viewMode) {
    if (state.isLoading && state.novels.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (state.error != null && state.novels.isEmpty) {
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
              onPressed: () => ref.read(novelListProvider.notifier).loadNovels(),
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (state.novels.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_books_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              '还没有小说',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击下方按钮添加小说',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
            ),
          ],
        ),
      );
    }

    if (viewMode == NovelViewMode.grid) {
      return NovelGridView(
        novels: state.novels,
        onTap: _openNovel,
        onLongPress: _deleteNovel,
      );
    } else {
      return NovelListView(
        novels: state.novels,
        onTap: _openNovel,
        onLongPress: _deleteNovel,
      );
    }
  }
}
