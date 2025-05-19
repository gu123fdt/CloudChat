import 'package:audioplayers/audioplayers.dart';
import 'package:matrix/matrix.dart';
import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundService {
  List<MediaDeviceInfo> inputs = [];
  List<MediaDeviceInfo> outputs = [];

  String? selectedInputId;
  String? selectedOutputId;

  final Map<String, AudioPlayer> _players = {};

  late SharedPreferences? store;

  final StreamController<void> _updateController =
      StreamController<void>.broadcast();

  Stream<void> get onUpdate => _updateController.stream;

  SoundService(this.store) {
    _loadDevices();
  }

  void setStore(store) {
    this.store = store;
  }

  Future<void> _loadDevices() async {
    Logs().i("[SoundService][_loadDevices] Call.");
    try {
      final savedInputId = store?.getString("inputDevice");
      final savedOutputId = store?.getString("outputDevice");

      final devices = await navigator.mediaDevices.enumerateDevices();
      inputs = devices.where((d) => d.kind == 'audioinput').toList();
      outputs = devices.where((d) => d.kind == 'audiooutput').toList();

      if (savedInputId != null &&
          inputs.any((d) => d.deviceId == savedInputId)) {
        selectedInputId = savedInputId;
      } else {
        selectedInputId = inputs.isNotEmpty ? inputs.first.deviceId : null;
      }

      if (savedOutputId != null &&
          outputs.any((d) => d.deviceId == savedOutputId)) {
        selectedOutputId = savedOutputId;
      } else {
        selectedOutputId = outputs.isNotEmpty ? outputs.first.deviceId : null;
      }

      if (selectedInputId != null) {
        store?.setString("inputDevice", selectedInputId!);
      }
      if (selectedOutputId != null) {
        store?.setString("outputDevice", selectedOutputId!);
      }

      _updateController.add(null);
    } catch (e) {
      Logs().e("[SoundService][_loadDevices] Call.", e);
    }
  }

  Future<void> refresh() => _loadDevices();

  Future<void> selectInput(String deviceId) async {
    Logs().i("[SoundService][selectInput] Call, id: $deviceId.");
    try {
      if (deviceId == selectedInputId) return;
      selectedInputId = deviceId;
      store?.setString("inputDevice", deviceId);
      Helper.selectAudioInput(deviceId);
      _updateController.add(null);
    } catch (e) {
      Logs().e("[SoundService][selectInput] Call, id: $deviceId failed.", e);
    }
  }

  Future<void> selectOutput(String deviceId) async {
    Logs().i("[SoundService][selectOutput] Call, id: $deviceId.");
    try {
      if (deviceId == selectedOutputId) return;
      selectedOutputId = deviceId;
      store?.setString("outputDevice", deviceId);
      Helper.selectAudioOutput(deviceId);
      _updateController.add(null);
    } catch (e) {
      Logs().e("[SoundService][selectOutput] Call, id: $deviceId failed.", e);
    }
  }

  Future<void> playSound(
    String id,
    String assetPath, {
    bool loop = false,
  }) async {
    Logs().i("[SoundService][playSound] Call, id: $id.");
    try {
      if (_players[id] != null) return;
      final player = AudioPlayer();
      _players[id] = player;
      _players[id]!.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
      await _players[id]!.play(AssetSource(assetPath));
    } catch (e) {
      Logs().e("[SoundService][playSound] Call, id: $id failed.", e);
    }
  }

  Future<void> stopSound(String id) async {
    Logs().i("[SoundService][stopSound] Call, id: $id.");
    try {
      final player = _players.remove(id);
      if (player != null) {
        await player.stop();
        await player.dispose();
      }
    } catch (e) {
      Logs().e("[SoundService][stopSound] Call, id: $id failed.", e);
    }
  }
}
