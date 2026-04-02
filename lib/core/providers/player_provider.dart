import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import '../../data/models/novel.dart';
import '../../data/models/voice.dart';
import '../../data/models/utterance.dart';
import '../../data/models/play_session.dart';
import '../../data/models/utterance_task.dart';
import '../../data/services/api_service.dart';
import '../../data/services/websocket_service.dart';
import 'settings_provider.dart';

/// 播放状态枚举
enum PlaybackState { stopped, loading, playing, paused }

/// 播放器状态
class PlayerState {
  final PlaySession? session;
  final Novel? novel;
  final Voice? voice;
  final List<Utterance> utterances;
  final int currentUtteranceIndex;
  final PlaybackState playbackState;
  final bool waitingForAudio;
  final String? error;

  // 分页相关
  final int totalUtterances;
  final int loadedStart;
  final int loadedEnd;
  final bool hasMore;
  final bool loadingMore;

  // 任务管理
  final Map<int, UtteranceTask> tasks;

  // Session 版本，用于防止旧 WS 事件污染新状态
  final int version;

  const PlayerState({
    this.session,
    this.novel,
    this.voice,
    this.utterances = const [],
    this.currentUtteranceIndex = 0,
    this.playbackState = PlaybackState.stopped,
    this.waitingForAudio = false,
    this.error,
    this.totalUtterances = 0,
    this.loadedStart = 0,
    this.loadedEnd = 0,
    this.hasMore = false,
    this.loadingMore = false,
    this.tasks = const {},
    this.version = 0,
  });

  PlayerState copyWith({
    PlaySession? session,
    Novel? novel,
    Voice? voice,
    List<Utterance>? utterances,
    int? currentUtteranceIndex,
    PlaybackState? playbackState,
    bool? waitingForAudio,
    String? error,
    int? totalUtterances,
    int? loadedStart,
    int? loadedEnd,
    bool? hasMore,
    bool? loadingMore,
    Map<int, UtteranceTask>? tasks,
    int? version,
  }) {
    return PlayerState(
      session: session ?? this.session,
      novel: novel ?? this.novel,
      voice: voice ?? this.voice,
      utterances: utterances ?? this.utterances,
      currentUtteranceIndex: currentUtteranceIndex ?? this.currentUtteranceIndex,
      playbackState: playbackState ?? this.playbackState,
      waitingForAudio: waitingForAudio ?? this.waitingForAudio,
      error: error,
      totalUtterances: totalUtterances ?? this.totalUtterances,
      loadedStart: loadedStart ?? this.loadedStart,
      loadedEnd: loadedEnd ?? this.loadedEnd,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      tasks: tasks ?? this.tasks,
      version: version ?? this.version,
    );
  }

  bool isUtteranceReady(int index) {
    return tasks[index]?.state == TaskState.ready;
  }
}

/// 播放器 Notifier
class PlayerNotifier extends StateNotifier<PlayerState> {
  final ApiService _api;
  final WebSocketService _wsService;
  final Ref _ref;
  final just_audio.AudioPlayer _audioPlayer = just_audio.AudioPlayer();

  StreamSubscription<WsEvent>? _wsSub;
  StreamSubscription<just_audio.PlayerState>? _playerSub;
  Timer? _prefetchTimer;
  Timer? _cleanupTimer;
  bool _disposed = false;
  bool _isStopping = false;
  int _version = 0;
  String? _sessionId;

  // 批量预加载并发控制
  static const int _maxConcurrentPrefetch = 3;
  static const int _pageSize = 30;

