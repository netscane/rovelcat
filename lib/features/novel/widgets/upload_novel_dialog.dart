import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../data/services/api_service.dart';
import '../../../data/models/novel.dart';
import '../../../core/providers/novel_provider.dart';

/// 上传小说对话框
class UploadNovelDialog extends ConsumerStatefulWidget {
  const UploadNovelDialog({super.key});

  @override
  ConsumerState<UploadNovelDialog> createState() => _UploadNovelDialogState();
}

class _UploadNovelDialogState extends ConsumerState<UploadNovelDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  
  Uint8List? _fileBytes;
  String? _fileName;
  bool _isUploading = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _fileBytes = result.files.single.bytes;
        _fileName = result.files.single.name;
        // 自动填充标题（去除扩展名）
        if (_titleController.text.isEmpty) {
          final nameWithoutExt = _fileName!.replaceAll(RegExp(r'\.txt$'), '');
          _titleController.text = nameWithoutExt;
        }
      });
    }
  }

  Future<void> _upload() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fileBytes == null || _fileName == null) {
      setState(() => _error = '请选择文件');
      return;
    }

    setState(() {
      _isUploading = true;
      _error = null;
    });

    final api = ref.read(apiServiceProvider);
    final result = await api.uploadNovel(
      _titleController.text.trim(),
      _fileBytes!,
      _fileName!,
    );

    result.fold(
      (error) {
        setState(() {
          _isUploading = false;
          _error = error;
        });
      },
      (Novel novel) {
        ref.read(novelListProvider.notifier).addNovel(novel);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('《${novel.title}》上传成功，正在处理中...')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 标题
                Text(
                  '添加小说',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 24),

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
                          _fileName != null ? Icons.description : Icons.upload_file,
                          size: 48,
                          color: _fileName != null
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _fileName ?? '点击选择 TXT 文件',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: _fileName != null
                                    ? colorScheme.onSurface
                                    : colorScheme.onSurfaceVariant,
                              ),
                          textAlign: TextAlign.center,
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
                const SizedBox(height: 16),

                // 标题输入
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: '小说标题',
                    hintText: '请输入小说标题',
                  ),
                  enabled: !_isUploading,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请输入标题';
                    }
                    return null;
                  },
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
                      onPressed: _isUploading ? null : () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
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
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
