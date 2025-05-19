import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloudchat/utils/voip/voip_sturtup.dart';
import 'package:cloudchat/utils/highlights_rooms_and_threads.dart';
import 'package:cloudchat/utils/thread_unread_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:collection/collection.dart';
import 'package:desktop_notifications/desktop_notifications.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cloudchat/utils/voip/call_manager.dart';
import 'package:cloudchat/utils/voip/sound_service.dart';
import 'package:cloudchat/utils/voip/voip_service.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:universal_html/html.dart' as html;
import 'package:url_launcher/url_launcher_string.dart';

import 'package:cloudchat/utils/client_manager.dart';
import 'package:cloudchat/utils/init_with_restore.dart';
import 'package:cloudchat/utils/matrix_sdk_extensions/matrix_file_extension.dart';
import 'package:cloudchat/utils/platform_infos.dart';
import 'package:cloudchat/utils/uia_request_manager.dart';
import 'package:cloudchat/widgets/cloud_chat_app.dart';
import 'package:cloudchat/widgets/future_loading_dialog.dart';
import 'package:window_manager/window_manager.dart';
import 'package:windows_taskbar/windows_taskbar.dart';
import '../config/app_config.dart';
import '../config/setting_keys.dart';
import '../pages/key_verification/key_verification_dialog.dart';
import '../utils/account_bundles.dart';
import '../utils/background_push.dart';
import 'local_notifications_extension.dart';

// import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Matrix extends StatefulWidget {
  final Widget? child;

  final List<Client> clients;

  final Map<String, String>? queryParameters;

  final SharedPreferences store;

  const Matrix({
    this.child,
    required this.clients,
    required this.store,
    this.queryParameters,
    super.key,
  });

  @override
  MatrixState createState() => MatrixState();

  /// Returns the (nearest) Client instance of your application.
  static MatrixState of(BuildContext context) =>
      Provider.of<MatrixState>(context, listen: false);
}

