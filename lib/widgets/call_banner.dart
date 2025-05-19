import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:cloudchat/utils/voip/voip_service.dart';
import 'package:cloudchat/widgets/avatar.dart';
import 'package:cloudchat/widgets/call.dart';
import 'package:cloudchat/widgets/call_banner_controller.dart';
import 'package:cloudchat/widgets/incoming_call.dart';
import 'package:cloudchat/widgets/cloud_chat_app.dart';
import 'package:cloudchat/widgets/matrix.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

class CallBanner extends StatefulWidget {
  final String callId;

  const CallBanner(this.callId, {super.key});

  @override
  CallBannerState createState() => CallBannerState();
}

class CallBannerState extends State<CallBanner>
    with SingleTickerProviderStateMixin {
  StreamSubscription<CallEvent>? callEventsListen;

  DateTime? callStartTime;

  CallInfo? info;
  Room? room;

  late Timer _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    info = Matrix.of(navigatorKey.currentContext!).callManager!.activeCall;

    if (info != null) {
      room ??= info!.session.room;

      try {
        callStartTime =
            info!.history.firstWhere(
              (h) => h["state"] == CallState.kConnected,
            )["time"];
      } catch (_) {}
    }

    callEventsListen = Matrix.of(
      navigatorKey.currentContext!,
    ).callManager!.events.listen((e) {
      if (!mounted) return;

      setState(() {
        info = e.call;
        room ??= info!.session.room;

        try {
          callStartTime =
              info!.history.firstWhere(
                (h) => h["state"] == CallState.kConnected,
              )["time"];
        } catch (_) {}
      });

      if (info!.phase == CallPhase.ended || info!.phase == CallPhase.failed) {
        navigatorKey.currentContext!.read<CallBannerController>().hideBanner();
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

  @override
  void dispose() {
    callEventsListen?.cancel();
    _timer.cancel();
    super.dispose();
  }

  List<Color> _getColors() {
    if (info?.phase == CallPhase.inCall &&
        info?.session.isMicrophoneMuted == false) {
      return const [Color(0xFFB8E986), Color(0xFF4CAF50)];
    } else if (info?.phase == CallPhase.connecting ||
        info?.phase == CallPhase.ringing) {
      return const [Color(0xFFADD8E6), Color.fromARGB(255, 41, 41, 233)];
    } else if (info?.session.isMicrophoneMuted == true) {
      return const [Color(0xFFB8E986), Color.fromARGB(255, 235, 80, 69)];
    }

    return const [Color(0xFFFFCDD2), Color.fromARGB(255, 235, 80, 69)];
  }

  void _answer() {
    Matrix.of(
      navigatorKey.currentContext!,
    ).callManager!.acceptCall(info!.session.room);
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

  List<Widget> _getActions() {
    if (info?.phase == CallPhase.inCall ||
        info?.phase == CallPhase.connecting) {
      return [
        IconButton(
          onPressed: _mute,
          icon: Icon(
            info?.session.isMicrophoneMuted == true ? Icons.mic_off : Icons.mic,
            color: Colors.white,
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.call_end,
            color:
                info?.session.isMicrophoneMuted == true
                    ? Colors.white
                    : Colors.red,
          ),
          onPressed: _hangup,
        ),
      ];
    } else if (info?.phase == CallPhase.ringing) {
      return [
        IconButton(
          icon: const Icon(Icons.phone, color: Colors.green),
          onPressed: _answer,
        ),
        IconButton(
          icon: const Icon(Icons.call_end, color: Colors.red),
          onPressed: _hangup,
        ),
      ];
    } else {
      return [];
    }
  }

  void _openCallPage() {
    if (info!.phase == CallPhase.ringing && info!.session.isRinging) {
      navigatorKey.currentContext!.read<CallBannerController>().hideBanner();

      ShowIncomingCallDialog.show(navigatorKey.currentContext!, widget.callId);
    }

    if (info!.phase == CallPhase.inCall) {
      navigatorKey.currentContext!.read<CallBannerController>().hideBanner();

      ShowCallDialog.show(navigatorKey.currentContext!, widget.callId);
    }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _openCallPage,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: ui.window.viewPadding.top / ui.window.devicePixelRatio,
              ),
              height:
                  48 + ui.window.viewPadding.top / ui.window.devicePixelRatio,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: _getColors(),
                ),
              ),
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Avatar(
                        mxContent: room?.avatar,
                        name: room?.getLocalizedDisplayname(),
                        size: 36,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          room != null ? room!.getLocalizedDisplayname() : "",
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium!.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        if (info?.phase != null &&
                            info?.phase != CallPhase.inCall)
                          Text(
                            info?.phase != null
                                ? "(${info?.phase.name}...)"
                                : "",
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall!.copyWith(
                              color: const Color.fromARGB(185, 255, 255, 255),
                              fontSize:
                                  theme.textTheme.titleSmall!.fontSize! - 2,
                            ),
                          ),
                        if (info?.phase != null &&
                            info?.phase == CallPhase.inCall &&
                            callStartTime != null)
                          Text(
                            _timeFormat(_elapsed),
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall!.copyWith(
                              color: const Color.fromARGB(185, 255, 255, 255),
                              fontSize:
                                  theme.textTheme.titleSmall!.fontSize! - 2,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: _getActions(),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.dividerColor),
          ],
        ),
      ),
    );
  }
}
