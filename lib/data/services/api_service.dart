import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/settings_provider.dart';
import '../models/novel.dart';
import '../models/voice.dart';
import '../models/segment.dart';
import '../models/play_session.dart';
import '../models/segment_task.dart';
import '../models/batch_task.dart';
import '../models/novel_brief.dart';

/// 结果类型：Either 的简化实现
class Result<T> {
  final T? _value;
  final String? _error;

  Result.success(T value) : _value = value, _error = null;
  Result.failure(String error) : _value = null, _error = error;

  R fold<R>(R Function(String error) onError, R Function(T value) onSuccess) {
    if (_error != null) {
      return onError(_error);
    }
    return onSuccess(_value as T);
  }
}

/// API 响应封装
/// 兼容两种服务端格式:
///   旧格式: { "errno": 0, "error": "", "data": T? }
///   新格式: { "success": bool, "data": T?, "error": String? }
class ApiResponse<T> {
  final bool success;
  final String? error;
  final T? data;

  ApiResponse({
    required this.success,
    this.error,
    this.data,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromData,
  ) {
    // 兼容 errno 和 success 两种协议
    final bool isOk;
    if (json.containsKey('errno')) {
      // 旧格式: errno == 0 表示成功
      isOk = (json['errno'] as int?) == 0;
    } else {
      // 新格式: success 布尔值
      isOk = json['success'] as bool? ?? false;
    }

    return ApiResponse(
      success: isOk,
      error: json['error'] as String?,
      data: json['data'] != null && fromData != null
          ? fromData(json['data'])
          : null,
    );
  }

  bool get isSuccess => success;
}

/// API 服务
class ApiService {
  Dio _dio;
  String _baseUrl;

