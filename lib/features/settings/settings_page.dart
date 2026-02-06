import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/history_provider.dart';
import '../../core/providers/voice_provider.dart';
import 'widgets/history_list_dialog.dart';

/// 设置页面
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(settingsProvider);
    final voiceState = ref.watch(voiceListProvider);
    final historyState = ref.watch(historyProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '设置',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // 播放设置分组
          _SectionHeader(title: '播放设置'),
          _SettingsTile(
            icon: Icons.record_voice_over,
            iconColor: colorScheme.primary,
            title: '默认音色',
            subtitle: voiceState.defaultVoice?.name ?? '未设置',
            onTap: () => _showVoiceSelector(context, ref),
          ),
          const Divider(height: 1, indent: 72),
          _SettingsTile(
            icon: Icons.download_for_offline,
            iconColor: colorScheme.secondary,
            title: '预加载数量',
            subtitle: '${settingsState.prefetchCount} 段',
            onTap: () => _showPrefetchCountDialog(context, ref),
          ),
          const Divider(height: 1, indent: 72),
          _SettingsTile(
            icon: Icons.history,
            iconColor: colorScheme.tertiary,
            title: '播放历史',
            subtitle: '${historyState.histories.length} 条记录',
            onTap: () => _showHistoryDialog(context),
          ),
          const SizedBox(height: 16),

          // 外观设置分组
          _SectionHeader(title: '外观设置'),
          _SettingsTile(
            icon: Icons.dark_mode,
            iconColor: colorScheme.secondary,
            title: '深色模式',
            subtitle: _getThemeModeText(settingsState.themeMode),
            onTap: () => _showThemeModeDialog(context, ref),
          ),
          const SizedBox(height: 16),

          // 服务器设置分组
          _SectionHeader(title: '服务器设置'),
          _SettingsTile(
            icon: Icons.dns,
            iconColor: colorScheme.error,
            title: '服务器地址',
            subtitle: _getServerAddress(settingsState),
            onTap: () => _showServerDialog(context, ref),
          ),
          const SizedBox(height: 16),

          // 关于分组
          _SectionHeader(title: '关于'),
          _SettingsTile(
            icon: Icons.info_outline,
            iconColor: colorScheme.onSurfaceVariant,
            title: '关于 Rovelcat',
            subtitle: '版本 1.0.0',
            onTap: () => _showAboutDialog(context),
          ),

          const SizedBox(height: 80), // 底部留白
        ],
      ),
    );
  }

  String _getThemeModeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return '跟随系统';
      case ThemeMode.light:
        return '浅色模式';
      case ThemeMode.dark:
        return '深色模式';
    }
  }

  String _getServerAddress(SettingsState state) {
    if (state.serverHost != null && state.serverPort != null) {
      return '${state.serverHost}:${state.serverPort}';
    }
    return '未配置';
  }

  void _showVoiceSelector(BuildContext context, WidgetRef ref) {
    final voiceState = ref.read(voiceListProvider);
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '选择默认音色',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          if (voiceState.voices.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.record_voice_over_outlined,
                    size: 48,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '还没有音色，请先添加',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: voiceState.voices.length,
                itemBuilder: (context, index) {
                  final voice = voiceState.voices[index];
                  final isSelected = voice.id == voiceState.defaultVoiceId;
                  
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isSelected
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.mic,
                        color: isSelected
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    title: Text(voice.name),
                    subtitle: voice.description != null
                        ? Text(
                            voice.description!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: colorScheme.primary)
                        : null,
                    selected: isSelected,
                    onTap: () {
                      ref.read(voiceListProvider.notifier).setDefaultVoice(voice.id);
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _showHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const HistoryListDialog(),
    );
  }

  void _showPrefetchCountDialog(BuildContext context, WidgetRef ref) {
    final currentCount = ref.read(settingsProvider).prefetchCount;
    final options = [3, 5, 8, 10, 12, 15, 20];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '预加载数量',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '设置播放时提前加载的段落数量（并发上限为 3）',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          ...options.map((count) => _PrefetchCountOption(
                count: count,
                isSelected: currentCount == count,
                onTap: () {
                  ref.read(settingsProvider.notifier).setPrefetchCount(count);
                  Navigator.of(context).pop();
                },
              )),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showThemeModeDialog(BuildContext context, WidgetRef ref) {
    final currentMode = ref.read(settingsProvider).themeMode;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '选择主题模式',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          _ThemeModeOption(
            icon: Icons.brightness_auto,
            title: '跟随系统',
            isSelected: currentMode == ThemeMode.system,
            onTap: () {
              ref.read(settingsProvider.notifier).setThemeMode(ThemeMode.system);
              Navigator.of(context).pop();
            },
          ),
          _ThemeModeOption(
            icon: Icons.light_mode,
            title: '浅色模式',
            isSelected: currentMode == ThemeMode.light,
            onTap: () {
              ref.read(settingsProvider.notifier).setThemeMode(ThemeMode.light);
              Navigator.of(context).pop();
            },
          ),
          _ThemeModeOption(
            icon: Icons.dark_mode,
            title: '深色模式',
            isSelected: currentMode == ThemeMode.dark,
            onTap: () {
              ref.read(settingsProvider.notifier).setThemeMode(ThemeMode.dark);
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showServerDialog(BuildContext context, WidgetRef ref) {
    final settings = ref.read(settingsProvider);
    final hostController = TextEditingController(text: settings.serverHost ?? '');
    final portController = TextEditingController(
      text: settings.serverPort?.toString() ?? '6060',
    );

    showDialog(
      context: context,
      builder: (context) {
        final dialogColorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: const Text('服务器设置'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: hostController,
                decoration: const InputDecoration(
                  labelText: '服务器地址',
                  hintText: '例如: 192.168.1.100',
                ),
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: portController,
                decoration: const InputDecoration(
                  labelText: '端口',
                  hintText: '默认 6060',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await ref.read(settingsProvider.notifier).clearServerConfig();
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: Text(
                '断开连接',
                style: TextStyle(color: dialogColorScheme.error),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final host = hostController.text.trim();
                final port = int.tryParse(portController.text.trim()) ?? 6060;
                if (host.isNotEmpty) {
                  await ref.read(settingsProvider.notifier).setServerConfig(host, port);
                }
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final dialogColorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [dialogColorScheme.primary, dialogColorScheme.tertiary],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_stories,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Text('Rovelcat'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '有声小说播放器',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '版本 1.0.0',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: dialogColorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                '基于 AI 语音合成技术，将你的小说变成有声读物。',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: dialogColorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}

class _ThemeModeOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeModeOption({
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isSelected
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        child: Icon(
          icon,
          color: isSelected
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(title),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: colorScheme.primary)
          : null,
      selected: isSelected,
      onTap: onTap,
    );
  }
}

class _PrefetchCountOption extends StatelessWidget {
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _PrefetchCountOption({
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isSelected
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        child: Text(
          '$count',
          style: TextStyle(
            color: isSelected
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      title: Text('$count 段'),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: colorScheme.primary)
          : null,
      selected: isSelected,
      onTap: onTap,
    );
  }
}
