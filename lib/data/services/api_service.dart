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
class ApiResponse<T> {
  final int errno;
  final String error;
  final T? data;

  ApiResponse({
    required this.errno,
    required this.error,
    this.data,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromData,
  ) {
    return ApiResponse(
      errno: json['errno'] as int,
      error: json['error'] as String,
      data: json['data'] != null && fromData != null
          ? fromData(json['data'])
          : null,
    );
  }

  bool get isSuccess => errno == 0;
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
      return Result.failure(apiResp.error);
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
      return Result.failure(apiResp.error);
    }
    return Result.success(apiResp.data!);
  }

  Future<Result<SegmentsResponse>> getSegments(
    String novelId, {
    int? start,
    int? limit,
  }) async {
    final response = await _dio.post('/novel/segments', data: {
      'novel_id': novelId,
      if (start != null) 'start': start,
      if (limit != null) 'limit': limit,
    });
    final apiResp = ApiResponse<SegmentsResponse>.fromJson(
      response.data,
      (data) => SegmentsResponse.fromJson(data as Map<String, dynamic>),
    );
    if (!apiResp.isSuccess) {
      return Result.failure(apiResp.error);
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
      return Result.failure(apiResp.error);
    }
    return Result.success(apiResp.data!);
  }

  Future<Result<void>> deleteNovel(String id) async {
    final response = await _dio.post('/novel/delete', data: {'id': id});
    final apiResp = ApiResponse.fromJson(response.data, null);
    if (!apiResp.isSuccess) {
      return Result.failure(apiResp.error);
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
      return Result.failure(apiResp.error);
    }
    return Result.success(apiResp.data ?? []);
  }

  Future<Result<Voice>> uploadVoice(
    String name,
    String? description,
    Uint8List fileBytes,
    String fileName,
  ) async {
    final formData = FormData.fromMap({
      'name': name,
      if (description != null) 'description': description,
      'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
    });
    final response = await _dio.post('/voice/upload', data: formData);
    final apiResp = ApiResponse<Voice>.fromJson(
      response.data,
      (data) => Voice.fromJson(data),
    );
    if (!apiResp.isSuccess) {
      return Result.failure(apiResp.error);
    }
    return Result.success(apiResp.data!);
  }

  Future<Result<void>> deleteVoice(String id) async {
    final response = await _dio.post('/voice/delete', data: {'id': id});
    final apiResp = ApiResponse.fromJson(response.data, null);
    if (!apiResp.isSuccess) {
      return Result.failure(apiResp.error);
    }
    return Result.success(null);
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
      return Result.failure(apiResp.error);
    }
    return Result.success(apiResp.data!);
  }

  Future<Result<int>> seek(String sessionId, int segmentIndex) async {
    final response = await _dio.post('/session/seek', data: {
      'session_id': sessionId,
      'segment_index': segmentIndex,
    });
    final apiResp = ApiResponse<int>.fromJson(
      response.data,
      (data) => (data as Map<String, dynamic>)['current_index'] as int,
    );
    if (!apiResp.isSuccess) {
      return Result.failure(apiResp.error);
    }
    return Result.success(apiResp.data!);
  }

  Future<Result<void>> changeVoice(String sessionId, String voiceId) async {
    final response = await _dio.post('/session/change_voice', data: {
      'session_id': sessionId,
      'voice_id': voiceId,
    });
    final apiResp = ApiResponse.fromJson(response.data, null);
    if (!apiResp.isSuccess) {
      return Result.failure(apiResp.error);
    }
    return Result.success(null);
  }

  Future<Result<void>> closeSession(String sessionId) async {
    final response = await _dio.post('/session/close', data: {
      'session_id': sessionId,
    });
    final apiResp = ApiResponse.fromJson(response.data, null);
    if (!apiResp.isSuccess) {
      return Result.failure(apiResp.error);
    }
    return Result.success(null);
  }

  // ========== Inference APIs ==========

  Future<Result<List<TaskInfo>>> submitInfer(
    String sessionId,
    List<int> segmentIndices,
  ) async {
    final response = await _dio.post('/infer/submit', data: {
      'session_id': sessionId,
      'segment_indices': segmentIndices,
    });
    final apiResp = ApiResponse<List<TaskInfo>>.fromJson(
      response.data,
      (data) => ((data as Map<String, dynamic>)['tasks'] as List)
          .map((e) => TaskInfo.fromJson(e))
          .toList(),
    );
    if (!apiResp.isSuccess) {
      return Result.failure(apiResp.error);
    }
    return Result.success(apiResp.data ?? []);
  }

  // ========== Audio API ==========

  Future<Uint8List?> getAudio(
    String novelId,
    int segmentIndex,
    String voiceId,
  ) async {
    final response = await _dio.post(
      '/audio',
      data: {
        'novel_id': novelId,
        'segment_index': segmentIndex,
        'voice_id': voiceId,
      },
      options: Options(responseType: ResponseType.bytes),
    );

    // 检查响应是否是 JSON（错误）还是二进制（音频）
    if (response.headers['content-type']?.first.contains('application/json') ??
        false) {
      return null;
    }

    return response.data as Uint8List;
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
      return Result.failure(apiResp.error);
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
      return Result.failure(apiResp.error);
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
      return Result.failure(apiResp.error);
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
      return Result.failure(apiResp.error);
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
      return Result.failure(apiResp.error);
    }
    return Result.success(apiResp.data!);
  }

  /// 取消批量任务
  Future<Result<BatchTask>> cancelBatchTask(String taskId) async {
    final response = await _dio.post('/batch/$taskId/cancel');
    final apiResp = ApiResponse<BatchTask>.fromJson(
      response.data,
      (data) => BatchTask.fromJson(data as Map<String, dynamic>),
    );
    if (!apiResp.isSuccess) {
      return Result.failure(apiResp.error);
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
