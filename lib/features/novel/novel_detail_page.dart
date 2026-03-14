import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/novel.dart';
import '../../data/models/novel_brief.dart';
import '../../data/models/voice.dart';
import '../../data/services/api_service.dart';
import '../../core/providers/voice_provider.dart';
import '../../core/providers/history_provider.dart';
import '../player/player_page.dart';
import 'widgets/speaker_list_widget.dart';
import 'widgets/novel_info_header.dart';

/// 小说详情页面
class NovelDetailPage extends ConsumerStatefulWidget {
  final Novel novel;

  const NovelDetailPage({super.key, required this.novel});

  @override
  ConsumerState<NovelDetailPage> createState() => _NovelDetailPageState();
}

class _NovelDetailPageState extends ConsumerState<NovelDetailPage> {
  NovelBrief? _brief;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBrief();
  }

  Future<void> _loadBrief() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final api = ref.read(apiServiceProvider);
    final result = await api.getNovelBrief(widget.novel.id);

    if (!mounted) return;

    result.fold(
      (error) {
        setState(() {
          _isLoading = false;
          _error = error;
        });
      },
      (brief) {
        setState(() {
          _isLoading = false;
          _brief = brief;
        });
      },
    );
  }

  void _startPlayback({int startIndex = 0}) {
    final voiceState = ref.read(voiceListProvider);
    if (voiceState.voices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先添加音色')),
      );
      return;
    }

    // 检查是否有播放历史
    final history =
        ref.read(historyProvider.notifier).getLastPosition(widget.novel.id);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PlayerPage(
          novel: widget.novel,
          startIndex: startIndex > 0 ? startIndex : (history?.segmentIndex ?? 0),
        ),
      ),
    );
  }

  Future<void> _assignVoiceToSpeaker(SpeakerInfo speaker) async {
    final voiceState = ref.read(voiceListProvider);
    if (voiceState.voices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先添加音色')),
      );
      return;
    }

    final selectedVoice = await showModalBottomSheet<Voice>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _VoicePickerSheet(
        voices: voiceState.voices,
        currentVoiceId: speaker.voiceId,
      ),
    );

    if (selectedVoice == null || !mounted) return;

    // 调用 API 分配音色
    final api = ref.read(apiServiceProvider);
    final result = await api.assignSpeakerVoice(
      widget.novel.id,
      speaker.name,
      selectedVoice.id,
    );

    if (!mounted) return;

    result.fold(
      (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分配音色失败: $error')),
        );
      },
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已为「${speaker.name}」分配音色「${selectedVoice.name}」'),
          ),
        );
        // 刷新 brief 数据
        _loadBrief();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final history =
        ref.watch(historyProvider).histories
            .where((h) => h.novelId == widget.novel.id)
            .firstOrNull;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 顶部 AppBar
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primaryContainer,
                      colorScheme.secondaryContainer,
                    ],
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.auto_stories,
                      size: 64,
                      color: colorScheme.onPrimaryContainer.withValues(alpha: 0.15),
                    ),
                    if (widget.novel.title.isNotEmpty)
                      Text(
                        widget.novel.title[0],
                        style: TextStyle(
                          fontSize: 80,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onPrimaryContainer.withValues(alpha: 0.4),
                        ),
                      ),
                  ],
                ),
              ),
              title: Text(
                widget.novel.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // 内容区域
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: _buildErrorView(),
            )
          else
            SliverToBoxAdapter(
              child: _buildContent(history),
            ),
        ],
      ),
      // 底部播放按钮
      bottomNavigationBar: widget.novel.canPlay
          ? _buildBottomBar(history)
          : null,
    );
  }

  Widget _buildErrorView() {
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
            _error!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _loadBrief,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(dynamic history) {
    final brief = _brief!;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 小说信息卡片
          NovelInfoHeader(
            novel: widget.novel,
            brief: brief,
            history: history,
          ),

          const SizedBox(height: 24),

          // 角色/Speaker 列表
          if (brief.speakers.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.people_outline, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '角色配音',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                Text(
                  '${brief.assignedSpeakerCount}/${brief.speakerCount} 已分配',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SpeakerListWidget(
              speakers: brief.speakers,
              onAssignVoice: _assignVoiceToSpeaker,
            ),
          ] else if (brief.isParseCompleted) ...[
            // 解析完成但没有 speakers
            _buildEmptySpeakersHint(),
          ] else if (!brief.isParseCompleted && widget.novel.status != NovelStatus.ready) ...[
            // 还在解析中
            _buildParsingHint(),
          ],

          // 底部留白（给底部按钮让位）
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildEmptySpeakersHint() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '该小说未检测到多角色对话，将使用默认音色朗读。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParsingHint() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '小说正在解析中，角色信息稍后显示...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(dynamic history) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasHistory = history != null;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
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
      child: Row(
        children: [
          if (hasHistory) ...[
            // 继续播放信息
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '上次听到',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  Text(
                    '第 ${history.segmentIndex + 1} 段 / 共 ${widget.novel.totalSegments} 段',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // 从头播放按钮
            OutlinedButton.icon(
              onPressed: () => _startPlayback(startIndex: 0),
              icon: const Icon(Icons.replay, size: 18),
              label: const Text('从头开始'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(width: 8),
            // 继续播放按钮
            FilledButton.icon(
              onPressed: () => _startPlayback(startIndex: history.segmentIndex),
              icon: const Icon(Icons.play_arrow),
              label: const Text('继续播放'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ] else ...[
            // 没有历史，直接显示播放按钮
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _startPlayback(),
                icon: const Icon(Icons.play_arrow),
                label: const Text('开始播放'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 音色选择底部弹窗
class _VoicePickerSheet extends StatelessWidget {
  final List<Voice> voices;
  final String? currentVoiceId;

  const _VoicePickerSheet({
    required this.voices,
    this.currentVoiceId,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.8,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // 拖动手柄
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '选择音色',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: voices.length,
                itemBuilder: (context, index) {
                  final voice = voices[index];
                  final isSelected = voice.id == currentVoiceId;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isSelected
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.record_voice_over,
                        size: 20,
                        color: isSelected
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    title: Text(
                      voice.name,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    subtitle: voice.allDisplayTags.isNotEmpty
                        ? Wrap(
                            spacing: 4,
                            children: voice.allDisplayTags.take(3).map((tag) {
                              return Text(
                                tag,
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              );
                            }).toList(),
                          )
                        : voice.description != null
                            ? Text(
                                voice.description!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: colorScheme.primary)
                        : null,
                    onTap: () => Navigator.of(context).pop(voice),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