  ApiService(String baseUrl)
      : _baseUrl = baseUrl,
        _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ));

  void updateBaseUrl(String baseUrl) {
    _baseUrl = baseUrl;
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
    ));
  }

  String get baseUrl => _baseUrl;

  /// 从 ApiResponse 提取错误信息
  String _errorMsg(ApiResponse resp) => resp.error ?? 'Unknown error';

  /// 测试服务器连接
  Future<Result<String>> testConnection() async {
    try {
      final response = await _dio.get('/ping');
      final data = response.data as Map<String, dynamic>;
      if (data['status'] == 'ok') {
        return Result.success(data['version'] as String? ?? 'unknown');
      }
      return Result.failure('Server status: ${data['status']}');
    } catch (e) {
      return Result.failure(e.toString());
    }
  }

  // ========== Novel APIs ==========

  Future<Result<List<Novel>>> listNovels() async {
    debugPrint('ApiService: listNovels()');
    final response = await _dio.get('/novel/list');
    final apiResp = ApiResponse<List<Novel>>.fromJson(
      response.data,
      (data) => (data as List).map((e) => Novel.fromJson(e)).toList(),
    );
    if (!apiResp.isSuccess) {
      return Result.failure(_errorMsg(apiResp));
    }
    return Result.success(apiResp.data ?? []);
  }

  Future<Result<Novel>> getNovel(String id) async {
    final response = await _dio.post('/novel/get', data: {'id': id});
    final apiResp = ApiResponse<Novel>.fromJson(
      response.data,
      (data) => Novel.fromJson(data),
    );
    if (!apiResp.isSuccess) {
      return Result.failure(_errorMsg(apiResp));
    }
    return Result.success(apiResp.data!);
  }

  /// 获取小说段落（utterances）
  Future<Result<SegmentsResponse>> getUtterances(
    String novelId, {
    int? start,
    int? limit,
  }) async {
    final response = await _dio.post('/novel/utterances', data: {
      'novel_id': novelId,
      if (start != null) 'start': start,
      if (limit != null) 'limit': limit,
    });
    final apiResp = ApiResponse<SegmentsResponse>.fromJson(
      response.data,
      (data) => SegmentsResponse.fromJson(data as Map<String, dynamic>),
    );
    if (!apiResp.isSuccess) {
      return Result.failure(_errorMsg(apiResp));
    }
    return Result.success(apiResp.data!);
  }

  /// 获取小说段落（兼容旧接口名）
  Future<Result<SegmentsResponse>> getSegments(
    String novelId, {
    int? start,
    int? limit,
  }) => getUtterances(novelId, start: start, limit: limit);

  /// 获取小说概要（含 speakers、解析状态等）
  Future<Result<NovelBrief>> getNovelBrief(String novelId) async {
    final response = await _dio.post('/novel/brief', data: {
      'novel_id': novelId,
    });
    final apiResp = ApiResponse<NovelBrief>.fromJson(
      response.data,
      (data) => NovelBrief.fromJson(data as Map<String, dynamic>),
    );
    if (!apiResp.isSuccess) {
      return Result.failure(_errorMsg(apiResp));
    }
    return Result.success(apiResp.data!);
  }

  Future<Result<Novel>> uploadNovel(
    String title,
    Uint8List fileBytes,
    String fileName,
  ) async {
    final formData = FormData.fromMap({
      'title': title,
      'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
    });
    final response = await _dio.post('/novel/upload', data: formData);
    final apiResp = ApiResponse<Novel>.fromJson(
      response.data,
      (data) => Novel.fromJson(data),
    );
    if (!apiResp.isSuccess) {
      return Result.failure(_errorMsg(apiResp));
    }
    return Result.success(apiResp.data!);
  }

  Future<Result<void>> deleteNovel(String id) async {
    final response = await _dio.post('/novel/delete', data: {'id': id});
    final apiResp = ApiResponse.fromJson(response.data, null);
    if (!apiResp.isSuccess) {
      return Result.failure(_errorMsg(apiResp));
    }
    return Result.success(null);
  }

  // ========== Voice APIs ==========

  Future<Result<List<Voice>>> listVoices() async {
    debugPrint('ApiService: listVoices()');
    final response = await _dio.get('/voice/list');
    final apiResp = ApiResponse<List<Voice>>.fromJson(
      response.data,
      (data) => (data as List).map((e) => Voice.fromJson(e)).toList(),
    );
    if (!apiResp.isSuccess) {
      return Result.failure(_errorMsg(apiResp));
    }
    return Result.success(apiResp.data ?? []);
  }

  /// 获取单个音色详情
  Future<Result<Voice>> getVoice(String id) async {
    final response = await _dio.post('/voice/get', data: {'id': id});
    final apiResp = ApiResponse<Voice>.fromJson(
      response.data,
      (data) => Voice.fromJson(data),
    );
    if (!apiResp.isSuccess) {
      return Result.failure(_errorMsg(apiResp));
    }
    return Result.success(apiResp.data!);
  }

  Future<Result<Voice>> uploadVoice(
    String name,
    String? description,
    Uint8List fileBytes,
    String fileName, {
    String? refText,
    String? gender,
    String? ageGroup,
    List<String>? tags,
  }) async {
    final formData = FormData.fromMap({
      'name': name,
      if (description != null) 'description': description,
      if (refText != null) 'ref_text': refText,
      if (gender != null && gender != 'unknown') 'gender': gender,
      if (ageGroup != null && ageGroup != 'unknown') 'age_group': ageGroup,
      if (tags != null && tags.isNotEmpty) 'tags': tags.join(','),
      'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
    });
    final response = await _dio.post('/voice/upload', data: formData);
    final apiResp = ApiResponse<Voice>.fromJson(
      response.data,
      (data) => Voice.fromJson(data),
    );
    if (!apiResp.isSuccess) {
      return Result.failure(_errorMsg(apiResp));
    }
    return Result.success(apiResp.data!);
  }

  Future<Result<void>> deleteVoice(String id) async {
    final response = await _dio.post('/voice/delete', data: {'id': id});
    final apiResp = ApiResponse.fromJson(response.data, null);
    if (!apiResp.isSuccess) {
      return Result.failure(_errorMsg(apiResp));
    }
    return Result.success(null);
  }

  /// 获取音色标签选项
  Future<Result<Map<String, dynamic>>> getVoiceTagOptions() async {
    final response = await _dio.get('/voice/tags/options');
    final apiResp = ApiResponse<Map<String, dynamic>>.fromJson(
      response.data,
      (data) => data as Map<String, dynamic>,
    );
    if (!apiResp.isSuccess) {
      return Result.failure(_errorMsg(apiResp));
    }
    return Result.success(apiResp.data!);
  }

  /// 下载音色参考音频
  Future<Uint8List?> getVoiceAudio(String voiceId) async {
    try {
      final response = await _dio.get(
        '/voice/audio/$voiceId',
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data as Uint8List;
    } catch (e) {
      debugPrint('getVoiceAudio error: $e');
      return null;
    }
  }

  // ========== Session APIs ==========

  Future<Result<PlaySession>> createSession(
    String novelId,
    String voiceId,
    int startIndex,
  ) async {
    final response = await _dio.post('/session/play', data: {
      'novel_id': novelId,
      'voice_id': voiceId,
      'start_index': startIndex,
    });
    final apiResp = ApiResponse<PlaySession>.fromJson(
      response.data,
      (data) => PlaySession.fromJson(data),
    );
    if (!apiResp.isSuccess) {
      return Result.failure(_errorMsg(apiResp));
    }
    return Result.success(apiResp.data!);
  }

  Future<Result<int>> seek(String sessionId, int segmentIndex) async {
    debugPrint('ApiService.seek(): session_id=$sessionId, segment_index=$segmentIndex');
    try {
      final response = await _dio.post('/session/seek', data: {
        'session_id': sessionId,
        'segment_index': segmentIndex,
      });
      debugPrint('ApiService.seek() response: ${response.data}');
      final apiResp = ApiResponse<int>.fromJson(
        response.data,
        (data) => (data as Map<String, dynamic>)['current_index'] as int,
      );
      if (!apiResp.isSuccess) {
        debugPrint('ApiService.seek() failed: ${apiResp.error}');
        return Result.failure(_errorMsg(apiResp));
      }
      debugPrint('ApiService.seek() success: current_index=${apiResp.data}');
      return Result.success(apiResp.data!);
    } catch (e) {
      debugPrint('ApiService.seek() exception: $e');
      return Result.failure(e.toString());
    }
  }

  Future<Result<void>> changeVoice(String sessionId, String voiceId) async {
    final response = await _dio.post('/session/change_voice', data: {
      'session_id': sessionId,
      'voice_id': voiceId,
    });
    final apiResp = ApiResponse.fromJson(response.data, null);
    if (!apiResp.isSuccess) {
      return Result.failure(_errorMsg(apiResp));
    }
    return Result.success(null);
  }

  Future<Result<void>> closeSession(String sessionId) async {
    final response = await _dio.post('/session/close', data: {
      'session_id': sessionId,
    });
    final apiResp = ApiResponse.fromJson(response.data, null);
    if (!apiResp.isSuccess) {
      return Result.failure(_errorMsg(apiResp));
    }
    return Result.success(null);
  }

  // ========== Inference APIs ==========

  /// 提交即时推理任务
  /// 新接口: {texts: [...], voice_id: "..."}
  Future<Result<List<TaskInfo>>> submitInfer(
    List<String> texts,
    String voiceId,
  ) async {
    final response = await _dio.post('/infer/submit', data: {
      'texts': texts,
      'voice_id': voiceId,
    });
    final apiResp = ApiResponse<List<TaskInfo>>.fromJson(
      response.data,
      (data) {
        if (data is List) {
          return data.map((e) => TaskInfo.fromJson(e)).toList();
        }
        final map = data as Map<String, dynamic>;
        if (map.containsKey('tasks')) {
          return (map['tasks'] as List).map((e) => TaskInfo.fromJson(e)).toList();
        }
        return <TaskInfo>[];
      },
    );
    if (!apiResp.isSuccess) {
      return Result.failure(_errorMsg(apiResp));
    }
    return Result.success(apiResp.data ?? []);
  }

  /// 查询推理任务状态
  Future<Result<List<TaskInfo>>> getInferStatus(List<String> taskIds) async {
    final response = await _dio.post('/infer/status', data: {
      'task_ids': taskIds,
    });
    final apiResp = ApiResponse<List<TaskInfo>>.fromJson(
      response.data,
      (data) {
        if (data is List) {
          return data.map((e) => TaskInfo.fromJson(e)).toList();
        }
        final map = data as Map<String, dynamic>;
        if (map.containsKey('tasks')) {
          return (map['tasks'] as List).map((e) => TaskInfo.fromJson(e)).toList();
        }
        return <TaskInfo>[];
      },
    );
    if (!apiResp.isSuccess) {
      return Result.failure(_errorMsg(apiResp));
    }
    return Result.success(apiResp.data ?? []);
  }

  // ========== Audio API ==========

  /// 通过 cache key 获取音频
  Future<Uint8List?> getAudio(Map<String, dynamic> params) async {
    final response = await _dio.post(
      '/audio',
      data: params,
      options: Options(responseType: ResponseType.bytes),
    );

    // 检查响应是否是 JSON（错误）还是二进制（音频）
    if (response.headers['content-type']?.first.contains('application/json') ??
        false) {
      return null;
    }

    return response.data as Uint8List;
  }

  /// 便捷方法：通过 novel_id + segment_index + voice_id 获取音频
  Future<Uint8List?> getSegmentAudio(
    String novelId,
    int segmentIndex,
    String voiceId,
  ) async {
    return getAudio({
      'novel_id': novelId,
      'segment_index': segmentIndex,
      'voice_id': voiceId,
    });
  }

  // ========== Character APIs ==========

  /// 获取小说角色列表
  Future<Result<List<Map<String, dynamic>>>> listCharacters(String novelId) async {
    final response = await _dio.post('/character/list', data: {
      'novel_id': novelId,
    });
    final apiResp = ApiResponse<List<Map<String, dynamic>>>.fromJson(
      response.data,
      (data) => (data as List).map((e) => e as Map<String, dynamic>).toList(),
    );
    if (!apiResp.isSuccess) {
      return Result.failure(_errorMsg(apiResp));
    }
    return Result.success(apiResp.data ?? []);
  }

  /// 获取单个角色详情
  Future<Result<Map<String, dynamic>>> getCharacter(String characterId) async {
    final response = await _dio.post('/character/get', data: {
      'character_id': characterId,
    });
    final apiResp = ApiResponse<Map<String, dynamic>>.fromJson(
      response.data,
      (data) => data as Map<String, dynamic>,
    );
    if (!apiResp.isSuccess) {
      return Result.failure(_errorMsg(apiResp));
    }
    return Result.success(apiResp.data!);
  }

  /// 合并角色
  Future<Result<void>> mergeCharacters(Map<String, dynamic> params) async {
    final response = await _dio.post('/character/merge', data: params);
    final apiResp = ApiResponse.fromJson(response.data, null);
    if (!apiResp.isSuccess) {
      return Result.failure(_errorMsg(apiResp));
    }
    return Result.success(null);
  }

  /// 按角色 ID 绑定音色
  Future<Result<void>> assignVoiceToCharacter(String characterId, String voiceId) async {
    final response = await _dio.post('/character/assign-voice', data: {
      'character_id': characterId,
      'voice_id': voiceId,
    });
    final apiResp = ApiResponse.fromJson(response.data, null);
    if (!apiResp.isSuccess) {
      return Result.failure(_errorMsg(apiResp));
    }
    return Result.success(null);
  }

  /// 按 speaker 名称绑定音色
  Future<Result<void>> assignSpeakerVoice(
    String novelId,
    String speakerName,
    String voiceId,
  ) async {
    final response = await _dio.post('/character/assign-speaker-voice', data: {
      'novel_id': novelId,
      'speaker_name': speakerName,
      'voice_id': voiceId,
    });
    final apiResp = ApiResponse.fromJson(response.data, null);
    if (!apiResp.isSuccess) {
      return Result.failure(_errorMsg(apiResp));
    }
    return Result.success(null);
  }

  /// 更新角色重要性
  Future<Result<void>> updateCharacterImportance(Map<String, dynamic> params) async {
    final response = await _dio.post('/character/update-importance', data: params);
    final apiResp = ApiResponse.fromJson(response.data, null);
    if (!apiResp.isSuccess) {
      return Result.failure(_errorMsg(apiResp));
    }
    return Result.success(null);
  }

  // ========== Worker APIs ==========

  /// 启动解析 worker
  Future<Result<void>> startWorker(Map<String, dynamic> params) async {
    final response = await _dio.post('/worker/start', data: params);
    final apiResp = ApiResponse.fromJson(response.data, null);
    if (!apiResp.isSuccess) {
      return Result.failure(_errorMsg(apiResp));
    }
    return Result.success(null);
  }

  /// 暂停 worker
  Future<Result<void>> pauseWorker(Map<String, dynamic> params) async {
    final response = await _dio.post('/worker/pause', data: params);
    final apiResp = ApiResponse.fromJson(response.data, null);
    if (!apiResp.isSuccess) {
      return Result.failure(_errorMsg(apiResp));
    }
    return Result.success(null);
  }

  /// 恢复 worker
  Future<Result<void>> resumeWorker(Map<String, dynamic> params) async {
    final response = await _dio.post('/worker/resume', data: params);
    final apiResp = ApiResponse.fromJson(response.data, null);
    if (!apiResp.isSuccess) {
      return Result.failure(_errorMsg(apiResp));
    }
    return Result.success(null);
  }

  /// 获取 worker 状态
  Future<Result<Map<String, dynamic>>> getWorkerStatus(String novelId) async {
    final response = await _dio.post('/worker/status', data: {
      'novel_id': novelId,
    });
    final apiResp = ApiResponse<Map<String, dynamic>>.fromJson(
      response.data,
      (data) => data as Map<String, dynamic>,
    );
    if (!apiResp.isSuccess) {
      return Result.failure(_errorMsg(apiResp));
    }
    return Result.success(apiResp.data!);
  }

  // ========== Batch Task APIs ==========

  /// 创建批量推理任务
  Future<Result<BatchTask>> createBatchTask(
    String novelId,
    String voiceId, {
    int segmentStart = 0,
    int? segmentEnd,
  }) async {
    final response = await _dio.post('/batch', data: {
      'novel_id': novelId,
      'voice_id': voiceId,
      'segment_start': segmentStart,
      if (segmentEnd != null) 'segment_end': segmentEnd,
    });
    final apiResp = ApiResponse<BatchTask>.fromJson(
      response.data,
      (data) => BatchTask.fromJson(data as Map<String, dynamic>),
    );
    if (!apiResp.isSuccess) {
      return Result.failure(_errorMsg(apiResp));
    }
    return Result.success(apiResp.data!);
  }

  /// 获取所有批量任务列表
  Future<Result<List<BatchTask>>> listBatchTasks() async {
    final response = await _dio.get('/batch');
    final apiResp = ApiResponse<List<BatchTask>>.fromJson(
      response.data,
      (data) =>
          (data as List).map((e) => BatchTask.fromJson(e as Map<String, dynamic>)).toList(),
    );
    if (!apiResp.isSuccess) {
      return Result.failure(_errorMsg(apiResp));
    }
    return Result.success(apiResp.data ?? []);
  }

  /// 获取单个批量任务状态
  Future<Result<BatchTask>> getBatchTask(String taskId) async {
    final response = await _dio.get('/batch/$taskId');
    final apiResp = ApiResponse<BatchTask>.fromJson(
      response.data,
      (data) => BatchTask.fromJson(data as Map<String, dynamic>),
    );
    if (!apiResp.isSuccess) {
      return Result.failure(_errorMsg(apiResp));
    }
    return Result.success(apiResp.data!);
  }

  /// 暂停批量任务
  Future<Result<BatchTask>> pauseBatchTask(String taskId) async {
    final response = await _dio.post('/batch/$taskId/pause');
    final apiResp = ApiResponse<BatchTask>.fromJson(
      response.data,
      (data) => BatchTask.fromJson(data as Map<String, dynamic>),
    );
    if (!apiResp.isSuccess) {
      return Result.failure(_errorMsg(apiResp));
    }
    return Result.success(apiResp.data!);
  }

  /// 恢复批量任务
  Future<Result<BatchTask>> resumeBatchTask(String taskId) async {
    final response = await _dio.post('/batch/$taskId/resume');
    final apiResp = ApiResponse<BatchTask>.fromJson(
      response.data,
      (data) => BatchTask.fromJson(data as Map<String, dynamic>),
    );
    if (!apiResp.isSuccess) {
      return Result.failure(_errorMsg(apiResp));
    }
    return Result.success(apiResp.data!);
  }

  /// 取消批量任务 (支持 Pending/Running/Paused/Failed → Cancelled)
  Future<Result<BatchTask>> cancelBatchTask(String taskId) async {
    final response = await _dio.post('/batch/$taskId/cancel');
    final apiResp = ApiResponse<BatchTask>.fromJson(
      response.data,
      (data) => BatchTask.fromJson(data as Map<String, dynamic>),
    );
    if (!apiResp.isSuccess) {
      return Result.failure(_errorMsg(apiResp));
    }
    return Result.success(apiResp.data!);
  }

  /// 重试失败的批量任务 (仅从 Failed → Running)
  Future<Result<BatchTask>> retryBatchTask(String taskId) async {
    final response = await _dio.post('/batch/$taskId/retry');
    final apiResp = ApiResponse<BatchTask>.fromJson(
      response.data,
      (data) => BatchTask.fromJson(data as Map<String, dynamic>),
    );
    if (!apiResp.isSuccess) {
      return Result.failure(_errorMsg(apiResp));
    }
    return Result.success(apiResp.data!);
  }
}

/// API 服务 Provider
final apiServiceProvider = Provider<ApiService>((ref) {
  final settings = ref.watch(settingsProvider);
  final baseUrl = settings.isServerConfigured 
      ? settings.apiBaseUrl 
      : 'http://localhost:6060/api';
  return ApiService(baseUrl);
});

/// WebSocket Base URL Provider
final wsBaseUrlProvider = Provider<String>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.isServerConfigured 
      ? settings.wsBaseUrl 
      : 'ws://localhost:6060/ws';
});
