import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../novel/novel_page.dart';
import '../voice/voice_page.dart';
import '../settings/settings_page.dart';

/// 底部导航索引
final homeNavIndexProvider = StateProvider<int>((ref) => 0);

/// 主页面 - 底部导航架构
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navIndex = ref.watch(homeNavIndexProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: IndexedStack(
        index: navIndex,
        children: const [
          NovelPage(),
          VoicePage(),
          SettingsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navIndex,
        onDestinationSelected: (index) {
          ref.read(homeNavIndexProvider.notifier).state = index;
        },
        destinations: [
          NavigationDestination(
            icon: Icon(
              Icons.book_outlined,
              color: colorScheme.onSurfaceVariant,
            ),
            selectedIcon: Icon(
              Icons.book,
              color: colorScheme.onSecondaryContainer,
            ),
            label: '小说',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.record_voice_over_outlined,
              color: colorScheme.onSurfaceVariant,
            ),
            selectedIcon: Icon(
              Icons.record_voice_over,
              color: colorScheme.onSecondaryContainer,
            ),
            label: '音色',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.settings_outlined,
              color: colorScheme.onSurfaceVariant,
            ),
            selectedIcon: Icon(
              Icons.settings,
              color: colorScheme.onSecondaryContainer,
            ),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
