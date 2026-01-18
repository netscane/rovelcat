import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/providers/settings_provider.dart';
import 'api_service.dart';

/// WebSocket 连接状态
enum WsConnectionState { disconnected, connecting, connected, reconnecting }

/// WebSocket 事件基类
abstract class WsEvent {}

/// 任务状态变更事件
class TaskStateChangedEvent extends WsEvent {
  final String sessionId;
  final String taskId;
  final int segmentIndex;
  final String state;
  final int? durationMs;
  final String? error;

  TaskStateChangedEvent({
    required this.sessionId,
    required this.taskId,
    required this.segmentIndex,
    required this.state,
    this.durationMs,
    this.error,
  });

  factory TaskStateChangedEvent.fromJson(Map<String, dynamic> json) {
    return TaskStateChangedEvent(
      sessionId: json['session_id'] as String,
      taskId: json['task_id'] as String,
      segmentIndex: json['segment_index'] as int,
      state: json['state'] as String,
      durationMs: json['duration_ms'] as int?,
      error: json['error'] as String?,
    );
  }
}

/// 会话关闭事件
class SessionClosedEvent extends WsEvent {
  final String sessionId;
  final String reason;

  SessionClosedEvent({required this.sessionId, required this.reason});

  factory SessionClosedEvent.fromJson(Map<String, dynamic> json) {
    return SessionClosedEvent(
      sessionId: json['session_id'] as String,
      reason: json['reason'] as String,
    );
  }
}

/// 小说准备就绪事件
class NovelReadyEvent extends WsEvent {
  final String novelId;
  final String title;
  final int totalSegments;

  NovelReadyEvent({
    required this.novelId,
    required this.title,
    required this.totalSegments,
  });

  factory NovelReadyEvent.fromJson(Map<String, dynamic> json) {
    return NovelReadyEvent(
      novelId: json['novel_id'] as String,
      title: json['title'] as String,
      totalSegments: json['total_segments'] as int,
    );
  }
}

/// 小说处理失败事件
class NovelFailedEvent extends WsEvent {
  final String novelId;
  final String error;

  NovelFailedEvent({required this.novelId, required this.error});

  factory NovelFailedEvent.fromJson(Map<String, dynamic> json) {
    return NovelFailedEvent(
      novelId: json['novel_id'] as String,
      error: json['error'] as String,
    );
  }
}

/// 小说删除中事件
class NovelDeletingEvent extends WsEvent {
  final String novelId;

  NovelDeletingEvent({required this.novelId});

  factory NovelDeletingEvent.fromJson(Map<String, dynamic> json) {
    return NovelDeletingEvent(novelId: json['novel_id'] as String);
  }
}

/// 小说已删除事件
class NovelDeletedEvent extends WsEvent {
  final String novelId;

  NovelDeletedEvent({required this.novelId});

  factory NovelDeletedEvent.fromJson(Map<String, dynamic> json) {
    return NovelDeletedEvent(novelId: json['novel_id'] as String);
  }
}

/// 小说删除失败事件
class NovelDeleteFailedEvent extends WsEvent {
  final String novelId;
  final String error;

  NovelDeleteFailedEvent({required this.novelId, required this.error});

  factory NovelDeleteFailedEvent.fromJson(Map<String, dynamic> json) {
    return NovelDeleteFailedEvent(
      novelId: json['novel_id'] as String,
      error: json['error'] as String,
    );
  }
}

/// 音色已删除事件
class VoiceDeletedEvent extends WsEvent {
  final String voiceId;

  VoiceDeletedEvent({required this.voiceId});

  factory VoiceDeletedEvent.fromJson(Map<String, dynamic> json) {
    return VoiceDeletedEvent(voiceId: json['voice_id'] as String);
  }
}

/// 连接事件
class WsConnectedEvent extends WsEvent {}
class WsDisconnectedEvent extends WsEvent {}
class WsErrorEvent extends WsEvent {
  final String message;
  WsErrorEvent(this.message);
}

/// 解析 WebSocket 事件
WsEvent? parseWsEvent(String data) {
  final json = jsonDecode(data) as Map<String, dynamic>;
  final event = json['event'] as String;
  final eventData = json['data'] as Map<String, dynamic>;

  switch (event) {
    case 'TaskStateChanged':
      return TaskStateChangedEvent.fromJson(eventData);
    case 'SessionClosed':
      return SessionClosedEvent.fromJson(eventData);
    case 'NovelReady':
      return NovelReadyEvent.fromJson(eventData);
    case 'NovelFailed':
      return NovelFailedEvent.fromJson(eventData);
    case 'NovelDeleting':
      return NovelDeletingEvent.fromJson(eventData);
    case 'NovelDeleted':
      return NovelDeletedEvent.fromJson(eventData);
    case 'NovelDeleteFailed':
      return NovelDeleteFailedEvent.fromJson(eventData);
    case 'VoiceDeleted':
      return VoiceDeletedEvent.fromJson(eventData);
    default:
      return null;
  }
}

/// WebSocket 服务
class WebSocketService {
  WebSocketChannel? _globalChannel;
  WebSocketChannel? _sessionChannel;
  String _wsBaseUrl;

  final StreamController<WsEvent> _globalEventController =
      StreamController<WsEvent>.broadcast();
  final StreamController<WsEvent> _sessionEventController =
      StreamController<WsEvent>.broadcast();

  WsConnectionState _globalState = WsConnectionState.disconnected;
  WsConnectionState _sessionState = WsConnectionState.disconnected;

