import 'package:flutter/material.dart';
import '../../../core/providers/player_provider.dart';

/// 播放控制栏组件
class PlayerControls extends StatelessWidget {
  final PlayerState state;
  final VoidCallback onPlayPause;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final Function(int) onSeek;

  const PlayerControls({
    super.key,
    required this.state,
    required this.onPlayPause,
    required this.onPrevious,
    required this.onNext,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = state.totalSegments > 0
        ? (state.currentSegmentIndex + 1) / state.totalSegments
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 进度条
            _ProgressSlider(
              progress: progress,
              currentIndex: state.currentSegmentIndex,
              totalSegments: state.totalSegments,
              onSeek: onSeek,
            ),
            // 控制按钮
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 进度信息
                  Expanded(
                    child: Text(
                      '${state.currentSegmentIndex + 1} / ${state.totalSegments}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                  // 上一段
                  IconButton(
                    onPressed: state.currentSegmentIndex > 0 ? onPrevious : null,
                    icon: const Icon(Icons.skip_previous_rounded),
                    iconSize: 32,
                    color: colorScheme.onSurface,
                    disabledColor: colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  const SizedBox(width: 8),
                  // 播放/暂停
                  _PlayPauseButton(
                    state: state.playbackState,
                    waitingForAudio: state.waitingForAudio,
                    onPressed: onPlayPause,
                  ),
                  const SizedBox(width: 8),
                  // 下一段
                  IconButton(
                    onPressed: state.currentSegmentIndex < state.totalSegments - 1
                        ? onNext
                        : null,
                    icon: const Icon(Icons.skip_next_rounded),
                    iconSize: 32,
                    color: colorScheme.onSurface,
                    disabledColor: colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  // 状态指示
                  Expanded(
                    child: Text(
                      _getStatusText(state),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusText(PlayerState state) {
    if (state.waitingForAudio) {
      return '准备中...';
    }
    switch (state.playbackState) {
      case PlaybackState.playing:
        return '播放中';
      case PlaybackState.paused:
        return '已暂停';
      case PlaybackState.loading:
        return '加载中...';
      case PlaybackState.stopped:
        return '已停止';
    }
  }
}

class _ProgressSlider extends StatelessWidget {
  final double progress;
  final int currentIndex;
  final int totalSegments;
  final Function(int) onSeek;

  const _ProgressSlider({
    required this.progress,
    required this.currentIndex,
    required this.totalSegments,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.surfaceContainerHighest,
        thumbColor: colorScheme.primary,
        overlayColor: colorScheme.primary.withValues(alpha: 0.2),
      ),
      child: Slider(
        value: totalSegments > 0 ? currentIndex.toDouble() : 0,
        min: 0,
        max: totalSegments > 0 ? (totalSegments - 1).toDouble() : 1,
        onChanged: (value) => onSeek(value.round()),
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  final PlaybackState state;
  final bool waitingForAudio;
  final VoidCallback onPressed;

  const _PlayPauseButton({
    required this.state,
    required this.waitingForAudio,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLoading = state == PlaybackState.loading || waitingForAudio;
    final isPlaying = state == PlaybackState.playing;

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            colorScheme.tertiary,
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(32),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: colorScheme.onPrimary,
                    ),
                  )
                : Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 36,
                    color: colorScheme.onPrimary,
                  ),
          ),
        ),
      ),
    );
  }
}
