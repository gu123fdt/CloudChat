import 'package:flutter/material.dart';

import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:go_router/go_router.dart';

import 'package:cloudchat/config/themes.dart';
import 'package:cloudchat/pages/chat/chat.dart';
import 'package:cloudchat/utils/date_time_extension.dart';
import 'package:cloudchat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:cloudchat/widgets/avatar.dart';
import 'package:cloudchat/widgets/presence_builder.dart';

class ChatAppBarTitle extends StatelessWidget {
  final ChatController controller;
  const ChatAppBarTitle(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final room = controller.room;
    if (controller.selectedEvents.isNotEmpty) {
      return Text(controller.selectedEvents.length.toString());
    }
    return InkWell(
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: controller.isArchived || controller.isThread()
          ? null
          : () => CloudThemes.isThreeColumnMode(context)
              ? controller.toggleDisplayChatDetailsColumn()
              : context.go('/rooms/${room.id}/details?'),
      child: Row(
        children: [
          if (!controller.isThread())
            Hero(
              tag: 'content_banner',
              child: Avatar(
                mxContent: room.avatar,
                name: room.getLocalizedDisplayname(
                  MatrixLocals(L10n.of(context)),
                ),
                size: 32,
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (controller.isThread())
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        L10n.of(context).thread,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: IconButton(
                          onPressed: controller.setFavoriteThread,
                          icon: controller.isFavoriteThread ? const Icon(Icons.star) : const Icon(Icons.star_outline),

                        ),
                      ),
                    ],
                  ),
                if (!controller.isThread())
                  Text(
                    room.getLocalizedDisplayname(
                        MatrixLocals(L10n.of(context)),),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                    ),
                  ),
                if (!controller.isThread())
                  AnimatedSize(
                    duration: CloudThemes.animationDuration,
                    child: PresenceBuilder(
                      userId: room.directChatMatrixID,
                      builder: (context, presence) {
                        final lastActiveTimestamp =
                            presence?.lastActiveTimestamp;
                        final style = Theme.of(context).textTheme.bodySmall;
                        if (presence?.currentlyActive == true) {
                          return Text(
                            L10n.of(context).currentlyActive,
                            style: style,
                          );
                        }
                        if (lastActiveTimestamp != null) {
                          return Text(
                            L10n.of(context).lastActiveAgo(
                              lastActiveTimestamp.localizedTimeShort(context),
                            ),
                            style: style,
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
