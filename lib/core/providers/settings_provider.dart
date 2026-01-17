import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _themeModeKey = 'theme_mode';
const String _serverHostKey = 'server_host';
const String _serverPortKey = 'server_port';

/// 设置状态
class SettingsState {
  final ThemeMode themeMode;
  final String? serverHost;
  final int? serverPort;
  final bool isLoading;
  final bool isInitialized;

  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.serverHost,
    this.serverPort,
    this.isLoading = false,
    this.isInitialized = false,
  });

  bool get isServerConfigured => serverHost != null && serverHost!.isNotEmpty;

  String get apiBaseUrl => 'http://$serverHost:$serverPort/api';
  String get wsBaseUrl => 'ws://$serverHost:$serverPort/ws';

  SettingsState copyWith({
    ThemeMode? themeMode,
    String? serverHost,
    int? serverPort,
    bool? isLoading,
    bool? isInitialized,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      serverHost: serverHost ?? this.serverHost,
      serverPort: serverPort ?? this.serverPort,
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

/// 设置 Notifier
class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    state = state.copyWith(isLoading: true);
    final prefs = await SharedPreferences.getInstance();
    
    final themeModeIndex = prefs.getInt(_themeModeKey) ?? ThemeMode.system.index;
    final themeMode = ThemeMode.values[themeModeIndex];
    final serverHost = prefs.getString(_serverHostKey);
    final serverPort = prefs.getInt(_serverPortKey);
    
    state = state.copyWith(
      themeMode: themeMode,
      serverHost: serverHost,
      serverPort: serverPort,
      isLoading: false,
      isInitialized: true,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, mode.index);
  }

  Future<void> setServerConfig(String host, int port) async {
    state = state.copyWith(serverHost: host, serverPort: port);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverHostKey, host);
    await prefs.setInt(_serverPortKey, port);
  }

  Future<void> clearServerConfig() async {
    state = SettingsState(
      themeMode: state.themeMode,
      isInitialized: true,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_serverHostKey);
    await prefs.remove(_serverPortKey);
  }
}

/// 设置 Provider
final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});

/// 主题模式 Provider（便捷访问）
final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(settingsProvider).themeMode;
});

/// 服务器是否已配置
final isServerConfiguredProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).isServerConfigured;
});

/// 设置是否已初始化
final isSettingsInitializedProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).isInitialized;
});
