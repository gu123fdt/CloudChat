import 'dart:async';
import 'package:flutter/material.dart';

class InactivityDetector extends StatefulWidget {
  final Widget child;
  final Duration timeout;
  final VoidCallback onInactivity;

  const InactivityDetector({
    super.key,
    required this.child,
    required this.timeout,
    required this.onInactivity,
  });

  @override
  InactivityDetectorState createState() => InactivityDetectorState();
}

class InactivityDetectorState extends State<InactivityDetector> {
  Timer? _inactivityTimer;

  @override
  void initState() {
    super.initState();
    _resetTimer();
  }

  @override
  void didUpdateWidget(covariant InactivityDetector oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.timeout != widget.timeout) {
      _resetTimer();
    }
  }

  void _resetTimer() {
    _inactivityTimer?.cancel();
    if (widget.timeout > Duration.zero) {
      _inactivityTimer = Timer(widget.timeout, widget.onInactivity);
    }
  }

  void _handleUserInteraction([_]) {
    _resetTimer();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handleUserInteraction,
      onPointerMove: _handleUserInteraction,
      onPointerUp: _handleUserInteraction,
      onPointerCancel: _handleUserInteraction,
      onPointerHover: _handleUserInteraction,
      onPointerPanZoomEnd: _handleUserInteraction,
      onPointerPanZoomStart: _handleUserInteraction,
      onPointerPanZoomUpdate: _handleUserInteraction,
      onPointerSignal: _handleUserInteraction,
      child: widget.child,
    );
  }
}
