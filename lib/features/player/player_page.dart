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
import 'controllers/scroll_controller_delegate.dart';

/// 播放页面
class PlayerPage extends ConsumerStatefulWidget {
  final Novel novel;
  final int startIndex;

  const PlayerPage({super.key, required this.novel, this.startIndex = 0});

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage>
    with WidgetsBindingObserver {
  late final ScrollControllerDelegate _scrollDelegate;
  bool _hasInitializedListener = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 创建滚动控制器委托
    _scrollDelegate = ScrollControllerDelegate(
      ref: ref,
      scrollController: ScrollController(),
      onLoadMore: () {
        if (mounted) {
          ref.read(playerProvider.notifier).loadMoreSegments();
        }
      },
    );

    // 初始播放
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startPlayback();
    });
  }

  void _handlePlayerStateChange(PlayerState? previous, PlayerState current) {
    if (!mounted || _scrollDelegate.isNavigatingAway) return;

    try {
      // 当 currentSegmentIndex 变化时，自动滚动到该段落
      if (previous != null &&
          previous.currentSegmentIndex != current.currentSegmentIndex) {
        _scrollDelegate.scrollToSegmentWhenReady(current.currentSegmentIndex);
      }

      // 段落加载完成后检查是否需要继续加载更多
      final segmentsChanged = previous?.segments.length != current.segments.length;
      if (segmentsChanged && current.hasMore && !current.loadingMore) {
        _scrollDelegate.checkAutoLoadMore();
      }

      // 新增：段落数据首次加载完成后，滚动到当前播放段落
      final wasEmpty = previous == null ? true : previous.segments.isEmpty;
      final isNowLoaded = current.segments.isNotEmpty;
      final isPlaying = current.playbackState == PlaybackState.playing;

      if (wasEmpty && isNowLoaded && isPlaying) {
        debugPrint(
          'Initial segments loaded, scrolling to current segment: ${current.currentSegmentIndex}',
        );
        _scrollDelegate.scrollToSegmentWhenReady(current.currentSegmentIndex);
      }
    } catch (e) {
      // 忽略 dispose 后的错误
      if (!e.toString().contains('disposed')) {
        debugPrint('Error in playerProvider listener: $e');
      }
    }
  }

  @override
  void dispose() {
    _scrollDelegate.isNavigatingAway = true;

    // 保存进度前检查 mounted
    if (mounted) {
      _saveProgress();
    }

    WidgetsBinding.instance.removeObserver(this);
    _scrollDelegate.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _saveProgress();
    }
  }

  void _startPlayback() {
    if (_scrollDelegate.isNavigatingAway || !mounted) return;
    final voiceState = ref.read(voiceListProvider);
    final voice = voiceState.defaultVoice;

    if (voice == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先添加音色')));
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    ref
        .read(playerProvider.notifier)
        .startPlayback(widget.novel, voice, startIndex: widget.startIndex);
  }

  void _saveProgress() {
    if (!mounted) return;

    try {
      final playerState = ref.read(playerProvider);
      if (playerState.novel != null && playerState.voice != null) {
        ref
            .read(historyProvider.notifier)
            .savePlayProgress(
              novelId: playerState.novel!.id,
              novelTitle: playerState.novel!.title,
              segmentIndex: playerState.currentSegmentIndex,
              voiceId: playerState.voice!.id,
              voiceName: playerState.voice!.name,
              totalSegments: playerState.totalSegments,
            );
      }
    } catch (e) {
      // 忽略 dispose 后的错误
      if (!e.toString().contains('disposed')) {
        debugPrint('Error saving progress: $e');
      }
    }
  }

  Future<void> _exit() async {
    _scrollDelegate.isNavigatingAway = true;
    _saveProgress();
    await ref.read(playerProvider.notifier).stopPlayback();

    // autoDispose 会自动处理 provider 生命周期
    // 当页面完全退出后，provider 会自动 dispose

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _showVoiceSelector() {
    if (_scrollDelegate.isNavigatingAway || !mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => VoiceSelectorSheet(onSelect: _changeVoice),
    );
  }

  void _changeVoice(Voice voice) {
    if (_scrollDelegate.isNavigatingAway || !mounted) return;
    ref.read(playerProvider.notifier).changeVoice(voice);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 如果正在导航离开，跳过构建
    if (_scrollDelegate.isNavigatingAway) {
      return const SizedBox.shrink();
    }

    // 注册监听器（仅一次）
    if (!_hasInitializedListener) {
      _hasInitializedListener = true;
      ref.listen<PlayerState>(playerProvider, _handlePlayerStateChange);
    }

    final playerState = ref.watch(playerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _exit,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              widget.novel.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
          Expanded(child: _buildSegmentList(playerState)),
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
    );
  }

  Widget _buildSegmentList(PlayerState state) {
    if (state.playbackState == PlaybackState.loading &&
        state.segments.isEmpty) {
      return const Center(child: CircularProgressIndicator());
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
            Text('加载失败', style: Theme.of(context).textTheme.titleMedium),
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
      scrollController: _scrollDelegate.scrollController,
      onSegmentTap: _onSegmentTap,
      scrollToIndex: _scrollDelegate.scrollToIndex,
      onScrollCompleted: () {
        if (!mounted) return;
        setState(() {
          _scrollDelegate.clearScrollToIndex();
        });
      },
    );
  }

  void _onPlayPause() {
    if (_scrollDelegate.isNavigatingAway || !mounted) return;
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
    if (_scrollDelegate.isNavigatingAway || !mounted) return;
    final state = ref.read(playerProvider);
    if (state.currentSegmentIndex > 0) {
      ref.read(playerProvider.notifier).seekTo(state.currentSegmentIndex - 1);
    }
  }

  void _onNext() {
    if (_scrollDelegate.isNavigatingAway || !mounted) return;
    final state = ref.read(playerProvider);
    if (state.currentSegmentIndex < state.totalSegments - 1) {
      ref.read(playerProvider.notifier).seekTo(state.currentSegmentIndex + 1);
    }
  }

  void _onSeek(int index) {
    if (_scrollDelegate.isNavigatingAway || !mounted) return;
    ref.read(playerProvider.notifier).seekTo(index);
  }

  void _onSegmentTap(int index) {
    if (_scrollDelegate.isNavigatingAway || !mounted) return;
    ref.read(playerProvider.notifier).seekTo(index);
  }
}
