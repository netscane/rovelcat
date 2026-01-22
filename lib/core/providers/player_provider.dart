import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import '../../data/models/novel.dart';
import '../../data/models/voice.dart';
import '../../data/models/segment.dart';
import '../../data/models/play_session.dart';
import '../../data/models/segment_task.dart';
import '../../data/services/api_service.dart';
import '../../data/services/websocket_service.dart';

/// 播放状态枚举
enum PlaybackState { stopped, loading, playing, paused }

/// 播放器状态
class PlayerState {
  final PlaySession? session;
  final Novel? novel;
  final Voice? voice;
  final List<Segment> segments;
  final int currentSegmentIndex;
  final PlaybackState playbackState;
  final bool waitingForAudio;
  final int? scrollToSegment;
  final String? error;

  // 分页相关
  final int totalSegments;
  final int loadedStart;
  final int loadedEnd;
  final bool hasMore;
  final bool loadingMore;

  // 任务管理
  final Map<int, SegmentTask> tasks;

  const PlayerState({
    this.session,
    this.novel,
    this.voice,
    this.segments = const [],
    this.currentSegmentIndex = 0,
    this.playbackState = PlaybackState.stopped,
    this.waitingForAudio = false,
    this.scrollToSegment,
    this.error,
    this.totalSegments = 0,
    this.loadedStart = 0,
    this.loadedEnd = 0,
    this.hasMore = false,
    this.loadingMore = false,
    this.tasks = const {},
  });

  PlayerState copyWith({
    PlaySession? session,
    Novel? novel,
    Voice? voice,
    List<Segment>? segments,
    int? currentSegmentIndex,
    PlaybackState? playbackState,
    bool? waitingForAudio,
    int? scrollToSegment,
    String? error,
    int? totalSegments,
    int? loadedStart,
    int? loadedEnd,
    bool? hasMore,
    bool? loadingMore,
    Map<int, SegmentTask>? tasks,
  }) {
    return PlayerState(
      session: session ?? this.session,
      novel: novel ?? this.novel,
      voice: voice ?? this.voice,
      segments: segments ?? this.segments,
      currentSegmentIndex: currentSegmentIndex ?? this.currentSegmentIndex,
      playbackState: playbackState ?? this.playbackState,
      waitingForAudio: waitingForAudio ?? this.waitingForAudio,
      scrollToSegment: scrollToSegment,
      error: error,
      totalSegments: totalSegments ?? this.totalSegments,
      loadedStart: loadedStart ?? this.loadedStart,
      loadedEnd: loadedEnd ?? this.loadedEnd,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      tasks: tasks ?? this.tasks,
    );
  }

  bool isSegmentReady(int index) {
    return tasks[index]?.state == TaskState.ready;
  }
}

/// 播放器 Notifier
class PlayerNotifier extends StateNotifier<PlayerState> {
  final ApiService _api;
  final WebSocketService _wsService;
  final just_audio.AudioPlayer _audioPlayer = just_audio.AudioPlayer();

  StreamSubscription<WsEvent>? _wsSub;
  StreamSubscription<just_audio.PlayerState>? _playerSub;
  Timer? _prefetchTimer;
  Timer? _cleanupTimer;
  bool _disposed = false;

  static const int _prefetchAhead = 3;
  static const int _pageSize = 30;

  PlayerNotifier(this._api, this._wsService) : super(const PlayerState()) {
    _playerSub = _audioPlayer.playerStateStream.listen(_handlePlayerState);
    _prefetchTimer = Timer.periodic(const Duration(seconds: 1), (_) => _prefetchTasks());
    _cleanupTimer = Timer.periodic(const Duration(seconds: 5), (_) => _cleanupTasks());
  }

  @override
  void dispose() {
    _disposed = true;
    _wsSub?.cancel();
    _playerSub?.cancel();
    _prefetchTimer?.cancel();
    _cleanupTimer?.cancel();
    _audioPlayer.dispose();
    _wsService.disconnectSession();
    super.dispose();
  }

