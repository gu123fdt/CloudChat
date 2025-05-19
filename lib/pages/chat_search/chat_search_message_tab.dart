import 'package:flutter/material.dart';

import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';

import 'package:cloudchat/utils/date_time_extension.dart';
import 'package:cloudchat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:cloudchat/utils/url_launcher.dart';
import 'package:cloudchat/widgets/avatar.dart';

import '../../widgets/matrix.dart';

class ChatSearchMessageTab extends StatelessWidget {
  final String searchQuery;
  final void Function({
    String? prevBatch,
    List<Event>? previousSearchResult,
  }) startSearch;
  final List<Event> events;
  final Room? room;
  final bool isLoading;

  const ChatSearchMessageTab({
    required this.searchQuery,
    required this.events,
    required this.startSearch,
    required this.isLoading,
    this.room,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (events.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_outlined, size: 64),
          const SizedBox(height: 8),
          Text(
            room != null
                ? L10n.of(context).searchIn(room!.getLocalizedDisplayname(
                    MatrixLocals(L10n.of(context)),
                  ),)
                : L10n.of(context).searchInGlobal,
          ),
        ],
      );
    }

    return SelectionArea(
      child: ListView.separated(
        itemCount: isLoading ? events.length + 1 : events.length,
        separatorBuilder: (context, _) => Divider(
          color: theme.dividerColor,
          height: 1,
        ),
        itemBuilder: (context, i) {
          if (i == events.length) {
            if (isLoading) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: CircularProgressIndicator.adaptive(
                    strokeWidth: 2,
                  ),
                ),
              );
            }
          }

          final event = events[i];
          final sender = event.senderFromMemoryOrFallback;
          final displayname = sender.calcDisplayname(
            i18n: MatrixLocals(L10n.of(context)),
          );

          return _MessageSearchResultListTile(
            sender: sender,
            displayname: displayname,
            event: event,
            room: Matrix.of(context).client.getRoomById(event.roomId!)!,
          );
        },
      ),
    );
  }
}

class _MessageSearchResultListTile extends StatelessWidget {
  const _MessageSearchResultListTile({
    required this.sender,
    required this.displayname,
    required this.event,
    required this.room,
  });

  final User sender;
  final String displayname;
  final Event event;
  final Room room;

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
          if (room.name != "")
            Text(
              ' | ${room.name}',
              style: const TextStyle(fontSize: 12),
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
      trailing: IconButton(
        icon: const Icon(
          Icons.chevron_right_outlined,
        ),
        onPressed: () {
          if (event.relationshipType == RelationshipTypes.thread) {
            context.go(
              '/${Uri(
                pathSegments: ['rooms', room.id],
                queryParameters: {
                  'threadEvent': event.eventId,
                  'event': event.relationshipEventId,
                  'thread': event.relationshipEventId,
                },
              )}',
            );
          } else {
            context.go(
              '/${Uri(
                pathSegments: ['rooms', room.id],
                queryParameters: {'event': event.eventId},
              )}',
            );
          }
        },
      ),
    );
  }
}
