import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc_impl;
import 'package:cloudchat/utils/platform_infos.dart';
import 'package:cloudchat/utils/voip/my_webRTC_delegate.dart';
import 'package:matrix/matrix.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webrtc_interface/webrtc_interface.dart' hide Navigator;
import 'package:window_manager/window_manager.dart';

class VoIPFixed extends VoIP {
  VoIPFixed(super.client, super.delegate);

  @override
  Future<void> onCallInvite(
    Room room,
    String remoteUserId,
    String? remoteDeviceId,
    Map<String, dynamic> content,
  ) async {
    if (remoteUserId != client.userID) {
      super.onCallInvite(room, remoteUserId, remoteDeviceId, content);
    }
  }
}

enum CallPhase { idle, ringing, connecting, inCall, ended, failed }

class CallInfo {
  final CallSession session;
  CallPhase phase;
  DateTime startedAt;
  MediaStream? localStream;
  final List<WrappedMediaStream> remoteStreams;
  final List<Map<String, dynamic>> history;
  bool speakerOn = false;

  CallInfo(this.session)
    : phase = CallPhase.idle,
      startedAt = DateTime.now(),
      history = [],
      localStream = null,
      remoteStreams = [];
}

class GroupCallInfo {
  final GroupCallSession session;
  CallPhase phase;
  DateTime startedAt;
  MediaStream? localStream;
  final List<Map<String, dynamic>> history;

  GroupCallInfo(this.session)
    : phase = CallPhase.idle,
      startedAt = DateTime.now(),
      localStream = null,
      history = [];
}

class CallEvent {
  final CallInfo? call;
  final GroupCallInfo? group;
  final CallPhase phase;

  CallEvent._({this.call, this.group, required this.phase});

  factory CallEvent.incoming(CallInfo info) =>
      CallEvent._(call: info, phase: info.phase);
  factory CallEvent.accepted(CallInfo info) =>
      CallEvent._(call: info, phase: info.phase);
  factory CallEvent.ended() => CallEvent._(phase: CallPhase.ended);
  factory CallEvent.groupIncoming(GroupCallInfo info) =>
      CallEvent._(group: info, phase: info.phase);
  factory CallEvent.groupJoined(GroupCallInfo info) =>
      CallEvent._(group: info, phase: info.phase);
  factory CallEvent.groupEnded() => CallEvent._(phase: CallPhase.ended);
}

class VoIPService {
  final Client client;
  late final WebRTCDelegate delegate;
  late final VoIPFixed voip;

  final _call = StreamController<CallInfo>.broadcast();
  final _group = StreamController<GroupCallInfo>.broadcast();

  Stream<CallInfo> get onCall => _call.stream;
  Stream<GroupCallInfo> get onGroupCall => _group.stream;

  VoIPService(this.client) {
    delegate = MyWebRTCDelegate(
      onIncoming: (session) => _onIncomingCall(session),
      onEnded: (session) => _onCallEnded(session),
      onMissed: (session) => _onCallMissed(session),
      onGroupIncoming: (group) => _onIncomingGroupCall(group),
      onGroupEnded: (group) => _onGroupCallEnded(group),
      onPlayRingtone: () => {},
      onStopRingtone: () => {},
      onCanHandleNewCall:
          () => voip.currentCID == null && voip.currentGroupCID == null,
    );

    voip = VoIPFixed(client, delegate);
  }

  Future<void> init() async {
    Logs().i("[VoIPService] Init VoIPService.");

    try {
      voip.onIncomingCallSetup.stream.listen(_onIncomingCall);
      voip.onIncomingGroupCall.stream.listen(_onIncomingGroupCall);
    } catch (e) {
      Logs().e("[VoIPService] Init VoIPService failed.", e);
    }
  }

  void _onIncomingCall(CallSession session) async {
    Logs().i("[VoIPService][_onIncomingCall] Call.");
    try {
      if (!session.isOutgoing) {
        final info = CallInfo(session)..phase = CallPhase.ringing;

        await Permission.microphone.request();
        final media = await webrtc_impl.navigator.mediaDevices.getUserMedia({
          'audio': true,
        });
        info.localStream = media;

        _attachP2PListeners(info);
        _call.add(info);

        if (PlatformInfos.isDesktop) {
          await windowManager.show();
          await windowManager.restore();
          await windowManager.focus();
        }
      } else {
        Logs().i("[VoIPService][_onIncomingCall] Ignoring.");
      }
    } catch (e) {
      Logs().e("[VoIPService][_onIncomingCall] Failed.", e);
    }
  }

  void _onIncomingGroupCall(GroupCallSession session) async {
    Logs().i("[VoIPService][_onIncomingGroupCall] Call.");

    try {
      final info = GroupCallInfo(session)..phase = CallPhase.ringing;

      await Permission.microphone.request();
      final media = await webrtc_impl.navigator.mediaDevices.getUserMedia({
        'audio': true,
      });
      info.localStream = media;

      _attachGroupListeners(info);
      _group.add(info);

      if (PlatformInfos.isDesktop) {
        await windowManager.show();
        await windowManager.restore();
        await windowManager.focus();
      }
    } catch (e) {
      Logs().e("[VoIPService][_onIncomingGroupCall] Failed.", e);
    }
  }

