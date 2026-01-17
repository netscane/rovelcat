import 'package:flutter/material.dart';
import '../../../data/models/voice.dart';

/// 音色卡片组件
class VoiceCard extends StatelessWidget {
  final Voice voice;
  final bool isDefault;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const VoiceCard({
    super.key,
    required this.voice,
    required this.isDefault,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: isDefault ? 2 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDefault
                ? colorScheme.primary
                : colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: isDefault ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onDelete,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 音色封面
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _getGradientColors(voice.name, colorScheme),
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.mic,
                        size: 28,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      Text(
                        voice.name.isNotEmpty ? voice.name[0].toUpperCase() : 'V',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // 音色信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              voice.name,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isDefault)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 14,
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '默认',
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: colorScheme.onPrimaryContainer,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      if (voice.description != null && voice.description!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          voice.description!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      // 操作提示
                      Text(
                        isDefault ? '当前默认音色' : '点击设为默认',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: isDefault
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 操作菜单
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'default',
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 20,
                            color: colorScheme.onSurface,
                          ),
                          const SizedBox(width: 12),
                          const Text('设为默认'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: colorScheme.error,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '删除',
                            style: TextStyle(color: colorScheme.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'default') {
                      onTap();
                    } else if (value == 'delete' && onDelete != null) {
                      onDelete!();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Color> _getGradientColors(String name, ColorScheme colorScheme) {
    // 根据名字生成不同的渐变色
    final hash = name.hashCode;
    final hue = (hash % 360).abs().toDouble();
    
    return [
      HSLColor.fromAHSL(1.0, hue, 0.6, 0.5).toColor(),
      HSLColor.fromAHSL(1.0, (hue + 30) % 360, 0.7, 0.4).toColor(),
    ];
  }
}