  bool _shouldReconnectGlobal = false;
  bool _shouldReconnectSession = false;
  Timer? _reconnectTimer;
  Timer? _sessionReconnectTimer;
  String? _lastSessionId;

  WebSocketService(this._wsBaseUrl);

  void updateWsBaseUrl(String wsBaseUrl) {
    _wsBaseUrl = wsBaseUrl;
    // 重新连接全局 WebSocket
    if (_shouldReconnectGlobal) {
      disconnectGlobal();
      connectGlobal();
    }
  }

  Stream<WsEvent> get globalEvents => _globalEventController.stream;
  Stream<WsEvent> get sessionEvents => _sessionEventController.stream;
  WsConnectionState get globalState => _globalState;
  WsConnectionState get sessionState => _sessionState;

  /// 连接全局事件 WebSocket
  void connectGlobal() {
    _shouldReconnectGlobal = true;
    _doConnectGlobal();
  }

  Future<void> _doConnectGlobal() async {
    if (!_shouldReconnectGlobal) return;

    _globalState = WsConnectionState.connecting;
    final url = '$_wsBaseUrl/events';

    debugPrint('WebSocketService: Connecting to global WebSocket: $url');
    _globalChannel = WebSocketChannel.connect(Uri.parse(url));

    await _globalChannel!.ready.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        debugPrint('WebSocketService: Global connection timeout');
        _scheduleReconnectGlobal();
      },
    );

    debugPrint('WebSocketService: Global WebSocket connected');
    _globalState = WsConnectionState.connected;

    _globalChannel!.stream.listen(
      (data) {
        final event = parseWsEvent(data as String);
        if (event != null) {
          _globalEventController.add(event);
        }
      },
      onError: (error) {
        debugPrint('WebSocketService: Global stream error: $error');
        _globalState = WsConnectionState.disconnected;
        _scheduleReconnectGlobal();
      },
      onDone: () {
        debugPrint('WebSocketService: Global stream done');
        _globalState = WsConnectionState.disconnected;
        _scheduleReconnectGlobal();
      },
    );
  }

  void _scheduleReconnectGlobal() {
    if (!_shouldReconnectGlobal) return;

    _reconnectTimer?.cancel();
    _globalState = WsConnectionState.reconnecting;
    _reconnectTimer = Timer(const Duration(seconds: 5), _doConnectGlobal);
  }

  /// 断开全局 WebSocket
  void disconnectGlobal() {
    _shouldReconnectGlobal = false;
    _reconnectTimer?.cancel();
    _globalChannel?.sink.close();
    _globalChannel = null;
    _globalState = WsConnectionState.disconnected;
  }

  /// 连接会话 WebSocket
  Future<void> connectSession(String sessionId) async {
    _shouldReconnectSession = true;
    _lastSessionId = sessionId;
    _doConnectSession(sessionId);
  }

  Future<void> _doConnectSession(String sessionId) async {
    if (!_shouldReconnectSession) return;
    
    _sessionState = WsConnectionState.connecting;
    final url = '$_wsBaseUrl/session/$sessionId';

    debugPrint('WebSocketService: Connecting to session WebSocket: $url');
    _sessionChannel = WebSocketChannel.connect(Uri.parse(url));

    await _sessionChannel!.ready.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        debugPrint('WebSocketService: Session connection timeout');
        _scheduleReconnectSession();
      },
    );

    debugPrint('WebSocketService: Session WebSocket connected');
    _sessionState = WsConnectionState.connected;
    _sessionEventController.add(WsConnectedEvent());

    _sessionChannel!.stream.listen(
      (data) {
        if (_sessionState != WsConnectionState.connected) {
          _sessionState = WsConnectionState.connected;
          _sessionEventController.add(WsConnectedEvent());
        }
        final event = parseWsEvent(data as String);
        if (event != null) {
          _sessionEventController.add(event);
        }
      },
      onError: (error) {
        debugPrint('WebSocketService: Session stream error: $error');
        _sessionState = WsConnectionState.disconnected;
        _scheduleReconnectSession();
      },
      onDone: () {
        debugPrint('WebSocketService: Session stream done');
        _sessionState = WsConnectionState.disconnected;
        _scheduleReconnectSession();
      },
    );
  }

  void _scheduleReconnectSession() {
    if (!_shouldReconnectSession) return;

    _sessionReconnectTimer?.cancel();
    _sessionState = WsConnectionState.reconnecting;
    _sessionReconnectTimer = Timer(const Duration(seconds: 5), () => _doConnectSession(_lastSessionId ?? ''));
  }

  /// 断开会话 WebSocket
  void disconnectSession() {
    _shouldReconnectSession = false;
    _sessionReconnectTimer?.cancel();
    _lastSessionId = null;
    _sessionChannel?.sink.close();
    _sessionChannel = null;
    _sessionState = WsConnectionState.disconnected;
  }

  /// 释放资源
  void dispose() {
    disconnectGlobal();
    disconnectSession();
    _globalEventController.close();
    _sessionEventController.close();
  }
}

/// WebSocket 服务 Provider
final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final wsBaseUrl = ref.watch(wsBaseUrlProvider);
  final service = WebSocketService(wsBaseUrl);
  
  // 仅当服务器已配置时才连接
  final settings = ref.watch(settingsProvider);
  if (settings.isServerConfigured) {
    service.connectGlobal();
  }
  
  ref.onDispose(() => service.dispose());
  return service;
});
