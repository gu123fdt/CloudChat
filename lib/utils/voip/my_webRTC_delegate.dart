import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc_impl;
import 'package:cloudchat/utils/platform_infos.dart';
import 'package:matrix/matrix.dart';
import 'package:webrtc_interface/webrtc_interface.dart';

class MyWebRTCDelegate implements WebRTCDelegate {
  final void Function(CallSession) onIncoming;
  final void Function(CallSession) onEnded;
  final void Function(CallSession) onMissed;
  final void Function(GroupCallSession) onGroupIncoming;
  final void Function(GroupCallSession) onGroupEnded;
  final void Function() onPlayRingtone;
  final void Function() onStopRingtone;
  final bool Function() onCanHandleNewCall;

  MyWebRTCDelegate({
    required this.onIncoming,
    required this.onEnded,
    required this.onMissed,
    required this.onGroupIncoming,
    required this.onGroupEnded,
    required this.onPlayRingtone,
    required this.onStopRingtone,
    required this.onCanHandleNewCall,
  });

  @override
  Future<RTCPeerConnection> createPeerConnection(
    Map<String, dynamic> configuration, [
    Map<String, dynamic> constraints = const {},
  ]) {
    return webrtc_impl.createPeerConnection(configuration, constraints);
  }

  @override
  Future<void> handleNewCall(CallSession session) async {
    if (PlatformInfos.isMobile) {
      FlutterForegroundTask.setOnLockScreenVisibility(true);
      FlutterForegroundTask.wakeUpScreen();
      FlutterForegroundTask.launchApp();
    }
    onIncoming(session);
  }

  @override
  Future<void> handleCallEnded(CallSession session) async {
    await session.cleanUp();
    onEnded(session);
  }

  @override
  Future<void> handleMissedCall(CallSession session) async {
    onMissed(session);
  }

  @override
  Future<void> handleNewGroupCall(GroupCallSession session) async {
    onGroupIncoming(session);
  }

  @override
  Future<void> handleGroupCallEnded(GroupCallSession session) async {
    onGroupEnded(session);
  }

  @override
  bool get canHandleNewCall => onCanHandleNewCall();

  @override
  bool get isWeb => false;

  @override
  EncryptionKeyProvider? get keyProvider => throw UnimplementedError();

  @override
  MediaDevices get mediaDevices => webrtc_impl.navigator.mediaDevices;

  @override
  Future<void> playRingtone() async {
    onPlayRingtone();
  }

  @override
  Future<void> registerListeners(CallSession session) async {
    // TODO: implement registerListeners
  }

  @override
  Future<void> stopRingtone() async {
    onStopRingtone();
  }
}