  PlayerNotifier(this._api, this._wsService, this._ref) : super(const PlayerState()) {
    _playerSub = _audioPlayer.playerStateStream.listen(_handlePlayerState);
    _prefetchTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _prefetchTasks(),
    );
    _cleanupTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _cleanupTasks(),
    );
  }

  /// 安全地更新 state
  void _safeSetState(PlayerState newState) {
    if (_disposed || !mounted) return;

    try {
      state = newState;
    } catch (e) {
      // 捕获所有错误
      if (!e.toString().contains('defunct')) {
        debugPrint('Error updating state: $e');
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;

    // 取消所有订阅
    _wsSub?.cancel();
    _wsSub = null;
    _playerSub?.cancel();
    _playerSub = null;

    // 尝试关闭会话 (Fire and forget)
    if (_sessionId != null) {
      _api
          .closeSession(_sessionId!)
          .then(
            (_) {},
            onError: (e) {
              debugPrint('Error closing session on dispose: $e');
            },
          );
      _sessionId = null;
    }

    _prefetchTimer?.cancel();
    _cleanupTimer?.cancel();
    _audioPlayer.dispose();
    _wsService.disconnectSession();

    // 只有在 mounted 时才调用 super.dispose()，避免 Riverpod 已 dispose 后重复调用
    if (mounted) {
      super.dispose();
    }
  }

  /// 开始播放
  Future<void> startPlayback(
    Novel novel,
    Voice voice, {
    int startIndex = 0,
  }) async {
    if (_disposed) return;

    _isStopping = false;

    // 确保音频播放器监听器已设置
    _playerSub ??= _audioPlayer.playerStateStream.listen(_handlePlayerState);

    _version++;
    _safeSetState(
      state.copyWith(
        novel: novel,
        voice: voice,
        utterances: [],
        currentUtteranceIndex: startIndex,
        playbackState: PlaybackState.loading,
        waitingForAudio: true,
        totalUtterances: novel.totalUtterances,
        loadedStart: 0,
        loadedEnd: 0,
        hasMore: true,
        tasks: {},
        error: null,
        version: _version,
      ),
    );

    final result = await _api.createSession(novel.id, voice.id, startIndex);
    if (_disposed || !mounted) return;

    await result.fold(
      (error) async {
        if (_disposed || !mounted) return;
        _safeSetState(
          state.copyWith(playbackState: PlaybackState.stopped, error: error),
        );
      },
      (PlaySession session) async {
        if (_disposed || !mounted) return;
        _sessionId = session.sessionId;
        _safeSetState(
          state.copyWith(
            session: session,
            currentUtteranceIndex: session.currentIndex,
          ),
        );

        // 连接 WebSocket
        _wsSub?.cancel();
        await _wsService.connectSession(session.sessionId);
        _wsSub = _wsService.sessionEvents.listen(_handleWsEvent);

        // 加载段落
        await _loadUtterances(startIndex: (startIndex - 5).clamp(0, startIndex));
      },
    );
  }

  /// 从历史记录恢复播放
  Future<void> restoreFromHistory({
    required String novelId,
    required int utteranceIndex,
    required String voiceId,
  }) async {
    // 这个方法只是标记 - 实际恢复由外部调用 startPlayback 时传入正确的参数
    // 保留此方法为未来的状态持久化扩展预留接口
    debugPrint('restoreFromHistory: novelId=$novelId, utteranceIndex=$utteranceIndex, voiceId=$voiceId');
  }

  /// 停止播放
  Future<void> stopPlayback({bool clearState = true}) async {
    if (_disposed) return;

    // 立即标记为正在停止，防止任何事件处理
    _isStopping = true;

    // 使用 _sessionId 而不是 state.session?.sessionId
    final sessionId = _sessionId;

    // 先取消订阅，防止音频播放器事件在停止过程中继续触发
    _playerSub?.cancel();
    _playerSub = null;

    await _audioPlayer.stop();

    if (sessionId != null) {
      // 先取消 WS 订阅并断开连接，防止在 closeSession 期间收到新事件
      _wsSub?.cancel();
      _wsSub = null;
      _wsService.disconnectSession();

      // 再关闭后端会话
      await _api.closeSession(sessionId);
      _sessionId = null; // 清除 sessionId
    }

    if (clearState) {
      _safeSetState(const PlayerState());
    }

    // 保持 _isStopping = true，防止延迟事件在导航期间触发状态更新
    // _isStopping 会在下次 startPlayback 时重置
  }

  /// 暂停播放
  void pausePlayback() {
    if (_disposed) return;
    _audioPlayer.pause();
    _safeSetState(state.copyWith(playbackState: PlaybackState.paused));
  }

  /// 恢复播放
  void resumePlayback() {
    if (_disposed) return;
    if (_audioPlayer.playing == false &&
        _audioPlayer.processingState == just_audio.ProcessingState.ready) {
      _audioPlayer.play();
      _safeSetState(state.copyWith(playbackState: PlaybackState.playing));
    }
  }

  /// 跳转到指定段落
  Future<void> seekTo(int index) async {
    if (_disposed || state.session == null) return;

    debugPrint('PlayerNotifier.seekTo(): index=$index, sessionId=${state.session!.sessionId}');
    _version++;
    await _audioPlayer.stop();
    _safeSetState(
      state.copyWith(
        playbackState: PlaybackState.loading,
        waitingForAudio: true,
        tasks: {},
        version: _version,
      ),
    );

    final result = await _api.seek(state.session!.sessionId, index);
    if (_disposed || !mounted) return;
    debugPrint('PlayerNotifier.seekTo(): API result received');
    await result.fold(
      (error) async {
        if (_disposed || !mounted) return;
        debugPrint('PlayerNotifier.seekTo(): error=$error');
        _safeSetState(
          state.copyWith(playbackState: PlaybackState.stopped, error: error),
        );
      },
      (int newIndex) async {
        if (_disposed || !mounted) return;
        debugPrint('PlayerNotifier.seekTo(): success, newIndex=$newIndex');
        // 检查是否需要加载新段落
        if (newIndex < state.loadedStart || newIndex >= state.loadedEnd) {
          await _loadUtterances(
            startIndex: (newIndex - 5).clamp(0, newIndex),
            replace: true,
          );
        }

        // 更新当前索引
        _safeSetState(
          state.copyWith(currentUtteranceIndex: newIndex),
        );

        _submitPrefetchTasks();
      },
    );
  }

  /// 切换音色
  Future<void> changeVoice(Voice voice) async {
    if (_disposed || state.session == null) return;

    _safeSetState(
      state.copyWith(
        voice: voice,
        playbackState: PlaybackState.loading,
        waitingForAudio: true,
        tasks: {},
      ),
    );

    final result = await _api.changeVoice(state.session!.sessionId, voice.id);
    if (_disposed) return;
    result.fold(
      (error) {
        _safeSetState(state.copyWith(error: error));
      },
      (_) {
        _submitPrefetchTasks();
      },
    );
  }

  /// 加载更多段落
  Future<void> loadMoreUtterances() async {
    if (_disposed ||
        state.loadingMore ||
        !state.hasMore ||
        state.session == null) {
      return;
    }

    _safeSetState(state.copyWith(loadingMore: true));
    await _loadUtterances(startIndex: state.loadedEnd, append: true);
  }

  /// 从停止状态开始播放
  void startPlayingFromStopped() {
    if (_disposed || state.session == null) return;

    if (state.isUtteranceReady(state.currentUtteranceIndex)) {
      _loadAndPlayAudio(state.currentUtteranceIndex);
    } else {
      _safeSetState(
        state.copyWith(
          playbackState: PlaybackState.loading,
          waitingForAudio: true,
        ),
      );
      _submitPrefetchTasks();
    }
  }

  // ========== 私有方法 ==========

  Future<void> _loadUtterances({
    required int startIndex,
    bool replace = false,
    bool append = false,
  }) async {
    if (_disposed || state.session == null) return;

    final result = await _api.getUtterances(
      state.session!.novelId,
      start: startIndex,
      limit: _pageSize,
    );

    if (_disposed) return;

    result.fold(
      (error) {
        if (_disposed || !mounted) return;
        _safeSetState(
          state.copyWith(loadingMore: false, error: error),
        );
      },
      (UtterancesResponse data) {
        if (_disposed || !mounted) return;
        final newUtterances = data.utterances;

        List<Utterance> utterances;
        int loadedStart;
        int loadedEnd;

        if (replace || state.utterances.isEmpty) {
          utterances = newUtterances;
          loadedStart = newUtterances.isNotEmpty ? newUtterances.first.index : 0;
          loadedEnd = newUtterances.isNotEmpty
              ? newUtterances.last.index + 1
              : loadedStart;
        } else if (append) {
          utterances = [...state.utterances, ...newUtterances];
          loadedStart = state.loadedStart;
          loadedEnd = utterances.isNotEmpty
              ? utterances.last.index + 1
              : loadedStart;
        } else {
          utterances = newUtterances;
          loadedStart = newUtterances.isNotEmpty ? newUtterances.first.index : 0;
          loadedEnd = newUtterances.isNotEmpty
              ? newUtterances.last.index + 1
              : loadedStart;
        }

        // 使用 API 返回的 total，但如果已有正确的 totalUtterances 则保留
        final total = state.totalUtterances > 0
            ? state.totalUtterances
            : data.total;

        _safeSetState(
          state.copyWith(
            utterances: utterances,
            totalUtterances: total,
            loadedStart: loadedStart,
            loadedEnd: loadedEnd,
            hasMore: loadedEnd < total,
            loadingMore: false,
          ),
        );

        // 初始加载时提交预取任务
        if (!append) {
          _submitPrefetchTasks();
        }
      },
    );
  }

  void _submitPrefetchTasks() {
    if (_disposed || state.session == null) return;

    // 从设置获取预加载数量
    final prefetchCount = _ref.read(prefetchCountProvider);
    
    // 计算当前正在进行的任务数（pending 或 inferring 状态）
    int inProgressCount = 0;
    for (final task in state.tasks.values) {
      if (task.state == TaskState.pending || task.state == TaskState.inferring) {
        inProgressCount++;
      }
    }
    
    // 如果有任务正在进行中，不提交新任务
    if (inProgressCount > 0) return;
    
    // 计算已经加载完成的数量（ready 状态，且在当前段落之后）
    int readyCount = 0;
    for (int i = state.currentUtteranceIndex; i < state.currentUtteranceIndex + prefetchCount + 1 && i < state.totalUtterances; i++) {
      final task = state.tasks[i];
      if (task != null && task.state == TaskState.ready) {
        readyCount++;
      }
    }
    
    // 计算还需要加载的数量
    final targetCount = (prefetchCount + 1).clamp(0, state.totalUtterances - state.currentUtteranceIndex);
    final needToLoad = targetCount - readyCount;
    
    // 如果需要加载的数量 <= 0，则不需要加载
    if (needToLoad <= 0) return;
    
    // 收集需要加载的索引
    final indices = <int>[];
    final end = (state.currentUtteranceIndex + prefetchCount + 1).clamp(
      0,
      state.totalUtterances,
    );

    for (int i = state.currentUtteranceIndex; i < end; i++) {
      final task = state.tasks[i];
      if (task == null ||
          (task.state != TaskState.pending &&
              task.state != TaskState.inferring &&
              task.state != TaskState.ready)) {
        indices.add(i);
      }
    }

    if (indices.isEmpty) return;

    // 批量提交，每批最多 _maxConcurrentPrefetch 个
    _submitPrefetchBatch(indices);
  }

  /// 批量提交预加载任务，限制并发数
  void _submitPrefetchBatch(List<int> indices) {
    if (_disposed || !mounted || state.session == null) return;
    if (indices.isEmpty) return;

    // 取出可提交的索引（最多 batchSize 个）
    final toSubmit = indices.take(_maxConcurrentPrefetch).toList();
    if (toSubmit.isEmpty) return;

    // 更新任务状态为 pending
    final tasks = Map<int, UtteranceTask>.from(state.tasks);
    final now = DateTime.now();
    for (final idx in toSubmit) {
      tasks[idx] = UtteranceTask(
        sessionId: state.session!.sessionId,
        utteranceIndex: idx,
        state: TaskState.pending,
        createdAt: now,
        version: state.version,
      );
    }
    _safeSetState(state.copyWith(tasks: tasks));

    // 提交到服务器（新接口：session_id + utterance_indices）
    _api.submitInfer(state.session!.sessionId, toSubmit).then((result) {
      if (_disposed || !mounted) return;
      result.fold(
        (error) {
          debugPrint('Submit infer error: $error');
          // 清除 pending 状态，允许重试
          if (_disposed || !mounted) return;
          final tasks = Map<int, UtteranceTask>.from(state.tasks);
          for (final idx in toSubmit) {
            tasks.remove(idx);
          }
          _safeSetState(state.copyWith(tasks: tasks));
        },
        (List<TaskInfo> taskInfos) {
          if (_disposed || !mounted) return;
          final tasks = Map<int, UtteranceTask>.from(state.tasks);
          for (final info in taskInfos) {
            final task = tasks[info.utteranceIndex];
            if (task != null) {
              tasks[info.utteranceIndex] = task.copyWith(
                taskId: info.taskId,
                state: TaskState.fromString(info.state),
              );
            }

            if (info.utteranceIndex == state.currentUtteranceIndex &&
                info.state == 'ready' &&
                (state.waitingForAudio ||
                    state.playbackState == PlaybackState.loading)) {
              _loadAndPlayAudio(state.currentUtteranceIndex);
            }
          }
          _safeSetState(state.copyWith(tasks: tasks));
        },
      );
    });
  }

  Future<void> _loadAndPlayAudio(int utteranceIndex) async {
    if (_disposed || !mounted || state.session == null) return;
    if (state.voice == null) {
      _safeSetState(state.copyWith(error: 'Voice not set'));
      return;
    }

    final data = await _api.getUtteranceAudio(
      state.session!.novelId,
      utteranceIndex,
      state.voice!.id,
    );

    if (_disposed || !mounted) return;

    if (data == null) {
      _safeSetState(state.copyWith(waitingForAudio: true));
      return;
    }

    await _playAudioData(data);
    if (_disposed || !mounted) return;
    _safeSetState(
      state.copyWith(
        waitingForAudio: false,
        playbackState: PlaybackState.playing,
      ),
    );
  }

  Future<void> _playAudioData(Uint8List data) async {
    final base64Data = base64Encode(data);
    final dataUri = 'data:audio/wav;base64,$base64Data';
    await _audioPlayer.setUrl(dataUri);
    _audioPlayer.play();
  }

  void _handlePlayerState(just_audio.PlayerState playerState) {
    if (_disposed || _isStopping || !mounted) return;
    if (playerState.processingState == just_audio.ProcessingState.completed) {
      _onAudioFinished();
    }
  }

  void _onAudioFinished() {
    if (_disposed || _isStopping || !mounted) return;
    debugPrint('_onAudioFinished called: playbackState=${state.playbackState}');
    if (state.playbackState != PlaybackState.playing) return;

    if (state.currentUtteranceIndex + 1 >= state.totalUtterances) {
      _safeSetState(state.copyWith(playbackState: PlaybackState.stopped));
      return;
    }

    final nextIndex = state.currentUtteranceIndex + 1;

    // 检查是否就绪
    if (state.isUtteranceReady(nextIndex)) {
      _safeSetState(state.copyWith(currentUtteranceIndex: nextIndex));
      _loadAndPlayAudio(nextIndex);
    } else {
      _safeSetState(
        state.copyWith(
          currentUtteranceIndex: nextIndex,
          playbackState: PlaybackState.loading,
          waitingForAudio: true,
        ),
      );
    }

    _submitPrefetchTasks();
  }

  void _handleWsEvent(WsEvent event) {
    // 多重检查，确保在任何异步间隙后都不会更新已销毁的状态
    if (_disposed || _isStopping || !mounted || !hasListeners) return;

    try {
      if (event is TaskStateChangedEvent) {
        if (state.session == null) return;
        if (event.sessionId != state.session!.sessionId) return;

        // 检查任务是否属于当前 version
        final task = state.tasks[event.utteranceIndex];
        if (task != null && task.sessionId != state.session!.sessionId) {
          debugPrint('Ignoring task from old session: ${event.utteranceIndex}');
          return;
        }

        // 检查任务是否属于当前 version（防止旧 seek/start 的事件污染新状态）
        if (task != null && task.version != state.version) {
          debugPrint('Ignoring task from old version: ${event.utteranceIndex}, task.version=${task.version}, state.version=${state.version}');
          return;
        }

        final tasks = Map<int, UtteranceTask>.from(state.tasks);
        if (task != null) {
          tasks[event.utteranceIndex] = task.copyWith(
            taskId: event.taskId,
            state: TaskState.fromString(event.state),
            durationMs: event.durationMs,
            error: event.error,
            version: state.version,
          );
        } else {
          tasks[event.utteranceIndex] = UtteranceTask(
            sessionId: event.sessionId,
            taskId: event.taskId,
            utteranceIndex: event.utteranceIndex,
            state: TaskState.fromString(event.state),
            durationMs: event.durationMs,
            error: event.error,
            createdAt: DateTime.now(),
            version: state.version,
          );
        }

        // 在更新状态前再次检查
        if (_disposed || !mounted || !hasListeners) return;
        _safeSetState(state.copyWith(tasks: tasks));

        // 检查当前段落是否就绪
        if (event.utteranceIndex == state.currentUtteranceIndex &&
            event.state == 'ready' &&
            (state.waitingForAudio ||
                state.playbackState == PlaybackState.loading)) {
          _loadAndPlayAudio(state.currentUtteranceIndex);
        }
      } else if (event is SessionClosedEvent) {
        if (_disposed || !mounted || !hasListeners) return;
        if (state.session?.sessionId == event.sessionId) {
          _safeSetState(
            state.copyWith(
              session: null,
              playbackState: PlaybackState.stopped,
              tasks: {},
              error: 'Session closed: ${event.reason}',
            ),
          );
        }
      }
    } catch (e) {
      // 捕获所有错误，防止 WebSocket 事件导致应用崩溃
      debugPrint('Error handling WebSocket event: $e');
    }
  }

  void _prefetchTasks() {
    if (_disposed || !mounted) return;
    if (state.playbackState != PlaybackState.playing &&
        state.playbackState != PlaybackState.loading) {
      return;
    }
    if (state.session == null) return;
    _submitPrefetchTasks();
  }

  void _cleanupTasks() {
    if (_disposed || !mounted) return;
    final now = DateTime.now();
    final tasks = Map<int, UtteranceTask>.from(state.tasks);
    final originalLength = tasks.length;
    tasks.removeWhere(
      (_, task) =>
          task.state == TaskState.pending &&
          now.difference(task.createdAt) > const Duration(seconds: 30),
    );
    // 只有在有变化且未被销毁时才更新 state
    if (!_disposed && mounted && tasks.length != originalLength) {
      _safeSetState(state.copyWith(tasks: tasks));
    }
  }
}

/// 播放器 Provider
/// 使用 autoDispose 自动管理生命周期
/// 当没有监听器时（页面完全退出），provider 会自动 dispose
final playerProvider = StateNotifierProvider.autoDispose<PlayerNotifier, PlayerState>((ref) {
  final notifier = PlayerNotifier(
    ref.watch(apiServiceProvider),
    ref.watch(webSocketServiceProvider),
    ref,
  );
  ref.onDispose(() {
    notifier.dispose();
  });
  return notifier;
});
