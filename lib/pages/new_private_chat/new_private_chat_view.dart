import 'package:flutter/material.dart';

import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

import 'package:cloudchat/config/app_config.dart';
import 'package:cloudchat/config/themes.dart';
import 'package:cloudchat/pages/new_private_chat/new_private_chat.dart';
import 'package:cloudchat/utils/localized_exception_extension.dart';
import 'package:cloudchat/utils/platform_infos.dart';
import 'package:cloudchat/utils/url_launcher.dart';
import 'package:cloudchat/widgets/avatar.dart';
import 'package:cloudchat/widgets/layouts/max_width_body.dart';
import 'package:cloudchat/widgets/matrix.dart';

class NewPrivateChatView extends StatelessWidget {
  final NewPrivateChatController controller;

  const NewPrivateChatView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final searchResponse = controller.searchResponse;
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        leading: const Center(child: BackButton()),
        title: Text(L10n.of(context).newChat),
        backgroundColor: theme.scaffoldBackgroundColor,
        actions: [
          TextButton(
            onPressed:
                UrlLauncher(context, AppConfig.startChatTutorial).launchUrl,
            child: Text(L10n.of(context).help),
          ),
        ],
      ),
      body: MaxWidthBody(
        withScrolling: false,
        innerPadding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: TextField(
                controller: controller.controller,
                onChanged: controller.searchUsers,
                decoration: InputDecoration(
                  hintText: L10n.of(context).searchForUsers,
                  filled: true,
                  fillColor: theme.colorScheme.secondaryContainer,
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.normal,
                  ),
                  prefixIcon: searchResponse == null
                      ? const Icon(Icons.search_outlined)
                      : FutureBuilder(
                          future: searchResponse,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState !=
                                ConnectionState.done) {
                              return const Padding(
                                padding: EdgeInsets.all(10.0),
                                child: SizedBox.square(
                                  dimension: 24,
                                  child: CircularProgressIndicator.adaptive(
                                    strokeWidth: 1,
                                  ),
                                ),
                              );
                            }
                            return const Icon(Icons.search_outlined);
                          },
                        ),
                  suffixIcon: controller.controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear_outlined),
                          onPressed: () {
                            controller.controller.clear();
                            controller.searchUsers();
                          },
                        ),
                ),
              ),
            ),
            Expanded(
              child: AnimatedCrossFade(
                duration: CloudThemes.animationDuration,
                crossFadeState: searchResponse == null
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18.0),
                      child: SelectableText.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: L10n.of(context).yourGlobalUserIdIs,
                            ),
                            TextSpan(
                              text: Matrix.of(context).client.userID,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.secondaryContainer,
                        foregroundColor: theme.colorScheme.onSecondaryContainer,
                        child: Icon(Icons.adaptive.share_outlined),
                      ),
                      title: Text(L10n.of(context).shareInviteLink),
                      onTap: controller.inviteAction,
                    ),
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.tertiaryContainer,
                        foregroundColor: theme.colorScheme.onTertiaryContainer,
                        child: const Icon(Icons.group_add_outlined),
                      ),
                      title: Text(L10n.of(context).createGroup),
                      onTap: () => context.go('/rooms/newgroup'),
                    ),
                    if (PlatformInfos.isMobile)
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          foregroundColor: theme.colorScheme.onPrimaryContainer,
                          child: const Icon(Icons.qr_code_scanner_outlined),
                        ),
                        title: Text(L10n.of(context).scanQrCode),
                        onTap: controller.openScannerAction,
                      ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(64.0),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 256),
                          child: Material(
                            borderRadius: BorderRadius.circular(12),
                            elevation: 10,
                            color: Colors.white,
                            shadowColor: theme.appBarTheme.shadowColor,
                            clipBehavior: Clip.antiAliasWithSaveLayer,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: PrettyQrView.data(
                                data:
                                    'https://matrix.to/#/${Matrix.of(context).client.userID}',
                                decoration: PrettyQrDecoration(
                                  shape: PrettyQrSmoothSymbol(
                                    roundFactor: 1,
                                    color: theme.brightness == Brightness.light
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                secondChild: FutureBuilder(
                  future: searchResponse,
                  builder: (context, snapshot) {
                    final result = snapshot.data;
                    final error = snapshot.error;
                    if (error != null) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            error.toLocalizedString(context),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: theme.colorScheme.error,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: controller.searchUsers,
                            icon: const Icon(Icons.refresh_outlined),
                            label: Text(L10n.of(context).tryAgain),
                          ),
                        ],
                      );
                    }
                    if (result == null) {
                      return const Center(
                        child: CircularProgressIndicator.adaptive(),
                      );
                    }
                    if (false) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_outlined, size: 86),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              L10n.of(context).noUsersFoundWithQuery(
                                controller.controller.text,
                              ),
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      );
                    }
                    return ListView.builder(
                      itemCount: result.length,
                      itemBuilder: (context, i) {
                        final contact = result[i];
                        final displayname = contact.displayName ??
                            contact.userId.localpart ??
                            contact.userId;
                        return ListTile(
                          leading: Avatar(
                            name: displayname,
                            mxContent: contact.avatarUrl,
                            presenceUserId: contact.userId,
                          ),
                          title: Text(displayname),
                          subtitle: Text(contact.userId),
                          onTap: () => controller.openUserModal(contact),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
