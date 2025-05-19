import 'package:badges/badges.dart';
import 'package:flutter/material.dart';

import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:go_router/go_router.dart';
import 'package:cloudchat/widgets/unread_rooms_badge.dart';
import 'package:matrix/matrix.dart';

import 'package:cloudchat/config/app_config.dart';
import 'package:cloudchat/config/themes.dart';
import 'package:cloudchat/pages/chat_list/chat_list.dart';
import 'package:cloudchat/pages/chat_list/navi_rail_item.dart';
import 'package:cloudchat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:cloudchat/utils/stream_extension.dart';
import 'package:cloudchat/widgets/avatar.dart';
import '../../widgets/matrix.dart';
import 'chat_list_body.dart';

class ChatListView extends StatelessWidget {
  final ChatListController controller;

  const ChatListView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final client = Matrix.of(context).client;

    return PopScope(
      canPop: !controller.isSearchMode && controller.activeSpaceId == null,
      onPopInvokedWithResult: (pop, _) {
        if (pop) return;
        if (controller.activeSpaceId != null) {
          controller.clearActiveSpace();
          return;
        }
        if (controller.isSearchMode) {
          controller.cancelSearch();
          return;
        }
      },
      child: Row(
        children: [
          if (CloudThemes.isColumnMode(context) &&
              controller.widget.displayNavigationRail) ...[
            StreamBuilder(
              key: ValueKey(
                client.userID.toString(),
              ),
              stream: client.onSync.stream
                  .where((s) => s.hasRoomUpdate)
                  .rateLimit(const Duration(seconds: 1)),
              builder: (context, _) {
                final allSpaces = Matrix.of(context)
                    .client
                    .rooms
                    .where((room) => room.isSpace);
                final rootSpaces = allSpaces
                    .where(
                      (space) => !allSpaces.any(
                        (parentSpace) => parentSpace.spaceChildren
                            .any((child) => child.roomId == space.id),
                      ),
                    )
                    .toList();

                return SizedBox(
                  width: CloudThemes.navRailWidth,
                  child: ListView.builder(
                    scrollDirection: Axis.vertical,
                    itemCount: rootSpaces.length + 3,
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return NaviRailItem(
                          isSelected: controller.activeSpaceId == null &&
                              GoRouter.of(context)
                                      .routeInformationProvider
                                      .value
                                      .uri
                                      .path !=
                                  '/rooms/threads',
                          onTap: () {
                            controller.clearActiveSpace();
                            context.go('/rooms');
                          },
                          icon: const Icon(Icons.forum_outlined),
                          selectedIcon: const Icon(Icons.forum),
                          toolTip: L10n.of(context).chats,
                          unreadBadgeFilter: (room) => true,
                        );
                      }
                      if (i == 1) {
                        return NaviRailItem(
                          isSelected: GoRouter.of(context)
                                  .routeInformationProvider
                                  .value
                                  .uri
                                  .path ==
                              '/rooms/threads',
                          onTap: () {
                            context.go('/rooms/threads');
                            controller.clearActiveSpace();
                          },
                          icon: const Icon(Icons.fork_right_outlined),
                          selectedIcon: const Icon(Icons.fork_right_outlined),
                          toolTip: L10n.of(context).threads,
                          badgeCount: controller.threadUnreadData
                              .unreadThreads[client.userID]?.values
                              .fold(0, (sum, list) => sum! + list.length),
                        );
                      }
                      i = i - 2;
                      if (i == rootSpaces.length) {
                        return NaviRailItem(
                          isSelected: false,
                          onTap: () => context.go('/rooms/newspace'),
                          icon: const Icon(Icons.add),
                          toolTip: L10n.of(context).createNewSpace,
                        );
                      }
                      final space = rootSpaces[i];
                      final displayname = rootSpaces[i].getLocalizedDisplayname(
                        MatrixLocals(L10n.of(context)),
                      );
                      final spaceChildrenIds =
                          space.spaceChildren.map((c) => c.roomId).toSet();
                      return NaviRailItem(
                        toolTip: displayname,
                        isSelected: controller.activeSpaceId == space.id,
                        onTap: () {
                          controller.setActiveSpace(rootSpaces[i].id);

                          if (GoRouter.of(context)
                                  .routeInformationProvider
                                  .value
                                  .uri
                                  .path ==
                              '/rooms/threads') {
                            context.go('/rooms');
                          }
                        },
                        unreadBadgeFilter: (room) =>
                            spaceChildrenIds.contains(room.id),
                        icon: Avatar(
                          mxContent: rootSpaces[i].avatar,
                          name: displayname,
                          size: 32,
                          borderRadius: BorderRadius.circular(
                            AppConfig.borderRadius / 4,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            Container(
              color: Theme.of(context).dividerColor,
              width: 1,
            ),
          ],
          Expanded(
            child: GestureDetector(
              onTap: FocusManager.instance.primaryFocus?.unfocus,
              excludeFromSemantics: true,
              behavior: HitTestBehavior.translucent,
              child: Scaffold(
                body: ChatListViewBody(controller),
                floatingActionButton: !controller.isSearchMode &&
                        controller.activeSpaceId == null
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (!CloudThemes.isColumnMode(context) &&
                              !controller.widget.displayNavigationRail)
                            Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: FloatingActionButton(
                                onPressed: () => context.go('/rooms/threads'),
                                child: UnreadRoomsBadge(
                                  badgePosition: BadgePosition.topEnd(
                                    top: -22,
                                    end: -22,
                                  ),
                                  count: controller.threadUnreadData
                                      .unreadThreads[client.userID]?.values
                                      .fold(
                                          0, (sum, list) => sum! + list.length,),
                                  child: const Icon(Icons.fork_right_outlined),
                                ),
                              ),
                            ),
                          FloatingActionButton.extended(
                            onPressed: () =>
                                context.go('/rooms/newprivatechat'),
                            icon: const Icon(Icons.add_outlined),
                            label: Text(
                              L10n.of(context).chat,
                              overflow: TextOverflow.fade,
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
