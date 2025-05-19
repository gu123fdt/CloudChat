import 'package:badges/badges.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:go_router/go_router.dart';
import 'package:cloudchat/config/themes.dart';
import 'package:cloudchat/pages/all_threads/all_threads.dart';
import 'package:cloudchat/utils/date_time_extension.dart';
import 'package:cloudchat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:cloudchat/utils/thread_favorite.dart';
import 'package:cloudchat/utils/highlights_rooms_and_threads.dart';
import 'package:cloudchat/utils/thread_unread_data.dart';
import 'package:cloudchat/utils/url_launcher.dart';
import 'package:cloudchat/widgets/avatar.dart';
import 'package:cloudchat/widgets/layouts/max_width_body.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:cloudchat/widgets/unread_rooms_badge.dart';
import 'package:matrix/matrix.dart';

class AllThreadsView extends StatelessWidget {
  final AllThreadsController controller;

  const AllThreadsView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final openedRoom = controller.rooms
        .firstWhereOrNull((room) => room.id == controller.roomId);

    return Scaffold(
      appBar: AppBar(
        leading: Center(
          child: BackButton(
            onPressed:
                controller.roomId != null ? controller.goBackToRoomList : null,
          ),
        ),
        titleSpacing: 0,
        title: Text(
          controller.roomId != null
              ? L10n.of(context).threadsFrom(
                  openedRoom!
                      .getLocalizedDisplayname(MatrixLocals(L10n.of(context))),
                )
              : L10n.of(context).threads,
        ),
      ),
      body: MaxWidthBody(
        withScrolling: false,
        maxWidth: 1800,
        innerPadding: !CloudThemes.isThreeColumnMode(context)
            ? const EdgeInsets.all(0)
            : const EdgeInsets.only(left: 64, right: 64),
        child: Column(
          children: [
            if (CloudThemes.isThreeColumnMode(context))
              const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
              ),
              child: TextField(
                controller: controller.roomId == null
                    ? controller.searchRoomsController
                    : controller.searchThreadsController,
                onSubmitted: (_) {
                  controller.updateUrl();
                  controller.filter();
                },
                onChanged: (_) {
                  controller.updateUrl();
                  controller.filter();
                },
                autofocus: true,
                decoration: InputDecoration(
                  hintText: L10n.of(context).search,
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
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SelectionArea(
                child: controller.roomId == null
                    ? ListView.separated(
                        itemCount: controller.filteredRooms.length,
                        separatorBuilder: (context, _) => Divider(
                          color: theme.dividerColor,
                          height: 1,
                        ),
                        itemBuilder: (context, i) {
                          return _RoomSearchResultListTile(
                            room: controller.filteredRooms[i],
                            threadsCount: controller.roomsThreadCounts[
                                controller.filteredRooms[i].id],
                            openThreads: controller.openThreads,
                            threadUnreadData: controller.threadUnreadData,
                          );
                        },
                      )
                    : ListView.separated(
                        itemCount: controller.filteredRoomThreads.length <
                                (controller.roomsThreadCounts[openedRoom!.id] ??
                                    0)
                            ? controller.filteredRoomThreads.length + 1
                            : controller.filteredRoomThreads.length,
                        separatorBuilder: (context, _) => Divider(
                          color: theme.dividerColor,
                          height: 1,
                        ),
                        itemBuilder: (context, i) {
                          if (i == controller.filteredRoomThreads.length) {
                            if (controller.filteredRoomThreads.length <
                                    controller
                                        .roomsThreadCounts[openedRoom.id]! &&
                                controller
                                    .searchThreadsController.text.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(
                                  child: CircularProgressIndicator.adaptive(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            } else {
                              return const SizedBox.shrink();
                            }
                          }

                          final event = controller.filteredRoomThreads[i];
                          final sender = event.senderFromMemoryOrFallback;
                          final displayname = sender.calcDisplayname(
                            i18n: MatrixLocals(L10n.of(context)),
                          );

                          return _ThreadMessageSearchResultListTile(
                            displayname: displayname,
                            event: event,
                            room: openedRoom,
                            sender: sender,
                            threadUnreadData: controller.threadUnreadData,
                            setFavoriteThread: controller.setFavoriteThread,
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

class _RoomSearchResultListTile extends StatelessWidget {
  const _RoomSearchResultListTile({
    required this.room,
    this.threadsCount,
    required this.openThreads,
    required this.threadUnreadData,
  });

  final Room room;
  final int? threadsCount;
  final Function(String) openThreads;
  final ThreadUnreadData threadUnreadData;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      title: Row(
        children: [
          Avatar(
            mxContent: room.avatar,
            name: room.getLocalizedDisplayname(
              MatrixLocals(L10n.of(context)),
            ),
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            room.getLocalizedDisplayname(
              MatrixLocals(L10n.of(context)),
            ),
          ),
        ],
      ),
      subtitle: threadsCount != null
          ? Text(L10n.of(context).threadsCount(threadsCount!))
          : const SizedBox.shrink(),
      trailing: threadsCount == null
          ? SizedBox(
              width: 24,
              height: 24,
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (ThreadFavorite().hasRoomFavorites(room.id))
                  const Icon(Icons.star),
                const SizedBox(width: 8),
                UnreadRoomsBadge(
                  badgePosition: BadgePosition.topEnd(
                    top: -4,
                    end: -4,
                  ),
                  count: threadUnreadData
                          .unreadThreads[room.client.userID]?[room.id]
                          ?.length ??
                      0,
                  color:
                      HighlightsRoomsAndThreads().hasHighlightThreads(room.id)
                          ? Colors.red
                          : null,
                  child: IconButton(
                    icon: const Icon(
                      Icons.chevron_right_outlined,
                    ),
                    onPressed: () => openThreads(room.id),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ThreadMessageSearchResultListTile extends StatelessWidget {
  const _ThreadMessageSearchResultListTile({
    required this.sender,
    required this.displayname,
    required this.event,
    required this.room,
    required this.threadUnreadData,
    required this.setFavoriteThread,
  });

  final User sender;
  final String displayname;
  final Event event;
  final Room room;
  final ThreadUnreadData threadUnreadData;
  final Function(String) setFavoriteThread;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      title: Row(
        children: [
          Avatar(
            mxContent: sender.avatarUrl,
            name: displayname,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            displayname,
          ),
          Expanded(
            child: Text(
              ' | ${event.originServerTs.localizedTimeShort(context)}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
      subtitle: Linkify(
        options: const LinkifyOptions(humanize: false),
        linkStyle: TextStyle(
          color: theme.colorScheme.primary,
          decoration: TextDecoration.underline,
          decorationColor: theme.colorScheme.primary,
        ),
        onOpen: (url) => UrlLauncher(context, url.url).launchUrl(),
        text: event
            .calcLocalizedBodyFallback(
              plaintextBody: true,
              removeMarkdown: true,
              MatrixLocals(
                L10n.of(context),
              ),
            )
            .trim(),
        maxLines: 7,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => setFavoriteThread(event.eventId),
            icon: ThreadFavorite().isFavorite(room.id, event.eventId)
                ? const Icon(Icons.star)
                : const Icon(Icons.star_outline),
          ),
          const SizedBox(width: 8),
          UnreadRoomsBadge(
            badgePosition: BadgePosition.topEnd(
              top: -4,
              end: -4,
            ),
            count: (threadUnreadData.unreadThreads[room.client.userID]
                            ?[room.id] ??
                        [])
                    .contains(event.eventId)
                ? 1
                : 0,
            color: HighlightsRoomsAndThreads()
                    .isHighlightThread(room.id, event.eventId)
                ? Colors.red
                : null,
            child: IconButton(
              icon: const Icon(
                Icons.chevron_right_outlined,
              ),
              onPressed: () {
                context.go(
                  '/${Uri(
                    pathSegments: ['rooms', room.id],
                    queryParameters: {
                      'thread': event.eventId,
                      'event': event.eventId,
                    },
                  )}',
                  extra: {
                    'from': GoRouter.of(context)
                        .routeInformationProvider
                        .value
                        .uri
                        .toString(),
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
