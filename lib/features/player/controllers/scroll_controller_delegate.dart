import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 滚动控制器委托 - 处理播放页面的滚动和自动加载逻辑
class ScrollControllerDelegate {
  final WidgetRef ref;
  final ScrollController scrollController;
  final VoidCallback onLoadMore;

  int? _scrollToIndex;
  bool _isNavigatingAway = false;

  ScrollControllerDelegate({
    required this.ref,
    required this.scrollController,
    required this.onLoadMore,
  }) {
    scrollController.addListener(_onScroll);
  }

  /// 当前滚动目标索引
  int? get scrollToIndex => _scrollToIndex;

  /// 是否正在导航离开
  bool get isNavigatingAway => _isNavigatingAway;

  /// 设置导航离开状态
  set isNavigatingAway(bool value) => _isNavigatingAway = value;

  /// 滚动到指定段落（在段落数据准备好后调用）
  void scrollToSegmentWhenReady(int index) {
    if (_isNavigatingAway) return;
    try {
      _scrollToIndex = index;
    } catch (e) {
      debugPrint('Error in scrollToSegmentWhenReady: $e');
    }
  }

  /// 清除滚动目标
  void clearScrollToIndex() {
    _scrollToIndex = null;
  }

  /// 检查是否需要自动加载更多（当内容不足以滚动时）
  void checkAutoLoadMore() {
    if (_isNavigatingAway) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scrollController.hasClients) return;

      final position = scrollController.position;
      if (position.maxScrollExtent <= 0) {
        onLoadMore();
      }
    });
  }

  /// 处理滚动事件
  void _onScroll() {
    if (_isNavigatingAway || !scrollController.hasClients) return;
    final position = scrollController.position;
    // 当滚动到距离底部 200 像素内时，加载更多
    if (position.pixels >= position.maxScrollExtent - 200) {
      onLoadMore();
    }
  }

  /// 获取 mounted 状态（从 ScrollController 获取）
  bool get mounted => scrollController.hasClients;

  /// 释放资源
  void dispose() {
    scrollController.removeListener(_onScroll);
  }
}

/// 滚动控制器 Provider
final scrollControllerProvider = Provider<ScrollController>((ref) {
  final controller = ScrollController();
  ref.onDispose(() => controller.dispose());
  return controller;
});
