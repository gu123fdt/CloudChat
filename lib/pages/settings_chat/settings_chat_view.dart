import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:cloudchat/widgets/settings_select_input_device_list_tile.dart';
import 'package:flutter/material.dart';

import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:go_router/go_router.dart';

import 'package:cloudchat/config/app_config.dart';
import 'package:cloudchat/config/setting_keys.dart';
import 'package:cloudchat/utils/platform_infos.dart';
import 'package:cloudchat/widgets/layouts/max_width_body.dart';
import 'package:cloudchat/widgets/matrix.dart';
import 'package:cloudchat/widgets/settings_select_output_device_list_tile.dart';
import 'package:cloudchat/widgets/settings_switch_list_tile.dart';
import 'settings_chat.dart';

class SettingsChatView extends StatelessWidget {
  final SettingsChatController controller;
  const SettingsChatView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(L10n.of(context).chat)),
      body: ListTileTheme(
        iconColor: theme.textTheme.bodyLarge!.color,
        child: MaxWidthBody(
          child: Column(
            children: <Widget>[
              SettingsSwitchListTile.adaptive(
                title: L10n.of(context).formattedMessages,
                subtitle: L10n.of(context).formattedMessagesDescription,
                onChanged: (b) => AppConfig.renderHtml = b,
                storeKey: SettingKeys.renderHtml,
                defaultValue: AppConfig.renderHtml,
              ),
              SettingsSwitchListTile.adaptive(
                title: L10n.of(context).hideMemberChangesInPublicChats,
                subtitle: L10n.of(context).hideMemberChangesInPublicChatsBody,
                onChanged: (b) => AppConfig.hideUnimportantStateEvents = b,
                storeKey: SettingKeys.hideUnimportantStateEvents,
                defaultValue: AppConfig.hideUnimportantStateEvents,
              ),
              SettingsSwitchListTile.adaptive(
                title: L10n.of(context).hideRedactedMessages,
                subtitle: L10n.of(context).hideRedactedMessagesBody,
                onChanged: (b) => AppConfig.hideRedactedEvents = b,
                storeKey: SettingKeys.hideRedactedEvents,
                defaultValue: AppConfig.hideRedactedEvents,
              ),
              SettingsSwitchListTile.adaptive(
                title: L10n.of(context).hideInvalidOrUnknownMessageFormats,
                onChanged: (b) => AppConfig.hideUnknownEvents = b,
                storeKey: SettingKeys.hideUnknownEvents,
                defaultValue: AppConfig.hideUnknownEvents,
              ),
              if (PlatformInfos.isMobile)
                SettingsSwitchListTile.adaptive(
                  title: L10n.of(context).autoplayImages,
                  onChanged: (b) => AppConfig.autoplayImages = b,
                  storeKey: SettingKeys.autoplayImages,
                  defaultValue: AppConfig.autoplayImages,
                ),
              SettingsSwitchListTile.adaptive(
                title: L10n.of(context).sendOnEnter,
                onChanged: (b) => AppConfig.sendOnEnter = b,
                storeKey: SettingKeys.sendOnEnter,
                defaultValue: AppConfig.sendOnEnter ?? !PlatformInfos.isMobile,
              ),
              SettingsSwitchListTile.adaptive(
                title: L10n.of(context).swipeRightToLeftToReply,
                onChanged: (b) => AppConfig.swipeRightToLeftToReply = b,
                storeKey: SettingKeys.swipeRightToLeftToReply,
                defaultValue: AppConfig.swipeRightToLeftToReply,
              ),
              Divider(color: theme.dividerColor),
              ListTile(
                title: Text(
                  L10n.of(context).customEmojisAndStickers,
                  style: TextStyle(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                title: Text(L10n.of(context).customEmojisAndStickers),
                subtitle: Text(L10n.of(context).customEmojisAndStickersBody),
                onTap: () => context.go('/rooms/settings/chat/emotes'),
                trailing: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Icon(Icons.chevron_right_outlined),
                ),
              ),
              Divider(color: theme.dividerColor),
              if (!PlatformInfos.isMobile && !PlatformInfos.isWeb) ...[
                SettingsSwitchListTile.adaptive(
                  title: L10n.of(context).autoStart,
                  onChanged: (b) async {
                    if (b) {
                      await launchAtStartup.enable();
                    } else {
                      await launchAtStartup.disable();
                    }

                    AppConfig.autoStart = await launchAtStartup.isEnabled();
                  },
                  storeKey: SettingKeys.autoStart,
                  defaultValue: AppConfig.autoStart,
                ),
                Divider(color: theme.dividerColor),
              ],
              if (!PlatformInfos.isMobile) ...[
                ListTile(
                  title: Text(
                    L10n.of(context).recording,
                    style: TextStyle(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SettingsSelectInputDeviceListTile(),
                Divider(color: theme.dividerColor),
                const SettingsSelectOutputDeviceListTile(),
                Divider(color: theme.dividerColor),
              ],
              ListTile(
                title: Text(
                  L10n.of(context).calls,
                  style: TextStyle(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SettingsSwitchListTile.adaptive(
                title: L10n.of(context).experimentalVideoCalls,
                onChanged: (b) {
                  AppConfig.experimentalVoip = b;
                  Matrix.of(context).createVoipService();
                  return;
                },
                storeKey: SettingKeys.experimentalVoip,
                defaultValue: AppConfig.experimentalVoip,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
