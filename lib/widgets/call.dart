import 'dart:async';
import 'dart:ui';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:glass/glass.dart';
import 'package:flutter/material.dart';
import 'package:cloudchat/utils/platform_infos.dart';
import 'package:cloudchat/utils/string_color.dart';
import 'package:cloudchat/utils/voip/sound_service.dart';
import 'package:cloudchat/utils/voip/voip_service.dart';
import 'package:cloudchat/widgets/avatar.dart';
import 'package:cloudchat/widgets/call_banner.dart';
import 'package:cloudchat/widgets/call_banner_controller.dart';
import 'package:cloudchat/widgets/cloud_chat_app.dart';
import 'package:cloudchat/widgets/matrix.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

class _callPage extends StatefulWidget {
  final String callId;

  const _callPage(this.callId);

  @override
  _callPageState createState() => _callPageState();
}

class _callPageState extends State<_callPage> {
  StreamSubscription<CallEvent>? callEventsListen;

  DateTime? callStartTime;

  CallInfo? info;
  User? user;

  late Timer _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    info = Matrix.of(navigatorKey.currentContext!).callManager!.activeCall;

    if (info != null) {
      user = info!.session.remoteUser;

      callStartTime =
          info!.history.firstWhere(
            (h) => h["state"] == CallState.kConnected,
          )["time"];
    }

    callEventsListen = Matrix.of(
      navigatorKey.currentContext!,
    ).callManager!.events.listen((e) {
      if (!mounted) return;

      setState(() {
        info = e.call;
        user ??= info!.session.remoteUser;

        callStartTime =
            info?.history.firstWhere(
              (h) => h["state"] == CallState.kConnected,
            )["time"];
      });

      if (info!.phase != CallPhase.inCall) {
        if (Navigator.of(navigatorKey.currentContext!).canPop()) {
          Navigator.of(navigatorKey.currentContext!).pop();
        }
      }
    });

    super.initState();

