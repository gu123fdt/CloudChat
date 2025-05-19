import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloudchat/utils/voip/sound_service.dart';
import 'package:cloudchat/utils/voip/voip_service.dart';
import 'package:matrix/matrix.dart';
import 'package:vibration/vibration.dart';

class CallManager {
  final VoIPService voipService;
  final SoundService soundService;

  CallInfo? activeCall;
  GroupCallInfo? activeGroup;

  final _events = StreamController<CallEvent>.broadcast();
  Stream<CallEvent> get events => _events.stream;

  CallManager(this.voipService, this.soundService) {
    voipService.onCall.listen(_handleP2P);
    voipService.onGroupCall.listen(_handleGroup);
  }

  void _handleP2P(CallInfo info) {
    Logs().i("[CallManager][_handleP2P] Call.");

    try {
      activeCall = info;

      if (info.session.isOutgoing) {
        if (info.phase == CallPhase.connecting) {
          soundService.playSound('call', 'sounds/call.mp3', loop: true);
        } else {
          soundService.stopSound("call");
        }
      } else {
        if (info.phase == CallPhase.ringing) {
          soundService.playSound('phone', 'sounds/phone.mp3', loop: true);
          Vibration.vibrate(pattern: [500, 1000, 500, 1000], repeat: 0);
        } else {
          soundService.stopSound("phone");
          Vibration.cancel();
        }
      }

      _events.add(CallEvent.incoming(info));
    } catch (e) {
      Logs().e("[CallManager][_handleP2P] Call failed.", e);
    }
  }

  void _handleGroup(GroupCallInfo info) {
    Logs().i("[CallManager][_handleGroup] Call.");

    try {
      activeGroup = info;

      if (info.phase == CallPhase.ringing) {
        soundService.playSound('ring_group', 'sounds/phone.mp3', loop: true);
      } else {
        soundService.stopSound("phone");
        Vibration.cancel();
      }

      _events.add(CallEvent.groupIncoming(info));
    } catch (e) {
      Logs().e("[CallManager][_handleGroup] Call failed.", e);
    }
  }

  Future<void> acceptCall(Room room) async {
    Logs().i("[CallManager][acceptCall] Call.");

    try {
      if (activeCall == null) return;
      soundService.stopSound('phone');
      Vibration.cancel();
      await activeCall!.session.answer();
      _events.add(CallEvent.accepted(activeCall!));
    } catch (e) {
      Logs().e("[CallManager][acceptCall] Call failed.", e);
    }
  }

  Future<void> rejectCall() async {
    Logs().i("[CallManager][rejectCall] Call.");

    try {
      if (activeCall == null) return;
      soundService.stopSound('phone');
      Vibration.cancel();
      await activeCall!.session.reject(reason: CallErrorCode.userBusy);
      _events.add(CallEvent.ended());
      activeCall = null;
    } catch (e) {
      Logs().e("[CallManager][rejectCall] Call failed.", e);
    }
  }

  Future<void> hangupCall() async {
    Logs().i("[CallManager][hangupCall] Call.");

    try {
      if (activeCall == null) return;
      await activeCall!.session.hangup(reason: CallErrorCode.userHangup);
      soundService.stopSound('phone');
      Vibration.cancel();
      _events.add(CallEvent.ended());
      activeCall = null;
    } catch (e) {
      Logs().e("[CallManager][hangupCall] Call failed.", e);
    }
  }

  Future<void> setMute(bool muted) async {
    Logs().i("[CallManager][setMute] Call.");

    try {
      if (activeCall == null) return;
      activeCall!.session.setMicrophoneMuted(muted);
      final track =
          activeCall?.session.getLocalStreams.first.stream!
              .getAudioTracks()
              .first;
      Helper.setMicrophoneMute(muted, track!);
    } catch (e) {
      Logs().e("[CallManager][setMute] Call failed.", e);
    }
  }

  Future<void> joinGroup() async {
    Logs().i("[CallManager][joinGroup] Call.");

    try {
      if (activeGroup == null) return;
      soundService.stopSound('phone');
      Vibration.cancel();
      await activeGroup!.session.enter();
      _events.add(CallEvent.groupJoined(activeGroup!));
    } catch (e) {
      Logs().e("[CallManager][joinGroup] Call failed.", e);
    }
  }

  Future<void> leaveGroup() async {
    Logs().i("[CallManager][leaveGroup] Call.");

    try {
      if (activeGroup == null) return;
      await activeGroup!.session.leave();
      _events.add(CallEvent.groupEnded());
      activeGroup = null;
    } catch (e) {
      Logs().e("[CallManager][leaveGroup] Call failed.", e);
    }
  }

  Future<void> setGroupMute(bool muted) async {
    Logs().i("[CallManager][setGroupMute] Call.");

    try {
      if (activeGroup?.localStream == null) return;
      for (final track in activeGroup!.localStream!.getAudioTracks()) {
        track.enabled = !muted;
      }
    } catch (e) {
      Logs().e("[CallManager][setGroupMute] Call failed.", e);
    }
  }

  Future<void> setSpeakerOn(bool speakerOn) async {
    Logs().i("[CallManager][setSpeakerOn] Call.");

    try {
      activeCall!.speakerOn = speakerOn;

      Helper.setSpeakerphoneOn(speakerOn);
    } catch (e) {
      Logs().e("[CallManager][setSpeakerOn] Call failed.", e);
    }
  }
}