  void _onCallEnded(CallSession session) {
    Logs().i("[VoIPService][_onCallEnded] Call.");

    try {} catch (e) {
      Logs().e("[VoIPService][_onCallEnded] Failed.", e);
    }
  }

  void _onGroupCallEnded(GroupCallSession session) {
    Logs().i("[VoIPService][_onGroupCallEnded] Call.");

    try {} catch (e) {
      Logs().e("[VoIPService][_onGroupCallEnded] Failed.", e);
    }
  }

  void _onCallMissed(CallSession session) {
    Logs().i("[VoIPService][_onCallMissed] Call.");

    try {} catch (e) {
      Logs().e("[VoIPService][_onCallMissed] Failed.", e);
    }
  }

  void _attachP2PListeners(CallInfo info) {
    Logs().i("[VoIPService][_attachP2PListeners] Call.");

    try {
      final s = info.session;

      s.onCallStateChanged.stream.listen((state) {
        info.history.add({'time': DateTime.now(), 'state': state});
        switch (state) {
          case CallState.kRinging:
            info.phase = CallPhase.ringing;
            break;
          case CallState.kConnecting:
            info.phase = CallPhase.connecting;
            break;
          case CallState.kConnected:
            info.phase = CallPhase.inCall;
            break;
          case CallState.kEnded:
            info.phase = CallPhase.ended;
            break;
          case CallState.kFledgling:
            info.phase = CallPhase.failed;
            s.restartIce();
            break;
          default:
            break;
        }

        _call.add(info);
      });

      s.onStreamAdd.stream.listen((wrapped) {
        info.remoteStreams.add(wrapped);
        _call.add(info);
      });

      s.onStreamRemoved.stream.listen((wrapped) {
        info.remoteStreams.remove(wrapped);
        _call.add(info);
      });
    } catch (e) {
      Logs().e("[VoIPService][_attachP2PListeners] Failed.", e);
    }
  }

  void _attachGroupListeners(GroupCallInfo info) {
    Logs().i("[VoIPService][_attachGroupListeners] Call.");

    try {
      final s = info.session;

      s.onGroupCallState.stream.listen((state) {
        info.history.add({'time': DateTime.now(), 'state': state});
        switch (state) {
          case GroupCallState.initializingLocalCallFeed:
            info.phase = CallPhase.ringing;
            break;
          case GroupCallState.entered:
            info.phase = CallPhase.inCall;
            break;
          case GroupCallState.ended:
            info.phase = CallPhase.ended;
            break;
          default:
            break;
        }
        _group.add(info);
      });

      s.matrixRTCEventStream.stream.listen((evt) {
        info.history.add({'time': DateTime.now(), 'event': evt});
        _group.add(info);
      });
    } catch (e) {
      Logs().e("[VoIPService][_attachGroupListeners] Failed.", e);
    }
  }

  Future<CallInfo?> startCall(Room room) async {
    Logs().i("[VoIPService][startCall] Call.");

    try {
      final session = await voip.inviteToCall(room, CallType.kVoice);
      final info = CallInfo(session)..phase = CallPhase.connecting;
      _attachP2PListeners(info);

      await Permission.microphone.request();
      final media = await webrtc_impl.navigator.mediaDevices.getUserMedia({
        'audio': true,
      });
      info.localStream = media;
      await session.gotCallFeedsForInvite([
        WrappedMediaStream(
          stream: media,
          room: room,
          participant: session.localParticipant!,
          purpose: "usermedia",
          client: client,
          audioMuted: false,
          videoMuted: true,
          isGroupCall: false,
          voip: voip,
        ),
      ]);

      return info;
    } catch (e) {
      Logs().e("[VoIPService][startCall] Failed.", e);
    }

    return null;
  }

  Future<GroupCallInfo?> startGroupCall(Room room, String groupCallId) async {
    Logs().i("[VoIPService][startGroupCall] Call.");

    try {
      final session = await voip.fetchOrCreateGroupCall(
        groupCallId,
        room,
        CallBackend as CallBackend,
        'com.example.app',
        'scope',
      );
      final info = GroupCallInfo(session)..phase = CallPhase.connecting;
      _attachGroupListeners(info);

      await Permission.microphone.request();
      final media = await webrtc_impl.navigator.mediaDevices.getUserMedia({
        'audio': true,
      });
      info.localStream = media;
      await session.enter(
        stream: WrappedMediaStream(
          stream: media,
          room: room,
          participant: session.localParticipant!,
          purpose: "usermedia",
          client: client,
          audioMuted: false,
          videoMuted: true,
          isGroupCall: false,
          voip: voip,
        ),
      );

      return info;
    } catch (e) {
      Logs().e("[VoIPService][startGroupCall] Failed.", e);
    }

    return null;
  }
}
