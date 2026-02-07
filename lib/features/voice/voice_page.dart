import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/voice_provider.dart';
import '../../data/models/voice.dart';
import '../../data/services/websocket_service.dart';
import 'widgets/voice_card.dart';
import 'upload_voice_page.dart';

/// 音色管理页面
class VoicePage extends ConsumerStatefulWidget {
  const VoicePage({super.key});

  @override
  ConsumerState<VoicePage> createState() => _VoicePageState();
}

class _VoicePageState extends ConsumerState<VoicePage> {
  @override
  void initState() {
    super.initState();
    _setupWebSocketListener();
  }

  void _setupWebSocketListener() {
    final wsService = ref.read(webSocketServiceProvider);
    wsService.globalEvents.listen((event) {
      if (!mounted) return;
      
      if (event is VoiceDeletedEvent) {
        ref.read(voiceListProvider.notifier).removeVoice(event.voiceId);
      }
    });
  }

  Future<void> _onRefresh() async {
    await ref.read(voiceListProvider.notifier).refresh();
  }

  void _showUploadDialog() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const UploadVoicePage(),
      ),
    );
  }

  Future<void> _setDefaultVoice(Voice voice) async {
    await ref.read(voiceListProvider.notifier).setDefaultVoice(voice.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已设置 ${voice.name} 为默认音色')),
      );
    }
  }

  Future<void> _deleteVoice(Voice voice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除音色'),
        content: Text('确定要删除音色「${voice.name}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // 调用删除 API
      ref.read(voiceListProvider.notifier).removeVoice(voice.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceListProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '音色管理',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: colorScheme.primary,
        child: _buildContent(voiceState),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: _showUploadDialog,
        icon: const Icon(Icons.add),
        label: const Text('添加音色'),
      ),
    );
  }

  Widget _buildContent(VoiceListState state) {
    if (state.isLoading && state.voices.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (state.error != null && state.voices.isEmpty) {
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
            Text(
              '加载失败',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              state.error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => ref.read(voiceListProvider.notifier).loadVoices(),
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (state.voices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.record_voice_over_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              '还没有音色',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击下方按钮添加音色',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.voices.length,
      itemBuilder: (context, index) {
        final voice = state.voices[index];
        final isDefault = voice.id == state.defaultVoiceId;
        
        return VoiceCard(
          voice: voice,
          isDefault: isDefault,
          onTap: () => _setDefaultVoice(voice),
          onDelete: () => _deleteVoice(voice),
        );
      },
    );
  }
}
