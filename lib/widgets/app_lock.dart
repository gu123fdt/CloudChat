import 'package:flutter/material.dart';

import 'package:cloudchat/utils/app_locker/app_locker.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:cloudchat/widgets/lock_screen.dart';
import 'package:idle_detector_wrapper/idle_detector_wrapper.dart';
import 'package:cloudchat/widgets/lock_screen.dart';

import 'inactivity_detector.dart';

class AppLockWidget extends StatefulWidget {
  const AppLockWidget({
    required this.child,
    required this.clients,
    super.key,
  });

  final List<Client> clients;
  final Widget child;

  @override
  State<AppLockWidget> createState() => AppLock();
}

class AppLock extends State<AppLockWidget> with WidgetsBindingObserver {
  bool _isLocked = false;
  bool _paused = false;
  bool get isActive => AppLocker.getLockApp() == true && !_paused;

  Duration? _lockTimeout;

  @override
  void initState() {
    super.initState();
    _isLocked = isActive;
    AppLocker.init(
      () {
        setState(() {
          _isLocked = false;
        });
      },
      () {
        setState(() {
          _isLocked = true;
        });
      },
      () {
        setState(() {
          _lockTimeout = Duration(minutes: AppLocker.getLockTimeout() ?? 0);
        });
      },
    );
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback(_checkLoggedIn);
  }

  void _checkLoggedIn(_) async {
    if (widget.clients.any((client) => client.isLogged())) return;

    await AppLocker.setLockMethod(null, null);
    setState(() {
      _isLocked = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (isActive &&
        state == AppLifecycleState.hidden &&
        !_isLocked &&
        isActive) {
      showLockScreen();
    }
  }

  bool get isLocked => _isLocked;

  void showLockScreen() => setState(() {
        _isLocked = true;
      });

  Future<T> pauseWhile<T>(Future<T> future) async {
    _paused = true;
    try {
      return await future;
    } finally {
      _paused = false;
    }
  }

  static AppLock of(BuildContext context) => Provider.of<AppLock>(
        context,
        listen: false,
      );

  @override
  Widget build(BuildContext context) => Provider<AppLock>(
        create: (_) => this,
        child: InactivityDetector(
          timeout: _lockTimeout ?? Duration.zero,
          onInactivity: () {
            if (AppLocker.getLockApp() &&
                AppLocker.getLockTimeout() != 0 &&
                _lockTimeout != null) {
              AppLocker.lockApp();
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.child,
              if (isLocked) const LockScreen(),
            ],
          ),
        ),
      );
}
