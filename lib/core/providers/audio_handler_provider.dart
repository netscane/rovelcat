import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../audio_handler.dart';

final audioHandlerProvider = FutureProvider<AudioHandlerWrapper>((ref) async {
  final handler = AudioHandlerWrapper();
  await AudioService.init(
    builder: () => handler,
    config: AudioServiceConfig(
      androidNotificationChannelId: 'com.rovelcat.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: false,
    ),
  );
  return handler;
});