class MatrixState extends State<Matrix>
    with TrayListener, WidgetsBindingObserver {
  int _activeClient = -1;
  String? activeBundle;

  ThreadUnreadData threadUnreadData = ThreadUnreadData();

  SharedPreferences get store => widget.store;

  XFile? loginAvatar;
  String? loginUsername;
  bool? loginRegistrationSupported;

  BackgroundPush? backgroundPush;

  StreamSubscription? unreadCountSubscription;

  Client get client {
    if (widget.clients.isEmpty) {
      widget.clients.add(getLoginClient());
    }
    if (_activeClient < 0 || _activeClient >= widget.clients.length) {
      final lastClient = store.getInt("lastClient");

      if (lastClient != null && widget.clients.length - 1 >= lastClient) {
        _activeClient = lastClient;
        return widget.clients[lastClient];
      }

      return currentBundle!.first!;
    }
    return widget.clients[_activeClient];
  }

  CallManager? callManager;
  VoIPService? voIPService;
  SoundService? soundService;

  bool get isMultiAccount => widget.clients.length > 1;

  int getClientIndexByMatrixId(String matrixId) =>
      widget.clients.indexWhere((client) => client.userID == matrixId);

  late String currentClientSecret;
  RequestTokenResponse? currentThreepidCreds;

  void setMarker() async {
    if (PlatformInfos.isMobile) return;

    final unreadCount =
        client.rooms
            .where((r) => (r.isUnread || r.membership == Membership.invite))
            .length;

    if (PlatformInfos.isWindows) {
      if (unreadCount == 0) {
        WindowsTaskbar.resetOverlayIcon();

        await trayManager.setIcon(
          Platform.isWindows ? 'assets/logo.ico' : 'assets/logo.png',
        );
      } else {
        if (unreadCount < 10) {
          WindowsTaskbar.setOverlayIcon(
            ThumbnailToolbarAssetIcon('assets/$unreadCount.ico'),
            tooltip: 'Stop',
          );
        } else {
          WindowsTaskbar.setOverlayIcon(
            ThumbnailToolbarAssetIcon('assets/10.ico'),
            tooltip: 'Stop',
          );
        }

        await trayManager.setIcon(
          Platform.isWindows ? 'assets/logoN.ico' : 'assets/logoN.png',
        );
      }
    }
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    if (menuItem.key == 'show_window') {
      await windowManager.show();
    } else if (menuItem.key == 'exit_app') {
      exit(0);
    }
  }

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
  }

  @override
  void onTrayIconRightMouseUp() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  void setUnreadCount() async {
    await unreadCountSubscription?.cancel();

    setMarker();

    unreadCountSubscription = client.onSync.stream
        .where((syncUpdate) => syncUpdate.hasRoomUpdate)
        .listen((syncUpdate) {
          setMarker();
        });
  }

  void setActiveClient(Client? cl) {
    final i = widget.clients.indexWhere((c) => c == cl);
    if (i != -1) {
      _activeClient = i;
      store.setInt("lastClient", i);

      // TODO: Multi-client VoiP support
      createVoipService();
      setUnreadCount();

      HighlightsRoomsAndThreads().init(this);
    } else {
      Logs().w('Tried to set an unknown client ${cl!.userID} as active');
    }
  }

  List<Client?>? get currentBundle {
    if (!hasComplexBundles) {
      return List.from(widget.clients);
    }
    final bundles = accountBundles;
    if (bundles.containsKey(activeBundle)) {
      return bundles[activeBundle];
    }
    return bundles.values.first;
  }

  Map<String?, List<Client?>> get accountBundles {
    final resBundles = <String?, List<_AccountBundleWithClient>>{};
    for (var i = 0; i < widget.clients.length; i++) {
      final bundles = widget.clients[i].accountBundles;
      for (final bundle in bundles) {
        if (bundle.name == null) {
          continue;
        }
        resBundles[bundle.name] ??= [];
        resBundles[bundle.name]!.add(
          _AccountBundleWithClient(client: widget.clients[i], bundle: bundle),
        );
      }
    }
    for (final b in resBundles.values) {
      b.sort(
        (a, b) =>
            a.bundle!.priority == null
                ? 1
                : b.bundle!.priority == null
                ? -1
                : a.bundle!.priority!.compareTo(b.bundle!.priority!),
      );
    }
    return resBundles.map(
      (k, v) => MapEntry(k, v.map((vv) => vv.client).toList()),
    );
  }

  bool get hasComplexBundles => accountBundles.values.any((v) => v.length > 1);

  Client? _loginClientCandidate;

  Client getLoginClient() {
    if (widget.clients.isNotEmpty && !client.isLogged()) {
      return client;
    }
    final candidate =
        _loginClientCandidate ??= ClientManager.createClient(
            '${AppConfig.applicationName}-${DateTime.now().millisecondsSinceEpoch}',
          )
          ..onLoginStateChanged.stream
              .where((l) => l == LoginState.loggedIn)
              .first
              .then((_) {
                if (!widget.clients.contains(_loginClientCandidate)) {
                  widget.clients.add(_loginClientCandidate!);
                }
                ClientManager.addClientNameToStore(
                  _loginClientCandidate!.clientName,
                  store,
                );
                _registerSubs(_loginClientCandidate!.clientName);
                _loginClientCandidate = null;
                CloudChatApp.router.go('/rooms');
              });
    return candidate;
  }

  Client? getClientByName(String name) =>
      widget.clients.firstWhereOrNull((c) => c.clientName == name);

  final onRoomKeyRequestSub = <String, StreamSubscription>{};
  final onKeyVerificationRequestSub = <String, StreamSubscription>{};
  final onNotification = <String, StreamSubscription>{};
  final onLoginStateChanged = <String, StreamSubscription<LoginState>>{};
  final onUiaRequest = <String, StreamSubscription<UiaRequest>>{};
  StreamSubscription<html.Event>? onFocusSub;
  StreamSubscription<html.Event>? onBlurSub;

  String? _cachedPassword;
  Timer? _cachedPasswordClearTimer;

  String? get cachedPassword => _cachedPassword;

  set cachedPassword(String? p) {
    Logs().d('Password cached');
    _cachedPasswordClearTimer?.cancel();
    _cachedPassword = p;
    _cachedPasswordClearTimer = Timer(const Duration(minutes: 10), () {
      _cachedPassword = null;
      Logs().d('Cached Password cleared');
    });
  }

  bool webHasFocus = true;

  String? get activeRoomId {
    final route = CloudChatApp.router.routeInformationProvider.value.uri.path;
    if (!route.startsWith('/rooms/')) return null;
    return route.split('/')[2];
  }

  final linuxNotifications =
      PlatformInfos.isLinux ? NotificationsClient() : null;
  final Map<String, int> linuxNotificationIds = {};

  @override
  void initState() {
    super.initState();
    if (PlatformInfos.isDesktop) {
      trayManager.addListener(this);
      _initializeTray();
    }
    WidgetsBinding.instance.addObserver(this);
    initMatrix();
    if (PlatformInfos.isWeb) {
      initConfig().then((_) => initSettings());
    } else {
      initSettings();
    }
    setUnreadCount();
    HighlightsRoomsAndThreads().init(this);
  }

  Future<void> _initializeTray() async {
    await trayManager.setIcon(
      Platform.isWindows ? 'assets/logo.ico' : 'assets/logo.png',
    );

    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show_window', label: 'Show'),
          MenuItem(key: 'exit_app', label: 'Exit'),
        ],
      ),
    );
  }

  String autoLoginAccountRedirect() {
    if (store.getString("autoLoginToken") != null &&
        store.getString("autoLoginHomeserver") != null) {
      if (widget.clients.isNotEmpty) {
        return "/rooms/settings/addaccount";
      } else {
        return "/home";
      }
    } else {
      return client.isLogged() ? '/rooms' : '/home';
    }
  }

  bool isAutoLoginAccountDetect() {
    return store.getString("autoLoginToken") != null &&
        store.getString("autoLoginHomeserver") != null;
  }

  Future<void> initConfig() async {
    try {
      final configJsonString = utf8.decode(
        (await http.get(Uri.parse('config.json'))).bodyBytes,
      );
      final configJson = json.decode(configJsonString);
      AppConfig.loadFromJson(configJson);
    } on FormatException catch (_) {
      Logs().v('[ConfigLoader] config.json not found');
    } catch (e) {
      Logs().v('[ConfigLoader] config.json not found', e);
    }
  }

  Future<bool> checkHomeserverIsSupportedRegistration() async {
    try {
      await getLoginClient().register();
    } on MatrixException catch (e) {
      if (e.session == null || e.authenticationFlows == null) {
        return false;
      } else {
        if (e.authenticationFlows![0].stages.contains(
              "m.login.email.identity",
            ) &&
            e.authenticationFlows![0].stages.length == 1) {
          return true;
        }
      }
    }

    return false;
  }

  void _registerSubs(String name) {
    final c = getClientByName(name);
    if (c == null) {
      Logs().w(
        'Attempted to register subscriptions for non-existing client $name',
      );
      return;
    }
    onRoomKeyRequestSub[name] ??= c.onRoomKeyRequest.stream.listen((
      RoomKeyRequest request,
    ) async {
      Logs().i('[Key Request] Get request ${request.requestingDevice.userId}');
      await request.forwardKey();
      /*if (widget.clients.any(
        ((cl) =>
            cl.userID == request.requestingDevice.userId &&
            cl.identityKey == request.requestingDevice.curve25519Key),
      )) {
        Logs().i(
          '[Key Request] Request is from one of our own clients, forwarding the key...',
        );
        await request.forwardKey();
      }*/
    });
    onKeyVerificationRequestSub[name] ??= c.onKeyVerificationRequest.stream
        .listen((KeyVerification request) async {
          var hidPopup = false;
          request.onUpdate = () {
            if (!hidPopup &&
                {
                  KeyVerificationState.done,
                  KeyVerificationState.error,
                }.contains(request.state)) {
              CloudChatApp.router.pop('dialog');
            }
            hidPopup = true;
          };
          request.onUpdate = null;
          hidPopup = true;
          await KeyVerificationDialog(request: request).show(
            CloudChatApp.router.routerDelegate.navigatorKey.currentContext ??
                context,
          );
        });
    onLoginStateChanged[name] ??= c.onLoginStateChanged.stream.listen((state) {
      final loggedInWithMultipleClients = widget.clients.length > 1;
      if (state == LoginState.loggedOut) {
        InitWithRestoreExtension.deleteSessionBackup(name);
      }
      if (loggedInWithMultipleClients && state != LoginState.loggedIn) {
        _cancelSubs(c.clientName);
        widget.clients.remove(c);
        ClientManager.removeClientNameFromStore(c.clientName, store);
        ScaffoldMessenger.of(
          CloudChatApp.router.routerDelegate.navigatorKey.currentContext ??
              context,
        ).showSnackBar(
          SnackBar(content: Text(L10n.of(context).oneClientLoggedOut)),
        );

        if (state != LoginState.loggedIn) {
          CloudChatApp.router.go('/rooms');
        }
      } else {
        CloudChatApp.router.go(
          state == LoginState.loggedIn ? '/rooms' : '/home',
        );
      }
    });
    onUiaRequest[name] ??= c.onUiaRequest.stream.listen(uiaRequestHandler);
    if (PlatformInfos.isWeb ||
        PlatformInfos.isLinux ||
        PlatformInfos.isWindows) {
      c.onSync.stream.first.then((s) {
        html.Notification.requestPermission();
        onNotification[name] ??= c.onEvent.stream
            .where(
              (e) =>
                  e.type == EventUpdateType.timeline &&
                  [
                    EventTypes.Message,
                    EventTypes.Sticker,
                    EventTypes.Encrypted,
                  ].contains(e.content['type']) &&
                  e.content['sender'] != c.userID,
            )
            .listen(showLocalNotification);
      });
    }
  }

  void _cancelSubs(String name) {
    onRoomKeyRequestSub[name]?.cancel();
    onRoomKeyRequestSub.remove(name);
    onKeyVerificationRequestSub[name]?.cancel();
    onKeyVerificationRequestSub.remove(name);
    onLoginStateChanged[name]?.cancel();
    onLoginStateChanged.remove(name);
    onNotification[name]?.cancel();
    onNotification.remove(name);
  }

  void initMatrix() {
    for (final c in widget.clients) {
      _registerSubs(c.clientName);
    }

    if (kIsWeb) {
      onFocusSub = html.window.onFocus.listen((_) => webHasFocus = true);
      onBlurSub = html.window.onBlur.listen((_) => webHasFocus = false);
    }

    if (PlatformInfos.isMobile) {
      backgroundPush = BackgroundPush(
        this,
        onFcmError: (errorMsg, {Uri? link}) async {
          final result = await showOkCancelAlertDialog(
            barrierDismissible: true,
            context:
                CloudChatApp
                    .router
                    .routerDelegate
                    .navigatorKey
                    .currentContext ??
                context,
            title: L10n.of(context).pushNotificationsNotAvailable,
            message: errorMsg,
            fullyCapitalizedForMaterial: false,
            okLabel:
                link == null ? L10n.of(context).ok : L10n.of(context).learnMore,
            cancelLabel: L10n.of(context).doNotShowAgain,
          );
          if (result == OkCancelResult.ok && link != null) {
            launchUrlString(
              link.toString(),
              mode: LaunchMode.externalApplication,
            );
          }
          if (result == OkCancelResult.cancel) {
            await store.setBool(SettingKeys.showNoGoogle, true);
          }
        },
      );
    }

    createVoipService();
  }

  void createVoipService() async {
    if (backgroundPush?.voIPService != null) {
      voIPService = backgroundPush?.voIPService;
      backgroundPush?.soundService?.setStore(store);
      soundService = backgroundPush?.soundService;
      callManager = backgroundPush?.callManager;
      return;
    }

    voIPService = VoIPService(client);
    soundService = SoundService(store);
    callManager = CallManager(voIPService!, soundService!);

    VoIPStartup.start(voIPService!, callManager!);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    Logs().v('AppLifecycleState = $state');
    final foreground =
        state != AppLifecycleState.inactive &&
        state != AppLifecycleState.paused;
    client.syncPresence =
        state == AppLifecycleState.resumed ? null : PresenceType.unavailable;
    if (PlatformInfos.isMobile) {
      client.backgroundSync = foreground;
      client.requestHistoryOnLimitedTimeline = !foreground;
      Logs().v('Set background sync to', foreground);
    }
  }

  void initSettings() {
    AppConfig.fontSizeFactor =
        double.tryParse(store.getString(SettingKeys.fontSizeFactor) ?? '') ??
        AppConfig.fontSizeFactor;

    AppConfig.renderHtml =
        store.getBool(SettingKeys.renderHtml) ?? AppConfig.renderHtml;

    AppConfig.swipeRightToLeftToReply =
        store.getBool(SettingKeys.swipeRightToLeftToReply) ??
        AppConfig.swipeRightToLeftToReply;

    AppConfig.hideRedactedEvents =
        store.getBool(SettingKeys.hideRedactedEvents) ??
        AppConfig.hideRedactedEvents;

    AppConfig.hideUnknownEvents =
        store.getBool(SettingKeys.hideUnknownEvents) ??
        AppConfig.hideUnknownEvents;

    AppConfig.hideUnimportantStateEvents =
        store.getBool(SettingKeys.hideUnimportantStateEvents) ??
        AppConfig.hideUnimportantStateEvents;

    AppConfig.separateChatTypes =
        store.getBool(SettingKeys.separateChatTypes) ??
        AppConfig.separateChatTypes;

    AppConfig.autoplayImages =
        store.getBool(SettingKeys.autoplayImages) ?? AppConfig.autoplayImages;

    AppConfig.sendTypingNotifications =
        store.getBool(SettingKeys.sendTypingNotifications) ??
        AppConfig.sendTypingNotifications;

    AppConfig.sendPublicReadReceipts =
        store.getBool(SettingKeys.sendPublicReadReceipts) ??
        AppConfig.sendPublicReadReceipts;

    AppConfig.sendOnEnter =
        store.getBool(SettingKeys.sendOnEnter) ?? AppConfig.sendOnEnter;

    AppConfig.experimentalVoip =
        store.getBool(SettingKeys.experimentalVoip) ??
        AppConfig.experimentalVoip;

    AppConfig.showPresences =
        store.getBool(SettingKeys.showPresences) ?? AppConfig.showPresences;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    onRoomKeyRequestSub.values.map((s) => s.cancel());
    onKeyVerificationRequestSub.values.map((s) => s.cancel());
    onLoginStateChanged.values.map((s) => s.cancel());
    onNotification.values.map((s) => s.cancel());
    client.httpClient.close();
    onFocusSub?.cancel();
    onBlurSub?.cancel();

    linuxNotifications?.close();
    unreadCountSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Provider(create: (_) => this, child: widget.child);
  }

  Future<void> dehydrateAction(BuildContext context) async {
    final response = await showOkCancelAlertDialog(
      context: context,
      isDestructiveAction: true,
      title: L10n.of(context).dehydrate,
      message: L10n.of(context).dehydrateWarning,
    );
    if (response != OkCancelResult.ok) {
      return;
    }
    final result = await showFutureLoadingDialog(
      context: context,
      future: client.exportDump,
    );
    final export = result.result;
    if (export == null) return;

    final exportBytes = Uint8List.fromList(const Utf8Codec().encode(export));

    final exportFileName =
        'cloudchat-export-${DateFormat(DateFormat.YEAR_MONTH_DAY).format(DateTime.now())}.cloudbackup';

    final file = MatrixFile(bytes: exportBytes, name: exportFileName);
    file.save(context);
  }
}

class _AccountBundleWithClient {
  final Client? client;
  final AccountBundle? bundle;

  _AccountBundleWithClient({this.client, this.bundle});
}
