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

  void _startPlayback({int startIndex = -1}) {
    final voiceState = ref.read(voiceListProvider);
    if (voiceState.voices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先添加音色')),
      );
      return;
    }

    final brief = _brief;
    if (brief == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正在加载小说信息，请稍候...')),
      );
      return;
    }

    if (brief.totalUtterances == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该小说暂无音频内容，请等待处理完成')),
      );
      _loadBrief();
      return;
    }

    final history =
        ref.read(historyProvider.notifier).getLastPosition(widget.novel.id);
    final historyIndex = history?.utteranceIndex ?? 0;
    final validIndex = startIndex < 0 ? historyIndex : startIndex;

    if (validIndex >= brief.totalUtterances) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('播放位置无效（共 ${brief.totalUtterances} 段），将从头开始播放')),
      );
      _startPlayback(startIndex: 0);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PlayerPage(
          novel: widget.novel,
          startIndex: validIndex,
        ),
      ),
    );
  }

  Future<void> _setNarrationVoice() async {
    final brief = _brief;
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
        currentVoiceId: brief?.narrationVoiceId,
      ),
    );

    if (selectedVoice == null || !mounted) return;

    final api = ref.read(apiServiceProvider);
    final result = await api.setNarrationVoice(
      widget.novel.id,
      selectedVoice.id,
    );

    if (!mounted) return;

    result.fold(
      (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('设置旁白音色失败: $error')),
        );
      },
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已设置旁白音色「${selectedVoice.name}」')),
        );
        _loadBrief();
      },
    );
  }

  Future<void> _assignVoiceToSpeaker(SpeakerInfo speaker) async {
    final brief = _brief;

    if (brief != null && !brief.canAssignVoice) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(brief.assignBlockReason ?? '当前不支持分配音色')),
      );
      return;
    }

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
          SnackBar(content: Text('已为「${speaker.name}」分配音色「${selectedVoice.name}」')),
        );
        _loadBrief();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyProvider).histories
        .where((h) => h.novelId == widget.novel.id)
        .firstOrNull;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero header
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            stretch: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _HeroHeader(novel: widget.novel),
              title: Text(
                widget.novel.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              titlePadding: const EdgeInsets.only(left: 56, right: 56, bottom: 16),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: '刷新',
                onPressed: _isLoading ? null : _loadBrief,
              ),
            ],
          ),

          // Content
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(child: _buildErrorView())
          else
            SliverToBoxAdapter(child: _buildContent(history)),
        ],
      ),
      bottomNavigationBar:
          _shouldShowPlayBar() ? _buildBottomBar(history) : null,
    );
  }

  bool _shouldShowPlayBar() {
    if (_brief == null || _error != null) return false;
    if (widget.novel.status != NovelStatus.ready) return false;
    return _brief!.totalUtterances > 0;
  }

  Widget _buildErrorView() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.cloud_off_rounded, size: 36, color: colorScheme.error),
            ),
            const SizedBox(height: 20),
            Text('加载失败', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadBrief,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(dynamic history) {
    final brief = _brief!;
    final colorScheme = Theme.of(context).colorScheme;
    final canAssign = brief.canAssignVoice;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 统计数据 + 信息
          NovelInfoHeader(novel: widget.novel, brief: brief, history: history),

          const SizedBox(height: 20),

          // 旁白音色
          _buildNarrationSection(brief),

          const SizedBox(height: 20),

          // 警告/提示区域
          if (!brief.isParseCompleted) ...[
            _buildBanner(
              icon: Icons.autorenew_rounded,
              iconColor: colorScheme.primary,
              bgColor: colorScheme.primaryContainer.withValues(alpha: 0.25),
              borderColor: colorScheme.primary.withValues(alpha: 0.15),
              text: _workerProgressText(brief),
              trailing: IconButton(
                icon: Icon(Icons.refresh_rounded, size: 18, color: colorScheme.primary),
                onPressed: _loadBrief,
                tooltip: '刷新状态',
                visualDensity: VisualDensity.compact,
              ),
              spinning: true,
            ),
            const SizedBox(height: 12),
          ],

          if (brief.hasConflicts) ...[
            _buildBanner(
              icon: Icons.warning_amber_rounded,
              iconColor: colorScheme.error,
              bgColor: colorScheme.errorContainer.withValues(alpha: 0.2),
              borderColor: colorScheme.error.withValues(alpha: 0.15),
              text: '有 ${brief.worker.conflictCharacters} 个角色存在冲突，需先处理冲突后才可分配音色。',
            ),
            const SizedBox(height: 12),
          ],

          if (!canAssign && brief.assignBlockReason != null && brief.speakers.isNotEmpty) ...[
            _buildBanner(
              icon: Icons.lock_rounded,
              iconColor: colorScheme.onSurfaceVariant,
              bgColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderColor: colorScheme.outlineVariant.withValues(alpha: 0.2),
              text: brief.assignBlockReason!,
            ),
            const SizedBox(height: 12),
          ],

          // 角色配音列表
          if (brief.speakers.isNotEmpty) ...[
            _buildSectionHeader(
              context,
              icon: Icons.people_rounded,
              title: '角色配音',
              trailing: _buildAssignmentProgress(brief, colorScheme),
            ),
            const SizedBox(height: 10),
            SpeakerListWidget(
              speakers: brief.speakers,
              onAssignVoice: _assignVoiceToSpeaker,
              enabled: canAssign,
            ),
          ] else if (brief.isParseCompleted) ...[
            _buildBanner(
              icon: Icons.info_outline_rounded,
              iconColor: colorScheme.onSurfaceVariant,
              bgColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderColor: colorScheme.outlineVariant.withValues(alpha: 0.2),
              text: '该小说未检测到多角色对话，将使用默认音色朗读。',
            ),
          ],

          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildAssignmentProgress(NovelBrief brief, ColorScheme colorScheme) {
    final total = brief.speakerCount;
    final assigned = brief.assignedSpeakerCount;
    final ratio = total > 0 ? assigned / total : 0.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 40,
          height: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: colorScheme.outlineVariant.withValues(alpha: 0.3),
              color: colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$assigned/$total',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  /// 旁白音色区域
  Widget _buildNarrationSection(NovelBrief brief) {
    final colorScheme = Theme.of(context).colorScheme;
    final voiceState = ref.watch(voiceListProvider);
    final narrationVoiceId = brief.narrationVoiceId;
    final narrationVoice = narrationVoiceId != null
        ? voiceState.voices.where((v) => v.id == narrationVoiceId).firstOrNull
        : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: colorScheme.surfaceContainerLow,
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.menu_book_rounded, size: 18, color: colorScheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '旁白音色',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              _NarrationActionButton(
                hasVoice: narrationVoice != null,
                onPressed: _setNarrationVoice,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (narrationVoice != null)
            _NarrationVoiceChip(voice: narrationVoice)
          else
            Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '为叙述部分指定默认配音',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    Widget? trailing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildBanner({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
    required String text,
    Widget? trailing,
    bool spinning = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          if (spinning)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: iconColor),
            )
          else
            Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  String _workerProgressText(NovelBrief brief) {
    final worker = brief.worker;
    if (worker.newCharacters > 0) {
      return '正在解析角色中... 已发现 ${worker.totalCharacters} 个角色，${worker.newCharacters} 个待确认';
    } else if (worker.totalCharacters > 0) {
      return '角色解析中... 已发现 ${worker.totalCharacters} 个角色';
    }
    return '小说正在解析中，角色信息稍后显示...';
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
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.15)),
        ),
      ),
      child: hasHistory ? _buildResumeBar(history) : _buildStartBar(),
    );
  }

  Widget _buildResumeBar(dynamic history) {
    final colorScheme = Theme.of(context).colorScheme;
    final brief = _brief;
    final total = brief?.totalUtterances ?? widget.novel.totalUtterances;
    final progress = total > 0 ? (history.utteranceIndex + 1) / total : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 进度条
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 3,
            backgroundColor: colorScheme.surfaceContainerHighest,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '上次听到 第 ${history.utteranceIndex + 1} 段',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  Text(
                    '共 $total 段 · ${(progress * 100).toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: () => _startPlayback(startIndex: 0),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('从头'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => _startPlayback(startIndex: history.utteranceIndex),
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: const Text('继续播放'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStartBar() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => _startPlayback(),
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('开始播放'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

// ============================================================
// Hero Header
// ============================================================

class _HeroHeader extends StatelessWidget {
  final Novel novel;

  const _HeroHeader({required this.novel});

  @override
  Widget build(BuildContext context) {
    final title = novel.title;
    final hue = (title.hashCode % 360).abs().toDouble();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HSLColor.fromAHSL(1, hue, 0.35, 0.65).toColor(),
            HSLColor.fromAHSL(1, (hue + 40) % 360, 0.4, 0.45).toColor(),
          ],
        ),
      ),
      child: Stack(
        children: [
          // 装饰性图案
          Positioned(
            right: -30,
            top: -20,
            child: Icon(
              Icons.auto_stories_rounded,
              size: 180,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          Positioned(
            left: -20,
            bottom: -10,
            child: Icon(
              Icons.headphones_rounded,
              size: 120,
              color: Colors.white.withValues(alpha: 0.04),
            ),
          ),
          // 中心首字
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    title.isNotEmpty ? title[0] : '?',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Narration Voice helpers
// ============================================================

class _NarrationActionButton extends StatelessWidget {
  final bool hasVoice;
  final VoidCallback onPressed;

  const _NarrationActionButton({required this.hasVoice, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    if (hasVoice) {
      return TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.swap_horiz_rounded, size: 16),
        label: const Text('更换'),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          visualDensity: VisualDensity.compact,
        ),
      );
    }
    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        visualDensity: VisualDensity.compact,
      ),
      child: const Text('设置'),
    );
  }
}

class _NarrationVoiceChip extends StatelessWidget {
  final Voice voice;

  const _NarrationVoiceChip({required this.voice});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hue = (voice.name.hashCode % 360).abs().toDouble();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              gradient: LinearGradient(
                colors: [
                  HSLColor.fromAHSL(1, hue, 0.5, 0.5).toColor(),
                  HSLColor.fromAHSL(1, (hue + 30) % 360, 0.6, 0.4).toColor(),
                ],
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              voice.name.isNotEmpty ? voice.name[0].toUpperCase() : 'V',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  voice.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                if (voice.description != null && voice.description!.isNotEmpty)
                  Text(
                    voice.description!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Icon(Icons.check_circle_rounded, color: colorScheme.primary, size: 18),
        ],
      ),
    );
  }
}

// ============================================================
// Voice Picker Sheet
// ============================================================

class _VoicePickerSheet extends StatelessWidget {
  final List<Voice> voices;
  final String? currentVoiceId;

  const _VoicePickerSheet({required this.voices, this.currentVoiceId});

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
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '选择音色',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    '${voices.length} 个可用',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                itemCount: voices.length,
                itemBuilder: (context, index) {
                  final voice = voices[index];
                  final isSelected = voice.id == currentVoiceId;
                  final hue = (voice.name.hashCode % 360).abs().toDouble();

                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(11),
                        gradient: LinearGradient(
                          colors: [
                            HSLColor.fromAHSL(1, hue, 0.5, 0.5).toColor(),
                            HSLColor.fromAHSL(1, (hue + 30) % 360, 0.6, 0.4).toColor(),
                          ],
                        ),
                        border: isSelected
                            ? Border.all(color: colorScheme.primary, width: 2)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        voice.name.isNotEmpty ? voice.name[0].toUpperCase() : 'V',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
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
                        ? Icon(Icons.check_circle_rounded, color: colorScheme.primary)
                        : Icon(Icons.circle_outlined, size: 20, color: colorScheme.outlineVariant),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    selectedTileColor: colorScheme.primaryContainer.withValues(alpha: 0.2),
                    selected: isSelected,
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
