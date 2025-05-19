import 'dart:async';
import 'dart:ui';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:glass/glass.dart';
import 'package:flutter/material.dart';
import 'package:cloudchat/utils/platform_infos.dart';
import 'package:cloudchat/utils/voip/voip_service.dart';
import 'package:cloudchat/widgets/avatar.dart';
import 'package:cloudchat/widgets/call_banner.dart';
import 'package:cloudchat/widgets/call_banner_controller.dart';
import 'package:cloudchat/widgets/cloud_chat_app.dart';
import 'package:cloudchat/widgets/matrix.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

class _incomingCall extends StatefulWidget {
  final String callId;

  const _incomingCall(this.callId);

  @override
  _incomingCallState createState() => _incomingCallState();
}

class _incomingCallState extends State<_incomingCall>
    with WidgetsBindingObserver {
  StreamSubscription<CallEvent>? callEventsListen;

  CallInfo? info;
  User? user;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || PlatformInfos.isDesktop) return;

    if (info!.phase != CallPhase.ringing) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void initState() {
    info = Matrix.of(context).callManager!.activeCall;

    if (info != null) {
      user = info!.session.remoteUser;
    }

    callEventsListen = Matrix.of(context).callManager!.events.listen((e) {
      if (!mounted) return;

      setState(() {
        info = e.call;
        user ??= info!.session.remoteUser;
      });

      if (info!.phase != CallPhase.ringing) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    });

    FlutterForegroundTask.setOnLockScreenVisibility(true);
    FlutterForegroundTask.wakeUpScreen();
    FlutterForegroundTask.launchApp();

    super.initState();
  }

  void _answer() {
    Matrix.of(context).callManager!.acceptCall(info!.session.room);
  }

  void _hangup() {
    Matrix.of(context).callManager!.hangupCall();
  }

  void _ignore() {
    Matrix.of(context).callManager!.soundService.stopSound("phone");
    navigatorKey.currentContext!.read<CallBannerController>().showBanner(
      CallBanner(widget.callId),
    );
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    callEventsListen?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = PlatformInfos.isMobile;

    return Container(
      width: isMobile ? double.infinity : 224,
      height: isMobile ? double.infinity : null,
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: isMobile ? 24 : 16,
      ),
      child: Column(
        mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
        children: [
          SizedBox(height: isMobile ? 64 : 16),
          Avatar(
            mxContent: user?.avatarUrl,
            name: user?.calcDisplayname(),
            size: 124,
          ),
          const SizedBox(height: 12),
          Text(
            user != null ? user!.calcDisplayname() : "",
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            user != null ? "(${user!.id})" : "()",
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 32),
          if (isMobile) const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: _hangup,
                icon: const Icon(Icons.call_end),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints.tightFor(
                  width: isMobile ? 64 : 48,
                  height: isMobile ? 64 : 48,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                ),
              ),
              SizedBox(width: isMobile ? 64 : 32),
              IconButton(
                onPressed: _answer,
                icon: const Icon(Icons.phone),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints.tightFor(
                  width: isMobile ? 64 : 48,
                  height: isMobile ? 64 : 48,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: _ignore, child: const Text("Ignore call")),
        ],
      ),
    );
  }
}

class ShowIncomingCallDialog {
  static Future<T?> show<T>(BuildContext context, String callId) {
    if (PlatformInfos.isMobile) {
      return Navigator.of(context).push<T>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _FullScreenIncomingCallPage(callId: callId),
        ),
      );
    } else {
      return showDialog<T>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withOpacity(0.3),
        useRootNavigator: true,
        builder:
            (ctx) => Center(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Stack(
                    clipBehavior: Clip.antiAliasWithSaveLayer,
                    children: [
                      _incomingCall(callId),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Material(
                          color: Colors.transparent,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () {
                              navigatorKey.currentContext!
                                  .read<CallBannerController>()
                                  .showBanner(CallBanner(callId));
                              Navigator.of(ctx).pop();
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.close,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ).asGlass(
                clipBorderRadius: const BorderRadius.all(Radius.circular(20)),
              ),
            ),
      );
    }
  }
}

class _FullScreenIncomingCallPage extends StatelessWidget {
  final String callId;
  const _FullScreenIncomingCallPage({required this.callId});

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
              Positioned.fill(child: _incomingCall(callId)),
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