  /// 开始播放
  Future<void> startPlayback(Novel novel, Voice voice, {int startIndex = 0}) async {
    state = state.copyWith(
      novel: novel,
      voice: voice,
      segments: [],
      currentSegmentIndex: startIndex,
      playbackState: PlaybackState.loading,
      waitingForAudio: true,
      totalSegments: novel.totalSegments,
      loadedStart: 0,
      loadedEnd: 0,
      hasMore: true,
      tasks: {},
      error: null,
    );

    final result = await _api.createSession(novel.id, voice.id, startIndex);
    await result.fold(
      (error) async {
        state = state.copyWith(
          playbackState: PlaybackState.stopped,
          error: error,
        );
      },
      (PlaySession session) async {
        state = state.copyWith(
          session: session,
          currentSegmentIndex: session.currentIndex,
        );

        // 连接 WebSocket
        _wsSub?.cancel();
        await _wsService.connectSession(session.sessionId);
        _wsSub = _wsService.sessionEvents.listen(_handleWsEvent);

        // 加载段落
        await _loadSegments(startIndex: (startIndex - 5).clamp(0, startIndex));
      },
    );
  }

  /// 停止播放
  Future<void> stopPlayback() async {
    await _audioPlayer.stop();
    
    if (state.session != null) {
      await _api.closeSession(state.session!.sessionId);
      _wsService.disconnectSession();
      _wsSub?.cancel();
    }

    state = const PlayerState();
  }

  /// 暂停播放
  void pausePlayback() {
    _audioPlayer.pause();
    state = state.copyWith(playbackState: PlaybackState.paused);
  }

  /// 恢复播放
  void resumePlayback() {
    _audioPlayer.play();
    state = state.copyWith(playbackState: PlaybackState.playing);
  }

  /// 跳转到指定段落
  Future<void> seekTo(int index) async {
    if (state.session == null) return;

    await _audioPlayer.stop();
    state = state.copyWith(
      playbackState: PlaybackState.loading,
      waitingForAudio: true,
      tasks: {},
    );

    final result = await _api.seek(state.session!.sessionId, index);
    await result.fold(
      (error) async {
        state = state.copyWith(
          playbackState: PlaybackState.stopped,
          error: error,
        );
      },
      (int newIndex) async {
        // 检查是否需要加载新段落
        if (newIndex < state.loadedStart || newIndex >= state.loadedEnd) {
          await _loadSegments(startIndex: (newIndex - 5).clamp(0, newIndex), replace: true);
        }
        
        // 段落加载完成后再更新索引和设置滚动目标，确保滑块和可见内容同步
        state = state.copyWith(
          currentSegmentIndex: newIndex,
          scrollToSegment: newIndex,
        );

        _submitPrefetchTasks();
      },
    );
  }

  /// 切换音色
  Future<void> changeVoice(Voice voice) async {
    if (state.session == null) return;

    state = state.copyWith(
      voice: voice,
      playbackState: PlaybackState.loading,
      waitingForAudio: true,
      tasks: {},
    );

    final result = await _api.changeVoice(state.session!.sessionId, voice.id);
    result.fold(
      (error) {
        state = state.copyWith(error: error);
      },
      (_) {
        _submitPrefetchTasks();
      },
    );
  }

  /// 加载更多段落
  Future<void> loadMoreSegments() async {
    if (state.loadingMore || !state.hasMore || state.session == null) return;

    state = state.copyWith(loadingMore: true);
    await _loadSegments(startIndex: state.loadedEnd, append: true);
  }

  /// 清除滚动目标
  void clearScrollToSegment() {
    state = state.copyWith(scrollToSegment: null);
  }

  /// 从停止状态开始播放
  void startPlayingFromStopped() {
    if (state.session == null) return;

    if (state.isSegmentReady(state.currentSegmentIndex)) {
      _loadAndPlayAudio(state.currentSegmentIndex);
    } else {
      state = state.copyWith(
        playbackState: PlaybackState.loading,
        waitingForAudio: true,
      );
      _submitPrefetchTasks();
    }
  }

