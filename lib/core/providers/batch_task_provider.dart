import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/batch_task.dart';
import '../../data/services/api_service.dart';

/// 批量任务列表状态
class BatchTaskListState {
  final List<BatchTask> tasks;
  final bool isLoading;
  final bool isRefreshing;
  final String? error;

  const BatchTaskListState({
    this.tasks = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
  });

  BatchTaskListState copyWith({
    List<BatchTask>? tasks,
    bool? isLoading,
    bool? isRefreshing,
    String? error,
  }) {
    return BatchTaskListState(
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: error,
    );
  }
}

/// 批量任务列表 Notifier
class BatchTaskListNotifier extends StateNotifier<BatchTaskListState> {
  final ApiService _api;
  Timer? _pollingTimer;
  static const _pollInterval = Duration(seconds: 3);

  BatchTaskListNotifier(this._api) : super(const BatchTaskListState());

  /// 加载任务列表
  Future<void> loadTasks() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _api.listBatchTasks();
    result.fold(
      (error) => state = state.copyWith(isLoading: false, error: error),
      (tasks) => state = state.copyWith(isLoading: false, tasks: tasks),
    );
  }

  /// 刷新任务列表
  Future<void> refresh() async {
    state = state.copyWith(isRefreshing: true, error: null);
    final result = await _api.listBatchTasks();
    result.fold(
      (error) => state = state.copyWith(isRefreshing: false, error: error),
      (tasks) => state = state.copyWith(isRefreshing: false, tasks: tasks),
    );
  }

  /// 开始轮询
  void startPolling() {
    stopPolling();
    loadTasks();
    _pollingTimer = Timer.periodic(_pollInterval, (_) => _pollTasks());
  }

  /// 停止轮询
  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// 静默轮询更新
  Future<void> _pollTasks() async {
    final result = await _api.listBatchTasks();
    result.fold(
      (_) {}, // 轮询时忽略错误
      (tasks) => state = state.copyWith(tasks: tasks),
    );
  }

  /// 创建批量任务
  Future<String?> createTask(
    String novelId,
    String voiceId, {
    int segmentStart = 0,
    int? segmentEnd,
  }) async {
    final result = await _api.createBatchTask(
      novelId,
      voiceId,
      segmentStart: segmentStart,
      segmentEnd: segmentEnd,
    );
    return result.fold(
      (error) => error,
      (task) {
        state = state.copyWith(tasks: [task, ...state.tasks]);
        return null;
      },
    );
  }

  /// 暂停任务
  Future<String?> pauseTask(String taskId) async {
    final result = await _api.pauseBatchTask(taskId);
    return result.fold(
      (error) => error,
      (task) {
        _updateTask(task);
        return null;
      },
    );
  }

  /// 恢复任务
  Future<String?> resumeTask(String taskId) async {
    final result = await _api.resumeBatchTask(taskId);
    return result.fold(
      (error) => error,
      (task) {
        _updateTask(task);
        return null;
      },
    );
  }

  /// 取消任务
  Future<String?> cancelTask(String taskId) async {
    final result = await _api.cancelBatchTask(taskId);
    return result.fold(
      (error) => error,
      (task) {
        _updateTask(task);
        return null;
      },
    );
  }

  void _updateTask(BatchTask task) {
    final tasks = state.tasks.map((t) {
      return t.taskId == task.taskId ? task : t;
    }).toList();
    state = state.copyWith(tasks: tasks);
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}

/// 批量任务列表 Provider
final batchTaskListProvider =
    StateNotifierProvider<BatchTaskListNotifier, BatchTaskListState>((ref) {
  return BatchTaskListNotifier(ref.watch(apiServiceProvider));
});
