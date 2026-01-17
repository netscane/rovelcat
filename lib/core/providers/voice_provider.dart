import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/voice.dart';
import '../../data/services/api_service.dart';

const String _defaultVoiceKey = 'default_voice_id';

/// 音色列表状态
class VoiceListState {
  final List<Voice> voices;
  final bool isLoading;
  final bool isRefreshing;
  final String? error;
  final String? defaultVoiceId;

  const VoiceListState({
    this.voices = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
    this.defaultVoiceId,
  });

  VoiceListState copyWith({
    List<Voice>? voices,
    bool? isLoading,
    bool? isRefreshing,
    String? error,
    String? defaultVoiceId,
  }) {
    return VoiceListState(
      voices: voices ?? this.voices,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: error,
      defaultVoiceId: defaultVoiceId ?? this.defaultVoiceId,
    );
  }

  Voice? get defaultVoice {
    if (defaultVoiceId == null) return voices.isNotEmpty ? voices.first : null;
    return voices.where((v) => v.id == defaultVoiceId).firstOrNull ?? 
           (voices.isNotEmpty ? voices.first : null);
  }
}

/// 音色列表 Notifier
class VoiceListNotifier extends StateNotifier<VoiceListState> {
  final ApiService _api;

  VoiceListNotifier(this._api) : super(const VoiceListState()) {
    _init();
  }

  Future<void> _init() async {
    await _loadDefaultVoice();
    await loadVoices();
  }

  Future<void> _loadDefaultVoice() async {
    final prefs = await SharedPreferences.getInstance();
    final defaultVoiceId = prefs.getString(_defaultVoiceKey);
    state = state.copyWith(defaultVoiceId: defaultVoiceId);
  }

  Future<void> loadVoices() async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await _api.listVoices();
    result.fold(
      (error) => state = state.copyWith(isLoading: false, error: error),
      (List<Voice> voices) => state = state.copyWith(isLoading: false, voices: voices),
    );
  }

  Future<void> refresh() async {
    state = state.copyWith(isRefreshing: true, error: null);
    final result = await _api.listVoices();
    result.fold(
      (error) => state = state.copyWith(isRefreshing: false, error: error),
      (List<Voice> voices) => state = state.copyWith(isRefreshing: false, voices: voices),
    );
  }

  Future<void> setDefaultVoice(String voiceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_defaultVoiceKey, voiceId);
    state = state.copyWith(defaultVoiceId: voiceId);
  }

  void addVoice(Voice voice) {
    state = state.copyWith(voices: [...state.voices, voice]);
  }

  void removeVoice(String id) {
    final voices = state.voices.where((v) => v.id != id).toList();
    // 如果删除的是默认音色，重置默认音色
    String? newDefaultId = state.defaultVoiceId;
    if (state.defaultVoiceId == id) {
      newDefaultId = voices.isNotEmpty ? voices.first.id : null;
      SharedPreferences.getInstance().then((prefs) {
        if (newDefaultId != null) {
          prefs.setString(_defaultVoiceKey, newDefaultId);
        } else {
          prefs.remove(_defaultVoiceKey);
        }
      });
    }
    state = state.copyWith(voices: voices, defaultVoiceId: newDefaultId);
  }
}

/// 音色列表 Provider
final voiceListProvider = StateNotifierProvider<VoiceListNotifier, VoiceListState>((ref) {
  return VoiceListNotifier(ref.watch(apiServiceProvider));
});

/// 当前选中的音色（用于播放）
final selectedVoiceProvider = StateProvider<Voice?>((ref) {
  final voiceState = ref.watch(voiceListProvider);
  return voiceState.defaultVoice;
});
