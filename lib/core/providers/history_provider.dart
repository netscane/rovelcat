import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/play_history.dart';

const String _historyKey = 'play_history';
const int _maxHistoryCount = 50;

/// 播放历史状态
class HistoryState {
  final List<PlayHistory> histories;
  final bool isLoading;

  const HistoryState({
    this.histories = const [],
    this.isLoading = false,
  });

  HistoryState copyWith({
    List<PlayHistory>? histories,
    bool? isLoading,
  }) {
    return HistoryState(
      histories: histories ?? this.histories,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// 播放历史 Notifier
class HistoryNotifier extends StateNotifier<HistoryState> {
  HistoryNotifier() : super(const HistoryState()) {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    state = state.copyWith(isLoading: true);
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList(_historyKey) ?? [];
    
    final histories = historyJson
        .map((json) => PlayHistory.fromJson(jsonDecode(json)))
        .toList();
    
    // 按播放时间排序（最近的在前）
    histories.sort((a, b) => b.playedAt.compareTo(a.playedAt));
    
    state = state.copyWith(
      histories: histories,
      isLoading: false,
    );
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = state.histories
        .map((h) => jsonEncode(h.toJson()))
        .toList();
    await prefs.setStringList(_historyKey, historyJson);
  }

  /// 保存播放进度
  Future<void> savePlayProgress({
    required String novelId,
    required String novelTitle,
    String? coverUrl,
    required int segmentIndex,
    required String voiceId,
    required String voiceName,
    required int totalSegments,
  }) async {
    final history = PlayHistory(
      novelId: novelId,
      novelTitle: novelTitle,
      coverUrl: coverUrl,
      segmentIndex: segmentIndex,
      voiceId: voiceId,
      voiceName: voiceName,
      totalSegments: totalSegments,
      playedAt: DateTime.now(),
    );

    // 移除同一小说的旧记录
    final histories = state.histories
        .where((h) => h.novelId != novelId)
        .toList();
    
    // 添加新记录到开头
    histories.insert(0, history);
    
    // 限制历史记录数量
    if (histories.length > _maxHistoryCount) {
      histories.removeRange(_maxHistoryCount, histories.length);
    }

    state = state.copyWith(histories: histories);
    await _saveHistory();
  }

  /// 获取小说的最后播放位置
  PlayHistory? getLastPosition(String novelId) {
    return state.histories
        .where((h) => h.novelId == novelId)
        .firstOrNull;
  }

  /// 删除单条历史记录
  Future<void> removeHistory(String novelId) async {
    final histories = state.histories
        .where((h) => h.novelId != novelId)
        .toList();
    state = state.copyWith(histories: histories);
    await _saveHistory();
  }

  /// 清除所有历史记录
  Future<void> clearHistory() async {
    state = state.copyWith(histories: []);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  /// 刷新历史记录
  Future<void> refresh() async {
    await _loadHistory();
  }
}

/// 播放历史 Provider
final historyProvider = StateNotifierProvider<HistoryNotifier, HistoryState>((ref) {
  return HistoryNotifier();
});
