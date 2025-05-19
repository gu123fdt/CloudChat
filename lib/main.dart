import 'dart:io';

import 'package:flutter/services.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:cloudchat/pages/homeserver_picker/homeserver_auto_picker.dart';
import 'package:flutter/material.dart';

import 'package:collection/collection.dart';
import 'package:cloudchat/utils/app_locker/app_locker.dart';
import 'package:matrix/matrix.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloudchat/config/app_config.dart';
import 'package:cloudchat/utils/client_manager.dart';
import 'package:cloudchat/utils/platform_infos.dart';
import 'package:cloudchat/widgets/error_widget.dart';
import 'package:window_manager/window_manager.dart';
import 'utils/background_push.dart';
import 'widgets/cloud_chat_app.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:flutter_single_instance/flutter_single_instance.dart';

class MyWindowListener extends WindowListener {
  @override
  void onWindowClose() async {
    await windowManager.hide();

    AppLocker.lockApp();
  }
}

void main(List<String> arguments) async {
  Logs().i('Welcome to ${AppConfig.applicationName} <3');

  // Our background push shared isolate accesses flutter-internal things very early in the startup proccess
  // To make sure that the parts of flutter needed are started up already, we need to ensure that the
  // widget bindings are initialized already.

  WidgetsFlutterBinding.ensureInitialized();
  if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.detached) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );
  }

  if (PlatformInfos.isWindows ||
      PlatformInfos.isMacOS ||
      PlatformInfos.isLinux) {
    await windowManager.ensureInitialized();

    if (!await FlutterSingleInstance().isFirstInstance()) {
      await FlutterSingleInstance().focus();
      exit(0);
    }

    windowManager.setPreventClose(true);

    windowManager.addListener(MyWindowListener());
  }

  if (!PlatformInfos.isWeb) {
    final packageInfo = await PackageInfo.fromPlatform();
    launchAtStartup.setup(
      appName: packageInfo.appName,
      appPath: Platform.resolvedExecutable,
      packageName: AppConfig.appId,
    );
  }

  if (PlatformInfos.isWindows) {
    await localNotifier.setup(
      appName: AppConfig.applicationName,
      shortcutPolicy: ShortcutPolicy.requireCreate,
    );
  }

  if (PlatformInfos.isWindows ||
      PlatformInfos.isLinux ||
      PlatformInfos.isMacOS) {
    final windowOptions = const WindowOptions(
      minimumSize: Size(1000, 800),
      size: Size(1000, 700),
      center: true,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  Logs().nativeColors = !PlatformInfos.isIOS;
  final store = await SharedPreferences.getInstance();
  final clients = await ClientManager.getClients(store: store);

  // If the app starts in detached mode, we assume that it is in
  // background fetch mode for processing push notifications. This is
  // currently only supported on Android.
  if (PlatformInfos.isAndroid &&
      AppLifecycleState.detached == WidgetsBinding.instance.lifecycleState) {
    // Do not send online presences when app is in background fetch mode.
    for (final client in clients) {
      client.backgroundSync = false;
      client.syncPresence = PresenceType.offline;
    }

    // In the background fetch mode we do not want to waste ressources with
    // starting the Flutter engine but process incoming push notifications.
    BackgroundPush.clientOnly(clients.first);
    // To start the flutter engine afterwards we add an custom observer.
    WidgetsBinding.instance.addObserver(AppStarter(clients, store));
    Logs().i(
      '${AppConfig.applicationName} started in background-fetch mode. No GUI will be created unless the app is no longer detached.',
    );
    return;
  }

  // Started in foreground mode.
  Logs().i(
    '${AppConfig.applicationName} started in foreground mode. Rendering GUI...',
  );
  await startGui(clients, store, arguments);
}

/// Fetch the pincode for the applock and start the flutter engine.
Future<void> startGui(
  List<Client> clients,
  SharedPreferences store,
  List<String> arguments,
) async {
  // Preload first client
  final firstClient = clients.firstOrNull;
  await firstClient?.roomsLoading;
  await firstClient?.accountDataLoading;

  ErrorWidget.builder = (details) => CloudChatErrorWidget(details);
  runApp(CloudChatApp(clients: clients, store: store));
  autoLoginAccount(arguments, store);
}

/// Watches the lifecycle changes to start the application when it
/// is no longer detached.
class AppStarter with WidgetsBindingObserver {
  final List<Client> clients;
  final SharedPreferences store;
  bool guiStarted = false;

  AppStarter(this.clients, this.store);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    if (guiStarted) return;
    if (state == AppLifecycleState.detached) return;

    Logs().i(
      '${AppConfig.applicationName} switches from the detached background-fetch mode to ${state.name} mode. Rendering GUI...',
    );
    // Switching to foreground mode needs to reenable send online sync presence.
    for (final client in clients) {
      client.backgroundSync = true;
      client.syncPresence = PresenceType.online;
    }
    startGui(clients, store, []);
    // We must make sure that the GUI is only started once.
    guiStarted = true;
  }
}
