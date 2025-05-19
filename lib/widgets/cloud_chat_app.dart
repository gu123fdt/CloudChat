import 'package:cloudchat/pages/chat_updater/update_banner_controller.dart';
import 'package:cloudchat/pages/chat_updater/update_banner_wrapper.dart';
import 'package:cloudchat/widgets/call_banner_controller.dart';
import 'package:cloudchat/widgets/wrapper_banner_wrapper.dart';
import 'package:cloudchat/utils/locale_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloudchat/config/routes.dart';
import 'package:cloudchat/config/themes.dart';
import 'package:cloudchat/widgets/app_lock.dart';
import 'package:cloudchat/widgets/theme_builder.dart';
import '../config/app_config.dart';
import '../utils/custom_scroll_behaviour.dart';
import 'matrix.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class CloudChatApp extends StatelessWidget {
  final Widget? testWidget;
  final List<Client> clients;
  final SharedPreferences store;

  const CloudChatApp({
    super.key,
    this.testWidget,
    required this.clients,
    required this.store,
  });

  static bool gotInitialLink = false;

  static final GoRouter router = GoRouter(
    routes: AppRoutes.routes,
    debugLogDiagnostics: true,
    navigatorKey: navigatorKey,
  );

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => CallBannerController()),
        ChangeNotifierProvider(create: (_) => UpdateBannerController()),
      ],
      child: ThemeBuilder(
        builder:
            (context, themeMode, primaryColor) => MaterialApp.router(
              title: AppConfig.applicationName,
              themeMode: themeMode,
              theme: CloudThemes.buildTheme(
                context,
                Brightness.light,
                primaryColor,
              ),
              darkTheme: CloudThemes.buildTheme(
                context,
                Brightness.dark,
                primaryColor,
              ),
              scrollBehavior: CustomScrollBehavior(),
              locale: Provider.of<LocaleProvider>(context).locale,
              localizationsDelegates: L10n.localizationsDelegates,
              supportedLocales: L10n.supportedLocales,
              routerConfig: router,
              builder:
                  (context, child) => UpdateBannerWrapper(
                    child: CallBannerWrapper(
                      child: AppLockWidget(
                        clients: clients,
                        child: Builder(
                          builder: (context) {
                            return Matrix(
                              clients: clients,
                              store: store,
                              child: testWidget ?? child,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
            ),
      ),
    );
  }
}
