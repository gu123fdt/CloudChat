import 'package:flutter/foundation.dart';

import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:audioplayers/audioplayers.dart';

import 'package:cloudchat/utils/platform_infos.dart';

class UserMediaManager {
  factory UserMediaManager() {
    return _instance;
  }

  UserMediaManager._internal();

  static final UserMediaManager _instance = UserMediaManager._internal();

  AudioPlayer? _assetsAudioPlayer;

  final FlutterRingtonePlayer _flutterRingtonePlayer = FlutterRingtonePlayer();

  Future<void> startRingingTone() async {
    if (PlatformInfos.isMobile) {
      await _flutterRingtonePlayer.playRingtone(volume: 80);
    } else if ((kIsWeb || PlatformInfos.isMacOS || PlatformInfos.isWindows)) {
      const path = 'sounds/phone.mp3';
      final player = _assetsAudioPlayer = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.play(AssetSource(path));
    }
    return;
  }

  Future<void> stopRingingTone() async {
    if (PlatformInfos.isMobile) {
      await _flutterRingtonePlayer.stop();
    }
    await _assetsAudioPlayer!.stop();
    await _assetsAudioPlayer!.setReleaseMode(ReleaseMode.stop);
    _assetsAudioPlayer = null;
    return;
  }
}