    _updateElapsed();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateElapsed(),
    );
  }

  void _updateElapsed() {
    final now = DateTime.now();
    setState(() {
      if (callStartTime != null) {
        _elapsed = now.difference(callStartTime!);
      }
    });
  }

  String _timeFormat(Duration d) {
    twoDigits(int n) => n.toString().padLeft(2, '0');
    final h = twoDigits(d.inHours);
    final m = twoDigits(d.inMinutes % 60);
    final s = twoDigits(d.inSeconds % 60);

    if (h == "00") {
      return '$m:$s';
    } else {
      return '$h:$m:$s';
    }
  }

  void _hangup() {
    Matrix.of(navigatorKey.currentContext!).callManager!.hangupCall();
  }

  void _mute() {
    setState(() {
      Matrix.of(
        navigatorKey.currentContext!,
      ).callManager!.setMute(!info!.session.isMicrophoneMuted);
    });
  }

  void _switchSpeaker() {
    setState(() {
      Matrix.of(navigatorKey.currentContext!).callManager!.setSpeakerOn(
        !Matrix.of(
          navigatorKey.currentContext!,
        ).callManager!.activeCall!.speakerOn,
      );
    });
  }

  @override
  void dispose() {
    callEventsListen?.cancel();
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatars = [
      Expanded(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          margin:
              PlatformInfos.isMobile
                  ? const EdgeInsets.only(bottom: 8)
                  : const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color:
                Color.lerp(
                  (Matrix.of(
                        navigatorKey.currentContext!,
                      ).client.userID!.localpart)
                      ?.lightColorAvatar,
                  Colors.white,
                  0.25,
                )!,
          ),
          child: FutureBuilder<Profile>(
            future:
                Matrix.of(
                  navigatorKey.currentContext!,
                ).client.fetchOwnProfile(),
            builder:
                (context, snapshot) => Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      children: [
                        Avatar(
                          mxContent: snapshot.data?.avatarUrl,
                          name:
                              snapshot.data?.displayName ??
                              Matrix.of(
                                navigatorKey.currentContext!,
                              ).client.userID!.localpart,
                          size: 124,
                        ),
                        if (info?.session.isMicrophoneMuted == true)
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.8),
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(
                                Icons.mic_off,
                                size: 20,
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      snapshot.data != null ? snapshot.data!.displayName! : "",
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
          ),
        ),
      ),
      Expanded(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          margin:
              PlatformInfos.isMobile
                  ? const EdgeInsets.only(top: 8)
                  : const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color:
                Color.lerp(
                  user?.displayName?.lightColorAvatar,
                  Colors.white,
                  0.25,
                )!,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                children: [
                  Avatar(
                    mxContent: user?.avatarUrl,
                    name: user?.displayName,
                    size: 124,
                  ),
                  if (info?.session.remoteUserMediaStream?.audioMuted == true)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(
                          Icons.mic_off,
                          size: 20,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                user != null ? user!.displayName! : "",
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
      ),
    ];

    return Container(
      padding: PlatformInfos.isMobile ? const EdgeInsets.all(8) : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          Container(
            height: 64,
            alignment: Alignment.center,
            margin: const EdgeInsets.only(bottom: 16),
            child: Text(
              _timeFormat(_elapsed),
              style: Theme.of(context).textTheme.titleLarge!.copyWith(
                color: const Color.fromARGB(255, 199, 199, 199),
              ),
            ),
          ),
          Expanded(
            child: SizedBox(
              width: double.infinity,
              child:
                  PlatformInfos.isMobile
                      ? Column(children: avatars)
                      : Row(children: avatars),
            ),
          ),
          Container(
            height: 64,
            margin: const EdgeInsets.only(top: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                MicWithDevicePicker(
                  isMuted: info?.session.isMicrophoneMuted ?? false,
                  onMuteToggle: _mute,
                  soundService:
                      Matrix.of(navigatorKey.currentContext!).soundService!,
                ),
                if (PlatformInfos.isMobile) ...[
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: _switchSpeaker,
                    icon: Icon(
                      !Matrix.of(
                            navigatorKey.currentContext!,
                          ).callManager!.activeCall!.speakerOn
                          ? Icons.volume_up
                          : Icons.volume_off,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 48,
                      height: 48,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).cardColor,
                      foregroundColor: Colors.white,
                      shape: const CircleBorder(),
                    ),
                  ),
                ],
                const SizedBox(width: 16),
                IconButton(
                  onPressed: _hangup,
                  icon: const Icon(Icons.call_end),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 48,
                    height: 48,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: const CircleBorder(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ShowCallDialog {
  static Future<T?> show<T>(BuildContext context, String callId) {
    if (PlatformInfos.isMobile) {
      return Navigator.of(context).push<T>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _FullScreenCallPage(callId: callId),
        ),
      );
    } else {
      return showDialog<T>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withOpacity(0.3),
        useRootNavigator: true,
        builder:
            (ctx) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: _DecoratedCallDialog(
                  callId: callId,
                  onClose: () {
                    if (Matrix.of(context).callManager!.activeCall != null) {
                      context.read<CallBannerController>().showBanner(
                        CallBanner(callId),
                      );
                    }
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ),
      );
    }
  }
}

class _FullScreenCallPage extends StatelessWidget {
  final String callId;
  const _FullScreenCallPage({required this.callId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            children: [
              Positioned.fill(child: _callPage(callId)),
              Positioned(
                top: 16,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    if (Matrix.of(context).callManager!.activeCall != null) {
                      context.read<CallBannerController>().showBanner(
                        CallBanner(callId),
                      );
                    }
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        ).asGlass(clipBorderRadius: const BorderRadius.all(Radius.zero)),
      ),
    );
  }
}

class _DecoratedCallDialog extends StatelessWidget {
  final String callId;
  final VoidCallback onClose;

  const _DecoratedCallDialog({required this.callId, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            _callPage(callId),
            Positioned(
              top: 0,
              right: 0,
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onClose,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.close, size: 20, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).asGlass(clipBorderRadius: const BorderRadius.all(Radius.circular(20)));
  }
}

class MicWithDevicePicker extends StatefulWidget {
  final bool isMuted;
  final VoidCallback onMuteToggle;
  final SoundService soundService;

  const MicWithDevicePicker({
    super.key,
    required this.isMuted,
    required this.onMuteToggle,
    required this.soundService,
  });

  @override
  _MicWithDevicePickerState createState() => _MicWithDevicePickerState();
}

class _MicWithDevicePickerState extends State<MicWithDevicePicker> {
  final _buttonKey = GlobalKey();
  late List<MediaDeviceInfo> _inputs;
  late List<MediaDeviceInfo> _outputs;
  late String? _selectedInput;
  late String? _selectedOutput;
  late StreamSubscription _selectedSub;
  late StreamSubscription _soundUpdateSub;

  @override
  void initState() {
    super.initState();
    _inputs = widget.soundService.inputs;
    _outputs = widget.soundService.outputs;
    _selectedInput = widget.soundService.selectedInputId;
    _selectedOutput = widget.soundService.selectedOutputId;
    _soundUpdateSub = widget.soundService.onUpdate.listen((_) {
      setState(() {
        _inputs = widget.soundService.inputs;
        _outputs = widget.soundService.outputs;
        _selectedInput = widget.soundService.selectedInputId;
        _selectedOutput = widget.soundService.selectedOutputId;
      });
    });
  }

  @override
  void dispose() {
    _selectedSub.cancel();
    _soundUpdateSub.cancel();
    super.dispose();
  }

  Future<void> _openMenu() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).canvasColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (_) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Text(
                    'Select Audio Device',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  if (_inputs.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Inputs',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    ..._inputs.map(
                      (d) => ListTile(
                        leading: const Icon(Icons.mic),
                        title: Text(
                          d.label ?? 'Unknown',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing:
                            d.deviceId == _selectedInput
                                ? const Icon(Icons.check)
                                : null,
                        onTap: () {
                          widget.soundService.selectInput(d.deviceId);
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                    const Divider(),
                  ],
                  if (_outputs.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Outputs',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    ..._outputs.map(
                      (d) => ListTile(
                        leading: const Icon(Icons.volume_up),
                        title: Text(
                          d.label ?? 'Unknown',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing:
                            d.deviceId == _selectedOutput
                                ? const Icon(Icons.check)
                                : null,
                        onTap: () {
                          widget.soundService.selectOutput(d.deviceId);
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          key: _buttonKey,
          onPressed: widget.onMuteToggle,
          icon: Icon(widget.isMuted ? Icons.mic_off : Icons.mic),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(context).cardColor,
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
          ),
        ),
        if (!PlatformInfos.isMobile)
          Positioned(
            right: 0,
            bottom: 0,
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: _openMenu,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_drop_up,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
