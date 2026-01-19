import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/novel.dart';
import '../../data/services/api_service.dart';

/// 小说列表视图模式
enum NovelViewMode { grid, list }

/// 视图模式状态 - Web 平台默认列表模式，移动端默认封面模式
final novelViewModeProvider = StateProvider<NovelViewMode>((ref) {
  if (kIsWeb) {
    return NovelViewMode.list;
  } else {
    return NovelViewMode.grid;
  }
});

/// 小说列表状态
class NovelListState {
  final List<Novel> novels;
  final bool isLoading;
  final bool isRefreshing;
  final String? error;

  const NovelListState({
    this.novels = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
  });

  NovelListState copyWith({
    List<Novel>? novels,
    bool? isLoading,
    bool? isRefreshing,
    String? error,
  }) {
    return NovelListState(
      novels: novels ?? this.novels,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: error,
    );
  }
}

/// 小说列表 Notifier
class NovelListNotifier extends StateNotifier<NovelListState> {
  final ApiService _api;

  NovelListNotifier(this._api) : super(const NovelListState()) {
    loadNovels();
  }

  Future<void> loadNovels() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _api.listNovels();
    result.fold(
      (error) => state = state.copyWith(isLoading: false, error: error),
      (List<Novel> novels) => state = state.copyWith(isLoading: false, novels: novels),
    );
  }

  Future<void> refresh() async {
    state = state.copyWith(isRefreshing: true, error: null);
    final result = await _api.listNovels();
    result.fold(
      (error) => state = state.copyWith(isRefreshing: false, error: error),
      (List<Novel> novels) => state = state.copyWith(isRefreshing: false, novels: novels),
    );
  }

  void updateNovel(Novel novel) {
    final novels = state.novels.map((n) => n.id == novel.id ? novel : n).toList();
    state = state.copyWith(novels: novels);
  }

  void addNovel(Novel novel) {
    state = state.copyWith(novels: [novel, ...state.novels]);
  }

  void removeNovel(String id) {
    final novels = state.novels.where((n) => n.id != id).toList();
    state = state.copyWith(novels: novels);
  }

  void setNovelStatus(String id, NovelStatus status) {
    final novels = state.novels.map((n) {
      if (n.id == id) {
        return n.copyWith(status: status);
      }
      return n;
    }).toList();
    state = state.copyWith(novels: novels);
  }
}

/// 小说列表 Provider
final novelListProvider = StateNotifierProvider<NovelListNotifier, NovelListState>((ref) {
  return NovelListNotifier(ref.watch(apiServiceProvider));
});

/// 选中的小说
final selectedNovelProvider = StateProvider<Novel?>((ref) => null);
