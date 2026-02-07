import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/services/api_service.dart';
import '../../data/models/voice.dart';
import '../../core/providers/voice_provider.dart';

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

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _refTextController.dispose();
    super.dispose();
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
}
