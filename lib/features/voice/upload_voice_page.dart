import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/services/api_service.dart';
import '../../data/models/voice.dart';
import '../../core/providers/voice_provider.dart';

/// 标签选项数据
class _TagOption {
  final String value;
  final String label;

  const _TagOption({required this.value, required this.label});
}

/// 上传音色页面
class UploadVoicePage extends ConsumerStatefulWidget {
  const UploadVoicePage({super.key});

  @override
  ConsumerState<UploadVoicePage> createState() => _UploadVoicePageState();
}

class _UploadVoicePageState extends ConsumerState<UploadVoicePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _refTextController = TextEditingController();

  Uint8List? _fileBytes;
  String? _fileName;
  bool _isUploading = false;
  String? _error;

  // 标签相关状态
  String _selectedGender = 'unknown';
  String _selectedAgeGroup = 'unknown';
  final Set<String> _selectedTags = {};
  bool _isLoadingTags = true;
  int _maxTags = 20;

  // 标签选项（从服务器加载）
  List<_TagOption> _genderOptions = const [
    _TagOption(value: 'unknown', label: '未知'),
    _TagOption(value: 'male', label: '男'),
    _TagOption(value: 'female', label: '女'),
  ];
  List<_TagOption> _ageGroupOptions = const [
    _TagOption(value: 'unknown', label: '未知'),
    _TagOption(value: 'child', label: '儿童'),
    _TagOption(value: 'young', label: '青年'),
    _TagOption(value: 'middle', label: '中年'),
    _TagOption(value: 'elder', label: '老年'),
  ];
  // Available tags from server (e.g., ["male", "female", "young", "old", ...])
  List<String> _availableTags = [];

  @override
  void initState() {
    super.initState();
    _loadTagOptions();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _refTextController.dispose();
    super.dispose();
  }

  /// 从服务器加载标签选项
  Future<void> _loadTagOptions() async {
    final api = ref.read(apiServiceProvider);
    final result = await api.getVoiceTagOptions();
    if (!mounted) return;

    result.fold(
      (error) {
        debugPrint('Failed to load tag options: $error');
        setState(() => _isLoadingTags = false);
      },
      (tagList) {
        setState(() {
          _availableTags = tagList;
          _isLoadingTags = false;
        });
      },
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav', 'mp3', 'flac', 'ogg'],
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _fileBytes = result.files.single.bytes;
        _fileName = result.files.single.name;
        // 自动填充名称
        if (_nameController.text.isEmpty) {
          final nameWithoutExt =
              _fileName!.replaceAll(RegExp(r'\.(wav|mp3|flac|ogg)$'), '');
          _nameController.text = nameWithoutExt;
        }
      });
    }
  }

  Future<void> _upload() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fileBytes == null || _fileName == null) {
      setState(() => _error = '请选择音频文件');
      return;
    }

    setState(() {
      _isUploading = true;
      _error = null;
    });

    final api = ref.read(apiServiceProvider);
    final result = await api.uploadVoice(
      _nameController.text.trim(),
      _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      _fileBytes!,
      _fileName!,
      refText: _refTextController.text.trim().isEmpty
          ? null
          : _refTextController.text.trim(),
      gender: _selectedGender,
      ageGroup: _selectedAgeGroup,
      tags: _selectedTags.toList(),
    );

    result.fold(
      (error) {
        setState(() {
          _isUploading = false;
          _error = error;
        });
      },
      (Voice voice) {
        ref.read(voiceListProvider.notifier).addVoice(voice);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('音色「${voice.name}」添加成功')),
        );
      },
    );
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else if (_selectedTags.length < _maxTags) {
        _selectedTags.add(tag);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '添加音色',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _isUploading ? null : _upload,
              child: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('上传'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 文件选择
            InkWell(
              onTap: _isUploading ? null : _pickFile,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outlineVariant,
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _fileName != null ? Icons.audio_file : Icons.upload_file,
                      size: 48,
                      color: _fileName != null
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _fileName ?? '点击选择音频文件',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _fileName != null
                                ? colorScheme.onSurface
                                : colorScheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '支持 WAV、MP3、FLAC、OGG 格式',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                    ),
                    if (_fileBytes != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${(_fileBytes!.length / 1024).toStringAsFixed(1)} KB',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 名称输入
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '音色名称',
                hintText: '请输入音色名称',
                border: OutlineInputBorder(),
              ),
              enabled: !_isUploading,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入名称';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 描述输入（可选）
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: '描述（可选）',
                hintText: '描述一下这个音色的特点',
                border: OutlineInputBorder(),
              ),
              enabled: !_isUploading,
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // 参考文本输入（可选）
            TextFormField(
              controller: _refTextController,
              decoration: const InputDecoration(
                labelText: '参考文本（可选）',
                hintText: '音频对应的文本内容，用于语音克隆',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              enabled: !_isUploading,
              maxLines: 5,
              minLines: 3,
            ),
            const SizedBox(height: 24),

            // ========== 音色标签区域 ==========
            _buildSectionHeader(context, '音色标签', Icons.label_outline),
            const SizedBox(height: 12),

            if (_isLoadingTags)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else ...[
              // 性别选择
              _buildOptionRow(
                context,
                label: '性别',
                icon: Icons.person_outline,
                options: _genderOptions,
                selectedValue: _selectedGender,
                onChanged: _isUploading
                    ? null
                    : (value) => setState(() => _selectedGender = value),
              ),
              const SizedBox(height: 12),

              // 年龄段选择
              _buildOptionRow(
                context,
                label: '年龄段',
                icon: Icons.cake_outlined,
                options: _ageGroupOptions,
                selectedValue: _selectedAgeGroup,
                onChanged: _isUploading
                    ? null
                    : (value) => setState(() => _selectedAgeGroup = value),
              ),
              const SizedBox(height: 16),

              // 可用标签列表
              if (_availableTags.isNotEmpty) ...[
                Text(
                  '标签（多选）',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _availableTags.map((tag) {
                    final isSelected = _selectedTags.contains(tag);
                    final isDisabled =
                        !isSelected && _selectedTags.length >= _maxTags;

                    return FilterChip(
                      label: Text(tag),
                      selected: isSelected,
                      onSelected: (_isUploading || isDisabled)
                          ? null
                          : (_) => _toggleTag(tag),
                      labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isSelected
                                ? colorScheme.onPrimaryContainer
                                : isDisabled
                                    ? colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
                                    : colorScheme.onSurfaceVariant,
                            fontWeight: isSelected ? FontWeight.w600 : null,
                          ),
                      selectedColor: colorScheme.primaryContainer,
                      backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      checkmarkColor: colorScheme.onPrimaryContainer,
                      side: BorderSide(
                        color: isSelected
                            ? colorScheme.primary.withValues(alpha: 0.5)
                            : colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    );
                  }).toList(),
                ),

                // 已选标签计数
                if (_selectedTags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '已选 ${_selectedTags.length} / $_maxTags 个标签',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
              ],
            ],

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

            // 底部留白，确保键盘弹出时有足够空间
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  /// 构建区域标题
  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
        ),
      ],
    );
  }

  /// 构建单选行（性别、年龄段）
  Widget _buildOptionRow(
    BuildContext context, {
    required String label,
    required IconData icon,
    required List<_TagOption> options,
    required String selectedValue,
    required void Function(String)? onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 72,
          child: Row(
            children: [
              Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: options.map((option) {
              final isSelected = option.value == selectedValue;
              return ChoiceChip(
                label: Text(option.label),
                selected: isSelected,
                onSelected: onChanged == null
                    ? null
                    : (_) => onChanged(option.value),
                labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isSelected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                      fontWeight: isSelected ? FontWeight.w600 : null,
                    ),
                selectedColor: colorScheme.primaryContainer,
                backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                side: BorderSide(
                  color: isSelected
                      ? colorScheme.primary.withValues(alpha: 0.5)
                      : colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