  // ========== 私有方法 ==========

  Future<void> _loadSegments({
    required int startIndex,
    bool replace = false,
    bool append = false,
  }) async {
    if (state.session == null) return;

    final result = await _api.getSegments(
      state.session!.novelId,
      start: startIndex,
      limit: _pageSize,
    );

    result.fold(
      (error) {
        state = state.copyWith(
          loadingMore: false,
          error: error,
        );
      },
      (SegmentsResponse data) {
        final newSegments = data.segments;
        
        List<Segment> segments;
        int loadedStart;
        int loadedEnd;

        if (replace || state.segments.isEmpty) {
          segments = newSegments;
          loadedStart = newSegments.isNotEmpty ? newSegments.first.index : 0;
          loadedEnd = loadedStart + newSegments.length;
        } else if (append) {
          segments = [...state.segments, ...newSegments];
          loadedStart = state.loadedStart;
          loadedEnd = state.loadedStart + segments.length;
        } else {
          segments = newSegments;
          loadedStart = newSegments.isNotEmpty ? newSegments.first.index : 0;
          loadedEnd = loadedStart + newSegments.length;
        }

        // 使用 API 返回的 total，但如果已有正确的 totalSegments 则保留
        final total = state.totalSegments > 0 ? state.totalSegments : data.total;

        state = state.copyWith(
          segments: segments,
          totalSegments: total,
          loadedStart: loadedStart,
          loadedEnd: loadedEnd,
          hasMore: loadedEnd < total,
          loadingMore: false,
        );

        // 初始加载时提交预取任务
        if (!append) {
          _submitPrefetchTasks();
        }
      },
    );
  }

  void _submitPrefetchTasks() {
    if (state.session == null) return;

    final indices = <int>[];
    final end = (state.currentSegmentIndex + _prefetchAhead + 1)
        .clamp(0, state.totalSegments);
    
    for (int i = state.currentSegmentIndex; i < end; i++) {
      if (!state.tasks.containsKey(i)) {
        indices.add(i);
      }
    }

    if (indices.isEmpty) return;

    // 添加 pending 任务
    final tasks = Map<int, SegmentTask>.from(state.tasks);
    final now = DateTime.now();
    for (final idx in indices) {
      tasks[idx] = SegmentTask(
        sessionId: state.session!.sessionId,
        segmentIndex: idx,
        state: TaskState.pending,
        createdAt: now,
      );
    }
    state = state.copyWith(tasks: tasks);

    // 提交任务
    _api.submitInfer(state.session!.sessionId, indices).then((result) {
      result.fold(
        (error) {
          debugPrint('Submit infer error: $error');
        },
        (List<TaskInfo> taskInfos) {
          final tasks = Map<int, SegmentTask>.from(state.tasks);
          for (final info in taskInfos) {
            final task = tasks[info.segmentIndex];
            if (task != null) {
              tasks[info.segmentIndex] = task.copyWith(
                taskId: info.taskId,
                state: TaskState.fromString(info.state),
              );
            }

            // 如果当前段落已经就绪，开始播放
            if (info.segmentIndex == state.currentSegmentIndex &&
                info.state == 'ready' &&
                (state.waitingForAudio || state.playbackState == PlaybackState.loading)) {
              _loadAndPlayAudio(state.currentSegmentIndex);
            }
          }
          state = state.copyWith(tasks: tasks);
        },
      );
    });
  }

  Future<void> _loadAndPlayAudio(int segmentIndex) async {
    if (state.session == null) return;

    final data = await _api.getAudio(
      state.session!.novelId,
      segmentIndex,
      state.voice!.id,
    );

    if (data == null) {
      state = state.copyWith(waitingForAudio: true);
      return;
    }

    await _playAudioData(data);
    state = state.copyWith(
      waitingForAudio: false,
      playbackState: PlaybackState.playing,
    );
  }

