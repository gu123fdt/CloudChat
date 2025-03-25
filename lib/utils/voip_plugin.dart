import 'dart:convert';
import 'dart:core';
import 'dart:io';

import 'package:cloudchat/widgets/cloud_chat_app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc_impl;
import 'package:matrix/matrix.dart';
import 'package:vibration/vibration.dart';
import 'package:webrtc_interface/webrtc_interface.dart' hide Navigator;
import 'package:cloudchat/pages/chat_list/chat_list.dart';
import 'package:cloudchat/pages/dialer/dialer.dart';
import 'package:cloudchat/utils/platform_infos.dart';
import '../../utils/voip/callkeep_manager.dart';
import '../../utils/voip/user_media_manager.dart';
import '../widgets/matrix.dart';

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

class VoipPlugin with WidgetsBindingObserver implements WebRTCDelegate {
  final MatrixState matrix;
  Client get client => matrix.client;

  VoipPlugin(this.matrix) {
    voip = VoIPFixed(client, this);

    if (!kIsWeb && !Platform.isWindows) {
      final wb = WidgetsBinding.instance;
      wb.addObserver(this);
      didChangeAppLifecycleState(wb.lifecycleState);
    }

    initCallInvite();
  }
  bool background = false;
  bool speakerOn = false;
  late VoIP voip;
  OverlayEntry? overlayEntry;
  BuildContext get context => matrix.context;

