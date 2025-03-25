import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uni_links/uni_links.dart';

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
    List<String> arguments, SharedPreferences store) async {
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
    linkStream.listen((String? link) => _processUri(link, store));

    final initialLink = await getInitialLink();
    _processUri(initialLink, store);
  }
}