  Future<void> _playAudioData(Uint8List data) async {
    final base64Data = base64Encode(data);
    final dataUri = 'data:audio/wav;base64,$base64Data';
    await _audioPlayer.setUrl(dataUri);
    _audioPlayer.play();
  }

  void _handlePlayerState(just_audio.PlayerState playerState) {
    if (playerState.processingState == just_audio.ProcessingState.completed) {
      _onAudioFinished();
    }
  }

   void _onAudioFinished() {
    debugPrint('_onAudioFinished called: playbackState=${state.playbackState}');
    if (state.playbackState != PlaybackState.playing) return;

    if (state.currentSegmentIndex + 1 >= state.totalSegments) {
      state = state.copyWith(playbackState: PlaybackState.stopped);
      return;
    }

     // 移动到下一段
    final nextIndex = state.currentSegmentIndex + 1;
    
    // 只有在没有手动滚动请求时才自动滚动
    if (state.scrollToSegment == null) {
      state = state.copyWith(
        currentSegmentIndex: nextIndex,
        scrollToSegment: nextIndex,
      );
    } else {
      // 如果有手动滚动请求，只更新索引，不覆盖滚动目标
      state = state.copyWith(currentSegmentIndex: nextIndex);
    }

    // 检查是否就绪
    if (state.isSegmentReady(nextIndex)) {
      _loadAndPlayAudio(nextIndex);
    } else {
      state = state.copyWith(
        playbackState: PlaybackState.loading,
        waitingForAudio: true,
      );
    }

    _submitPrefetchTasks();
  }

  void _handleWsEvent(WsEvent event) {
    if (event is TaskStateChangedEvent) {
      if (state.session == null) return;
      if (event.sessionId != state.session!.sessionId) return;

      final tasks = Map<int, SegmentTask>.from(state.tasks);
      final task = tasks[event.segmentIndex];
      if (task != null) {
        tasks[event.segmentIndex] = task.copyWith(
          taskId: event.taskId,
          state: TaskState.fromString(event.state),
          durationMs: event.durationMs,
          error: event.error,
        );
      } else {
        tasks[event.segmentIndex] = SegmentTask(
          sessionId: event.sessionId,
          taskId: event.taskId,
          segmentIndex: event.segmentIndex,
          state: TaskState.fromString(event.state),
          durationMs: event.durationMs,
          error: event.error,
          createdAt: DateTime.now(),
        );
      }
      state = state.copyWith(tasks: tasks);

      // 检查当前段落是否就绪
      if (event.segmentIndex == state.currentSegmentIndex &&
          event.state == 'ready' &&
          (state.waitingForAudio || state.playbackState == PlaybackState.loading)) {
        _loadAndPlayAudio(state.currentSegmentIndex);
      }
    } else if (event is SessionClosedEvent) {
      if (state.session?.sessionId == event.sessionId) {
        state = state.copyWith(
          session: null,
          playbackState: PlaybackState.stopped,
          tasks: {},
          error: 'Session closed: ${event.reason}',
        );
      }
    }
  }

  void _prefetchTasks() {
    if (_disposed) return;
    if (state.playbackState != PlaybackState.playing && 
        state.playbackState != PlaybackState.loading) {
      return;
    }
    if (state.session == null) return;
    _submitPrefetchTasks();
  }

  void _cleanupTasks() {
    if (_disposed) return;
    final now = DateTime.now();
    final tasks = Map<int, SegmentTask>.from(state.tasks);
    tasks.removeWhere((_, task) =>
        task.state == TaskState.pending && 
        now.difference(task.createdAt) > const Duration(seconds: 30));
    if (_disposed) return;
    state = state.copyWith(tasks: tasks);
  }
}

/// 播放器 Provider
final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  return PlayerNotifier(
    ref.watch(apiServiceProvider),
    ref.watch(webSocketServiceProvider),
  );
});
