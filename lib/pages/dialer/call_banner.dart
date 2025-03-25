import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

enum CallBannerType { incoming, outgoing, connected }

class CallBanner extends StatefulWidget {
  final CallSession call;
  final Function() hangUp;
  final Function() muteMic;
  final Function() answerCall;
  final bool audioMuted;
  final CallBannerType callType;

  const CallBanner(
      {super.key,
      required this.call,
      required this.answerCall,
      required this.callType,
      required this.hangUp,
      required this.muteMic,
      required this.audioMuted});

  @override
  CallBannerState createState() => CallBannerState();
}

class CallBannerState extends State<CallBanner>
    with SingleTickerProviderStateMixin {
  CallSession get call => widget.call;
  Function() get hangUp => widget.hangUp;
  Function() get muteMic => widget.muteMic;
  Function() get answerCall => widget.answerCall;
  bool get audioMuted => widget.audioMuted;
  CallBannerType get callType => widget.callType;

  late final AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(
        seconds: 30,
      ),
    )..repeat(reverse: true);

    _animation =
        Tween<double>(begin: _getBeginAndEnd() * -1, end: _getBeginAndEnd())
            .animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.linear,
      ),
    );
  }

  List<Color> _getGradientColors() {
    if (audioMuted) {
      return [
        Colors.orange,
        Colors.pink,
        Colors.deepOrange,
        Colors.pink,
      ];
    }

    if (callType == CallBannerType.connected) {
      return [
        Colors.orange,
        Colors.pink,
        Colors.purple,
        Colors.blue,
        Colors.green,
        Colors.yellow,
      ];
    } else if (callType == CallBannerType.incoming) {
      return [
        Colors.blue,
        Colors.green,
        Colors.yellow,
      ];
    } else if (callType == CallBannerType.outgoing) {
      return [
        Colors.blue,
        Colors.green,
        Colors.yellow,
        Colors.deepPurple,
      ];
    }

    return [];
  }

  List<double> _getGradientStops() {
    if (audioMuted) {
      return [
        _animation.value,
        _animation.value + 0.2,
        _animation.value + 0.4,
        _animation.value + 0.6,
      ];
    }

    if (callType == CallBannerType.connected) {
      return [
        _animation.value,
        _animation.value + 0.2,
        _animation.value + 0.4,
        _animation.value + 0.6,
        _animation.value + 0.8,
        _animation.value + 1,
      ];
    } else if (callType == CallBannerType.incoming) {
      return [
        _animation.value,
        _animation.value + 0.2,
        _animation.value + 0.4,
      ];
    } else if (callType == CallBannerType.outgoing) {
      return [
        _animation.value,
        _animation.value + 0.2,
        _animation.value + 0.4,
        _animation.value + 0.6,
      ];
    }

    return [];
  }

  double _getBeginAndEnd() {
    if (audioMuted) {
      return 0.3;
    }

    if (callType == CallBannerType.connected) {
      return 0.5;
    } else if (callType == CallBannerType.incoming) {
      return 0.2;
    } else if (callType == CallBannerType.outgoing) {
      return 0.3;
    }

    return 1;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        SizedBox(
          height: 48,
          width: double.infinity,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _getGradientColors(),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: _getGradientStops(),
                  ),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 380,
                    minWidth: 0,
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          call.room.displayname ?? '',
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(color: Colors.white),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: Row(
                          children: callType == CallBannerType.connected ||
                                  callType == CallBannerType.outgoing
                              ? [
                                  IconButton(
                                    icon: Icon(
                                      audioMuted ? Icons.mic_off : Icons.mic,
                                      color: Colors.white,
                                    ),
                                    onPressed: muteMic,
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.call_end,
                                      color: audioMuted
                                          ? Colors.white
                                          : Colors.red,
                                    ),
                                    onPressed: hangUp,
                                  ),
                                ]
                              : [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.phone,
                                      color: Colors.green,
                                    ),
                                    onPressed: answerCall,
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.call_end,
                                      color: Colors.red,
                                    ),
                                    onPressed: hangUp,
                                  ),
                                ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Divider(
          height: 1,
          color: theme.dividerColor,
        ),
      ],
    );
  }
}
