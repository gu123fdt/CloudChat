import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloudchat/config/setting_keys.dart';
import 'package:cloudchat/utils/platform_infos.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LockMethod {
  pin,
  password,
}

class AppLocker {
  AppLocker._privateConstructor();
  static final AppLocker _instance = AppLocker._privateConstructor();
  static AppLocker get instance => _instance;

  static bool isLocked = false;
  static SharedPreferences? store;

  static Function? unlockCallBack;
  static Function? lockCallBack;
  static Function? updateLockTimeoutCallBack;

  static int? getLockTimeout() {
    if (getLockApp()) {
      return store?.getInt(SettingKeys.appLockTimeoutKey) ?? 0;
    }
    return 0;
  }

  static Future<void> setLockTimeout(int? timeout) async {
    if (!getLockApp() || timeout == null || timeout == 0) {
      await store?.remove(SettingKeys.appLockTimeoutKey);
    } else {
      await store?.setInt(SettingKeys.appLockTimeoutKey, timeout);
    }

    updateLockTimeoutCallBack?.call();
  }

  static bool getLockApp() {
    if (!PlatformInfos.isWeb) {
      return store?.getString(SettingKeys.appLockKey) != null;
    } else {
      return false;
    }
  }

  static Future<void> setLockMethod(LockMethod? method, String? value) async {
    if (method == null || value == null || value.isEmpty) {
      await store?.remove(SettingKeys.appLockMethodKey);
      await store?.remove(SettingKeys.appLockKey);
      if (PlatformInfos.isMobile) {
        await const FlutterSecureStorage().delete(
          key: SettingKeys.appLockKey,
        );
      }
      return;
    }

    await store?.setInt(SettingKeys.appLockMethodKey, method.index);

    if (!PlatformInfos.isWeb) {
      await store?.setString(SettingKeys.appLockKey, value);
    }
  }

  static LockMethod? getLockMethod() {
    final methodIndex = store?.getInt(SettingKeys.appLockMethodKey);
    if (methodIndex == null) return null;
    return LockMethod.values[methodIndex];
  }

  static Future<bool> unlockApp(String value) async {
    if (getLockApp()) {
      if (!PlatformInfos.isWeb) {
        isLocked = store?.getString(SettingKeys.appLockKey) == value;
      }
    }

    if (isLocked) {
      unlockCallBack?.call();
      return true;
    } else {
      lockCallBack?.call();
      return false;
    }
  }

  static void lockApp() {
    if (getLockApp()) {
      isLocked = true;
      lockCallBack?.call();
    }
  }

  static Future<void> init(Function unlockCallBack, Function lockCallBack,
      Function updatelockTimeoutCallBack,) async {
    store = await SharedPreferences.getInstance();
    isLocked = getLockApp();
    AppLocker.unlockCallBack = unlockCallBack;
    AppLocker.lockCallBack = lockCallBack;
    AppLocker.updateLockTimeoutCallBack = updatelockTimeoutCallBack;

    if (isLocked) {
      AppLocker.lockCallBack?.call();
    }

    AppLocker.updateLockTimeoutCallBack?.call();
  }
}