  void initCallInvite() async {
    final callCandidatesJson = matrix.store.getString('CallInvite');

    if (callCandidatesJson != null) {
      final Map<String, dynamic> callCandidatesJsonMap =
          jsonDecode(callCandidatesJson);

      final room = matrix.client.getRoomById(callCandidatesJsonMap['room_id']);
      final event = Event.fromJson(callCandidatesJsonMap, room!);

      voip.onCallInvite(
        room,
        event.senderId,
        event.content.tryGet<String>('invitee_device_id'),
        event.content,
      );

      await matrix.store.remove('CallInvite');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState? state) {
    background = (state == AppLifecycleState.detached ||
        state == AppLifecycleState.paused);
  }

  void addCallingOverlay(String callId, CallSession call) {
    final context = kIsWeb || Platform.isWindows
        ? ChatList.contextForVoip!
        : this.context; // web is weird

    if (overlayEntry != null) {
      Logs().e('[VOIP] addCallingOverlay: The call session already exists?');
      overlayEntry!.remove();
    }
    // Overlay.of(context) is broken on web
    // falling back on a dialog
    if (kIsWeb || Platform.isWindows) {
      overlayEntry = OverlayEntry(
        builder: (_) => Calling(
          context: navigatorKey.currentContext!,
          client: client,
          callId: callId,
          call: call,
          onClear: () {
            overlayEntry?.remove();
            overlayEntry = null;
          },
        ),
      );
      Navigator.of(navigatorKey.currentContext!).overlay?.insert(overlayEntry!);
    } else {
      overlayEntry = OverlayEntry(
        builder: (_) => Calling(
          context: navigatorKey.currentContext!,
          client: client,
          callId: callId,
          call: call,
          onClear: () {
            overlayEntry?.remove();
            overlayEntry = null;
          },
        ),
      );
      Navigator.of(navigatorKey.currentContext!).overlay?.insert(overlayEntry!);
    }
  }

  @override
  MediaDevices get mediaDevices => webrtc_impl.navigator.mediaDevices;

  Future<void> setMicrophoneDevice(String? deviceId) async {
    try {
      final devices = await mediaDevices.enumerateDevices();
      final audioDevices =
          devices.where((device) => device.kind == 'audioinput').toList();

      if (audioDevices.isNotEmpty) {
        final selectedDevice = deviceId != null
            ? audioDevices.firstWhere((device) => device.deviceId == deviceId)
            : audioDevices.isNotEmpty
                ? audioDevices.first
                : throw Exception("Device not found");

        if (selectedDevice != null) {
          final stream = await mediaDevices.getUserMedia({
            'audio': {'deviceId': selectedDevice.deviceId}
          });
        }
      }
    } catch (e) {
      Logs().i("$e");
    }
  }

  @override
  bool get isWeb => kIsWeb || Platform.isWindows;

  @override
  Future<RTCPeerConnection> createPeerConnection(
    Map<String, dynamic> configuration, [
    Map<String, dynamic> constraints = const {},
  ]) {
    return webrtc_impl.createPeerConnection(configuration, constraints);
  }

  Future<bool> get hasCallingAccount async {
    try {
      return kIsWeb || Platform.isWindows
          ? false
          : await CallKeepManager().hasPhoneAccountEnabled;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> playRingtone() async {
    if (PlatformInfos.isAndroid) {
      Vibration.vibrate(
        pattern: [
          500,
          1000,
          500,
          1000,
        ],
        repeat: 0,
      );
    }

    if (!background && !await hasCallingAccount) {
      try {
        await UserMediaManager().startRingingTone();
      } catch (_) {}
    }
  }

  @override
  Future<void> stopRingtone() async {
    if (PlatformInfos.isAndroid) {
      Vibration.cancel();
    }

    if (!background && !await hasCallingAccount) {
      try {
        await UserMediaManager().stopRingingTone();
      } catch (_) {}
    }
  }

  @override
  Future<void> handleNewCall(CallSession call) async {
    await matrix.store.remove('CallInvite');

    if (PlatformInfos.isAndroid) {
      // probably works on ios too
      var hasCallingAccount = false;

      try {
        hasCallingAccount = await CallKeepManager().hasPhoneAccountEnabled;
      } catch (_) {
        hasCallingAccount = false;
      }

      if (call.direction == CallDirection.kIncoming &&
          hasCallingAccount &&
          call.type == CallType.kVoice) {
        ///Popup native telecom manager call UI for incoming call.
        final callKeeper = CallKeeper(CallKeepManager(), call);
        CallKeepManager().addCall(call.callId, callKeeper);
        await CallKeepManager().showCallkitIncoming(call);
        return;
      } else {
        try {
          final wasForeground = await FlutterForegroundTask.isAppOnForeground;

          await matrix.store.setString(
            'wasForeground',
            wasForeground == true ? 'true' : 'false',
          );
          FlutterForegroundTask.setOnLockScreenVisibility(true);
          FlutterForegroundTask.wakeUpScreen();
          FlutterForegroundTask.launchApp();
        } catch (e) {
          Logs().e('VOIP foreground failed $e');
        }
        // use fallback flutter call pages for outgoing and video calls.
        addCallingOverlay(call.callId, call);
        try {
          if (!hasCallingAccount) {
            ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
              const SnackBar(
                content: Text(
                  'No calling accounts found (used for native calls UI)',
                ),
              ),
            );
          }
        } catch (e) {
          Logs().e('failed to show snackbar');
        }
      }
    } else {
      addCallingOverlay(call.callId, call);
    }
  }

  @override
  Future<void> handleCallEnded(CallSession session) async {
    await matrix.store.remove('CallInvite');

    if (overlayEntry != null) {
      overlayEntry!.remove();
      overlayEntry = null;
      if (PlatformInfos.isAndroid) {
        FlutterForegroundTask.setOnLockScreenVisibility(false);
        FlutterForegroundTask.stopService();
        final wasForeground = matrix.store.getString('wasForeground');
        wasForeground == 'false' ? FlutterForegroundTask.minimizeApp() : null;
      }
    }
  }

  @override
  Future<void> handleGroupCallEnded(GroupCallSession groupCall) async {
    // TODO: implement handleGroupCallEnded
  }

  @override
  Future<void> handleNewGroupCall(GroupCallSession groupCall) async {
    // TODO: implement handleNewGroupCall
  }

  @override
  // TODO: implement canHandleNewCall
  bool get canHandleNewCall =>
      voip.currentCID == null && voip.currentGroupCID == null;

  @override
  Future<void> handleMissedCall(CallSession session) async {
    // TODO: implement handleMissedCall
  }

  @override
  // TODO: implement keyProvider
  EncryptionKeyProvider? get keyProvider => throw UnimplementedError();
}
