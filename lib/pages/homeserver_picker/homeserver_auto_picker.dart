import 'dart:io';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';

void _processUri(String? url, SharedPreferences store) {
  if (url != null) {
    try {
      final uri = Uri.parse(url);
      final loginToken = uri.queryParameters['loginToken'];
      final homeserver = uri.queryParameters['homeserver'];

      if (loginToken != null && homeserver != null) {
        store.setString("autoLoginToken", loginToken);
        store.setString("autoLoginHomeserver", homeserver);
      } else {
        _clearStoredLogin(store);
      }
    } catch (_) {
      _clearStoredLogin(store);
    }
  } else {
    _clearStoredLogin(store);
  }
}

void _clearStoredLogin(SharedPreferences store) {
  store.remove("autoLoginToken");
  store.remove("autoLoginHomeserver");
}

Future<void> autoLoginAccount(
  List<String> arguments,
  SharedPreferences store,
) async {
  if (Platform.isWindows) {
    if (arguments.isNotEmpty) {
      final urlArgument = arguments.firstWhere(
        (arg) => arg.startsWith('--url='),
        orElse: () => '',
      );

      if (urlArgument.isNotEmpty) {
        final urlString = urlArgument.replaceFirst('--url=', '');
        _processUri(urlString, store);
      } else {
        _clearStoredLogin(store);
      }
    } else {
      _clearStoredLogin(store);
    }
  } else if (Platform.isAndroid || Platform.isIOS) {
    AppLinks()
        .uriLinkStream
        .listen((Uri? uri) => _processUri(uri.toString(), store));

    final initialLink = await AppLinks().getInitialLinkString();
    _processUri(initialLink, store);
  }
}
