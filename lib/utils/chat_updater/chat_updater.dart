import 'dart:async';
import 'dart:io';

import 'package:cloudchat/config/app_config.dart';
import 'package:cloudchat/utils/platform_infos.dart';
import 'package:matrix/matrix_api_lite/utils/logs.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ServerVersionInfo {
  final String version;
  final Map<String, String> versions;

  ServerVersionInfo({required this.version, required this.versions});

  factory ServerVersionInfo.fromJson(Map<String, dynamic> json) {
    return ServerVersionInfo(
      version: json['version'],
      versions: Map<String, String>.from(json['versions']),
    );
  }
}

class ChatUpdater {
  ChatUpdater._privateConstructor();
  static final ChatUpdater _instance = ChatUpdater._privateConstructor();
  static ChatUpdater get instance => _instance;
  static ServerVersionInfo? serverVersions;
  static bool _isInit = false;
  static Function _showBanner = () => {};
  static Function _clouseBanner = () => {};

  static Future<ServerVersionInfo?> _getServerVersion() async {
    Logs().i("[UPDATER] Get server version");
    final response =
        await http.get(Uri.parse("${AppConfig.updateServerUrl}/versions.json"));

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return ServerVersionInfo.fromJson(data);
    }
    Logs().i("[UPDATER] Error get server version");
    return null;
  }

  static Future<bool> _downloadInstaller(String url, String filePath) async {
    Logs().i("[UPDATER] Start download new installer");

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        
        Logs().i("[UPDATER] Success download new installer");

        return true;
      } else {
        Logs().e("[UPDATER] Error download new installer");

        return false;
      }
    } catch (e) {
      Logs().e("[UPDATER] Error download new installer: $e");
      return false;
    }
  }

  static Future<void> startUpdate() async {
    try {
      if (PlatformInfos.isWindows) {
        final tempDirectory = await getTemporaryDirectory();
        final installersDir = Directory('${tempDirectory.path}\\installers');
        final filePath =
            '${tempDirectory.path}\\installers\\${serverVersions!.versions["windows"]!}';
        final downloadUrl =
            "${AppConfig.updateServerUrl}/installers/${serverVersions!.versions["windows"]!}";

        if (!installersDir.existsSync()) {
          installersDir.createSync(recursive: true);
        }

        if (await _downloadInstaller(downloadUrl, filePath)) {
          final file = File(filePath);
          final directory = file.parent;
          final fileName = file.path.split(Platform.pathSeparator).last;
          final newFileName = fileName.split('-')[0] + '.exe';
          final newPath = '${directory.path}${Platform.pathSeparator}$newFileName';
          await file.rename(newPath);

          Logs().i("[UPDATER] Start installer");
          await Process.start(newPath, []);

          Logs().i("[UPDATER] Exit from chat");
          exit(0);
        } else {}
      } else if (PlatformInfos.isMacOS) {
      } else if (PlatformInfos.isLinux) {
      } else {}
    } catch (e) {}
  }

  static Future<void> _endUpdate() async {
    Logs().i("[UPDATER] Delete all installers");

    try {
      final tempDirectory = await getTemporaryDirectory();
      final directory = Directory('${tempDirectory.path}/installers');

      if (await directory.exists()) {
        final files = directory.listSync();
        for (var file in files) {
          if (file is File) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      Logs().e('[UPDATER] Error deleting installers: $e');
    }
  }

  static Future<void> _checkUpdate() async {
    Logs().i("[UPDATER] Start check update");
    final currentVersion = (await PackageInfo.fromPlatform()).version;
    serverVersions = await _getServerVersion();

    Logs().i("[UPDATER] Current version: $currentVersion");
    Logs().i("[UPDATER] Server version: ${serverVersions?.version}");

    if (serverVersions == null) return _clouseBanner();

    if (currentVersion != serverVersions?.version) {
      _showBanner();
    } else {
      Logs().i("[UPDATER] No new versions");
      _clouseBanner();
      await _endUpdate();
    }
  }

  static Future<void> _startUpdateChecker() async {
    await _checkUpdate();

    Timer.periodic(const Duration(seconds: 60), (timer) {
      _checkUpdate();
    });
  }

  static void init(Function showBanner, Function clouseBanner) async {
    if (_isInit == false && PlatformInfos.isDesktop) {
      _isInit = true;
      _showBanner = showBanner;
      _clouseBanner = clouseBanner;
      _startUpdateChecker();
    }
  }
}
