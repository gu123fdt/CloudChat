import 'package:flutter/material.dart';
import 'package:cloudchat/config/themes.dart';

class ResizableWidget extends StatefulWidget {
  final Widget child;
  final double minWidthPercent;
  final double maxWidthPercent;
  final double initialWidthPercent;
  final double screenWidth;
  final bool? active;

  const ResizableWidget({
    super.key,
    required this.child,
    required this.minWidthPercent,
    required this.maxWidthPercent,
    required this.initialWidthPercent,
    required this.screenWidth,
    this.active,
  });

  @override
  _ResizableWidgetState createState() => _ResizableWidgetState();
}

class _ResizableWidgetState extends State<ResizableWidget>
    with WidgetsBindingObserver {
  late double currentWidthPercent;
  double _width = 1;

  @override
  void initState() {
    super.initState();
    currentWidthPercent = widget.initialWidthPercent;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    Future.delayed(
        CloudThemes.animationDuration + const Duration(milliseconds: 1), () {
      setState(() {
        currentWidthPercent = currentWidthPercent.clamp(
            widget.minWidthPercent, widget.maxWidthPercent,);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentWidthInPixels =
        widget.screenWidth * (currentWidthPercent / 100);

    return Row(
      children: [
        SizedBox(
          width: widget.active == false
              ? widget.screenWidth
              : currentWidthInPixels,
          child: widget.child,
        ),
        if (widget.active != false)
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragUpdate: (details) {
              setState(() {
                final deltaPercent =
                    details.primaryDelta! / widget.screenWidth * 100;
                currentWidthPercent += deltaPercent;
                currentWidthPercent = currentWidthPercent.clamp(
                    widget.minWidthPercent, widget.maxWidthPercent,);
                _width = 6;
              });
            },
            onHorizontalDragStart: (_) {
              setState(() {
                _width = 6;
              });
            },
            onHorizontalDragEnd: (_) {
              setState(() {
                _width = 1;
              });
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              onEnter: (_) {
                setState(() {
                  _width = 6;
                });
              },
              onExit: (_) {
                setState(() {
                  _width = 1;
                });
              },
              child: SizedBox(
                width: 6,
                height: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: _width,
                      color: Theme.of(context).dividerColor,
                      height: double.infinity,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
