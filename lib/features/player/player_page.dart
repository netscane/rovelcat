import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/player_provider.dart';
import '../../core/providers/voice_provider.dart';
import '../../core/providers/history_provider.dart';
import '../../data/models/novel.dart';
import '../../data/models/voice.dart';
import 'widgets/segment_list.dart';
import 'widgets/player_controls.dart';
import 'widgets/voice_selector_sheet.dart';

/// 播放页面
class PlayerPage extends ConsumerStatefulWidget {
  final Novel novel;
  final int startIndex;

  const PlayerPage({
    super.key,
    required this.novel,
    this.startIndex = 0,
  });

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    
    // 监听播放器状态，初始加载完成后滚动到当前播放段落
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startPlayback();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _saveProgress();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _saveProgress();
    }
  }

  void _startPlayback() {
    final voiceState = ref.read(voiceListProvider);
    final voice = voiceState.defaultVoice;
    
    if (voice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先添加音色')),
      );
      Navigator.of(context).pop();
      return;
    }

    ref.read(playerProvider.notifier).startPlayback(
      widget.novel,
      voice,
      startIndex: widget.startIndex,
    );
  }

  void _saveProgress() {
    final playerState = ref.read(playerProvider);
    if (playerState.novel != null && playerState.voice != null) {
      ref.read(historyProvider.notifier).savePlayProgress(
        novelId: playerState.novel!.id,
        novelTitle: playerState.novel!.title,
        segmentIndex: playerState.currentSegmentIndex,
        voiceId: playerState.voice!.id,
        voiceName: playerState.voice!.name,
        totalSegments: playerState.totalSegments,
      );
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // 当滚动到距离底部 200 像素内时，或者内容不足以滚动时，加载更多
    if (position.pixels >= position.maxScrollExtent - 200) {
      ref.read(playerProvider.notifier).loadMoreSegments();
    }
  }

  void _checkAutoLoadMore() {
    // 当内容不足以滚动时自动加载更多
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (position.maxScrollExtent <= 0) {
        ref.read(playerProvider.notifier).loadMoreSegments();
      }
    });
  }

  void _showVoiceSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => VoiceSelectorSheet(
        onSelect: _changeVoice,
      ),
    );
  }

  void _changeVoice(Voice voice) {
    ref.read(playerProvider.notifier).changeVoice(voice);
    Navigator.of(context).pop();
  }

  Future<void> _stopAndExit() async {
    _saveProgress();
    await ref.read(playerProvider.notifier).stopPlayback();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // 监听播放器状态变化，初始加载完成后自动滚动到当前播放段落
    ref.listen<PlayerState>(playerProvider, (previous, current) {
      // 处理滚动到指定段落
      if (current.scrollToSegment != null) {
        _scrollToSegmentWhenReady(current.scrollToSegment!);
        ref.read(playerProvider.notifier).clearScrollToSegment();
      }
      
      // 段落加载完成后检查是否需要继续加载更多
      final segmentsChanged = previous?.segments.length != current.segments.length;
      if (segmentsChanged && current.hasMore && !current.loadingMore) {
        _checkAutoLoadMore();
      }
      
      // 新增：段落数据首次加载完成后，滚动到当前播放段落
      final wasEmpty = previous == null ? true : (previous?.segments.isEmpty ?? false);
      final isNowLoaded = current.segments.isNotEmpty;
      final isPlaying = current.playbackState == PlaybackState.playing;
      
      if (wasEmpty && isNowLoaded && isPlaying) {
        debugPrint('Initial segments loaded, scrolling to current segment: ${current.currentSegmentIndex}');
        _scrollToSegmentWhenReady(current.currentSegmentIndex);
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _stopAndExit();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _stopAndExit,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                widget.novel.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (playerState.voice != null)
                Text(
                  playerState.voice!.name,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.record_voice_over),
              tooltip: '切换音色',
              onPressed: _showVoiceSelector,
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            // 段落列表
            Expanded(
              child: _buildSegmentList(playerState),
            ),
            // 播放控制栏
            PlayerControls(
              state: playerState,
              onPlayPause: _onPlayPause,
              onPrevious: _onPrevious,
              onNext: _onNext,
              onSeek: _onSeek,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentList(PlayerState state) {
    if (state.playbackState == PlaybackState.loading && state.segments.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (state.error != null && state.segments.isEmpty) {
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
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SegmentList(
      segments: state.segments,
      currentIndex: state.currentSegmentIndex,
      loadedStart: state.loadedStart,
      tasks: state.tasks,
      hasMore: state.hasMore,
      loadingMore: state.loadingMore,
      scrollController: _scrollController,
      onSegmentTap: _onSegmentTap,
    );
  }

  void _scrollToSegmentWhenReady(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollToSegment(index);
    });
  }

  void _scrollToSegment(int index) {
    final state = ref.read(playerProvider);
    final relativeIndex = index - state.loadedStart;
    if (relativeIndex < 0 || relativeIndex >= state.segments.length) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      
      final scrollPosition = _scrollController.position;
      final maxScroll = scrollPosition.maxScrollExtent;
      final viewportHeight = scrollPosition.viewportDimension;
      
      // 估算位置（每个段落约 130 像素，包括 padding）
      final estimatedOffset = relativeIndex * 130.0;
      
      // 将段落放在屏幕可视区域的上半部分（约 30% 的视口高度），确保播放的句子保持可见
      final extraOffset = viewportHeight * 0.3;
      final targetOffset = (estimatedOffset - extraOffset).clamp(0.0, maxScroll);
      
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  void _onPlayPause() {
    final state = ref.read(playerProvider);
    if (state.playbackState == PlaybackState.playing) {
      ref.read(playerProvider.notifier).pausePlayback();
    } else if (state.playbackState == PlaybackState.paused) {
      ref.read(playerProvider.notifier).resumePlayback();
    } else if (state.playbackState == PlaybackState.stopped) {
      ref.read(playerProvider.notifier).startPlayingFromStopped();
    }
  }

  void _onPrevious() {
    final state = ref.read(playerProvider);
    if (state.currentSegmentIndex > 0) {
      ref.read(playerProvider.notifier).seekTo(state.currentSegmentIndex - 1);
    }
  }

  void _onNext() {
    final state = ref.read(playerProvider);
    if (state.currentSegmentIndex < state.totalSegments - 1) {
      ref.read(playerProvider.notifier).seekTo(state.currentSegmentIndex + 1);
    }
  }

  void _onSeek(int index) {
    ref.read(playerProvider.notifier).seekTo(index);
  }

  void _onSegmentTap(int index) {
    ref.read(playerProvider.notifier).seekTo(index);
  }
}
