import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/batch_task_provider.dart';
import '../../../core/providers/voice_provider.dart';
import '../../../data/models/novel.dart';
import '../../../data/models/voice.dart';

/// 批量预热配置对话框
class BatchPreheatDialog extends ConsumerStatefulWidget {
  final Novel novel;

  const BatchPreheatDialog({super.key, required this.novel});

  @override
  ConsumerState<BatchPreheatDialog> createState() => _BatchPreheatDialogState();
}

class _BatchPreheatDialogState extends ConsumerState<BatchPreheatDialog> {
  Voice? _selectedVoice;
  late RangeValues _segmentRange;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _segmentRange = RangeValues(0, (widget.novel.totalSegments - 1).toDouble());
  }

  int get _segmentStart => _segmentRange.start.round();
  int get _segmentEnd => _segmentRange.end.round();
  int get _totalSelected => _segmentEnd - _segmentStart + 1;

  Future<void> _submit() async {
    if (_selectedVoice == null) {
      setState(() => _error = '请选择音色');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final error = await ref.read(batchTaskListProvider.notifier).createTask(
      widget.novel.id,
      _selectedVoice!.id,
      segmentStart: _segmentStart,
      segmentEnd: _segmentEnd,
    );

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _isSubmitting = false;
        _error = error;
      });
    } else {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('批量预热任务已创建')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final voiceState = ref.watch(voiceListProvider);

    // 设置默认选中的音色
    if (_selectedVoice == null && voiceState.voices.isNotEmpty) {
      _selectedVoice = voiceState.defaultVoice ?? voiceState.voices.first;
    }

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 标题
              Text(
                '批量预热',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '《${widget.novel.title}》',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),

              // 音色选择
              Text(
                '选择音色',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 8),
              if (voiceState.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (voiceState.voices.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '暂无可用音色，请先添加音色',
                    style: TextStyle(color: colorScheme.error),
                  ),
                )
              else
                DropdownButtonFormField<Voice>(
                  initialValue: _selectedVoice,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: voiceState.voices.map((voice) {
                    return DropdownMenuItem(
                      value: voice,
                      child: Text(voice.name),
                    );
                  }).toList(),
                  onChanged: _isSubmitting
                      ? null
                      : (voice) => setState(() => _selectedVoice = voice),
                ),
              const SizedBox(height: 24),

              // 段落范围选择
              Text(
                '段落范围',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '第 ${_segmentStart + 1} 段',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          '第 ${_segmentEnd + 1} 段',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    RangeSlider(
                      values: _segmentRange,
                      min: 0,
                      max: (widget.novel.totalSegments - 1).toDouble(),
                      divisions: widget.novel.totalSegments > 1
                          ? widget.novel.totalSegments - 1
                          : 1,
                      onChanged: _isSubmitting
                          ? null
                          : (values) => setState(() => _segmentRange = values),
                    ),
                    Text(
                      '共 $_totalSelected 段（总计 ${widget.novel.totalSegments} 段）',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 错误提示
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: colorScheme.onErrorContainer,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onErrorContainer,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // 操作按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _isSubmitting ? null : () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _isSubmitting || voiceState.voices.isEmpty
                        ? null
                        : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('开始预热'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
