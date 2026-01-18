import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class AudioHandlerWrapper extends BaseAudioHandler {
  final AudioPlayer _player = AudioPlayer();

  AudioHandlerWrapper() {
    _init();
  }

  Future<void> _init() async {
    _player.playbackEventStream.listen((event) {
      _updatePlaybackState();
    });

    _player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        _onComplete();
      }
    });
  }

  @override
  Future<void> setUrl(String url) async {
    await _player.setUrl(url);
  }

  @override
  Future<void> play() async {
    await _player.play();
    _updatePlaybackState();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    _updatePlaybackState();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    _updatePlaybackState();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  Future<void> skipToNext() async {
  }

  @override
  Future<void> skipToPrevious() async {
  }

  @override
  Future<void> setMediaItem(MediaItem item) async {
    mediaItem.add(item);
  }

  void _updatePlaybackState() {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState] ?? AudioProcessingState.idle,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: mediaItem.value == null ? 0 : 0,
    ));
  }

  void _onComplete() {
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.completed,
      playing: false,
    ));
  }

  AudioPlayer get player => _player;

  Future<void> dispose() async {
    await _player.dispose();
  }
}
