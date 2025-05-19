import 'package:flutter/material.dart';
import 'package:cloudchat/widgets/matrix.dart';

import 'package:matrix/matrix.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import 'package:cloudchat/config/themes.dart';
import 'package:cloudchat/pages/chat/chat.dart';
import 'package:cloudchat/pages/chat/events/message.dart';
import 'package:cloudchat/pages/chat/seen_by_row.dart';
import 'package:cloudchat/pages/chat/typing_indicators.dart';
import 'package:cloudchat/pages/user_bottom_sheet/user_bottom_sheet.dart';
import 'package:cloudchat/utils/account_config.dart';
import 'package:cloudchat/utils/adaptive_bottom_sheet.dart';
import 'package:cloudchat/utils/matrix_sdk_extensions/filtered_timeline_extension.dart';
import 'package:cloudchat/utils/platform_infos.dart';

class ChatEventList extends StatelessWidget {
  final ChatController controller;
  const ChatEventList({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final timeline = controller.timeline;
    if (timeline == null) {
      return const Center(
        child: CircularProgressIndicator.adaptive(
          strokeWidth: 2,
        ),
      );
    }

    final horizontalPadding = CloudThemes.isColumnMode(context) ? 8.0 : 0.0;

    final events = timeline.events
        .filterByVisibleInGui(exceptionRelationshipEventId: controller.thread);
    final animateInEventIndex = controller.animateInEventIndex;
    final thisEventsThreadEventCount = <String, int>{};
    final thisEventsThreadEventLastEvents = <String, Event>{};
    for (var i = 0; i < events.length; i++) {
      final _events = events
          .where(
            (event) =>
                event.eventId != events[i].eventId &&
                event.relationshipEventId == events[i].eventId &&
                event.relationshipType == RelationshipTypes.thread,
          )
          .toList();

      thisEventsThreadEventCount[events[i].eventId] = _events.length;

      if (_events.length != 0) {
        thisEventsThreadEventLastEvents[events[i].eventId] = _events[0];
      }
    }

    if (controller.isThread()) {
      events.removeWhere(
        (event) =>
            event.relationshipEventId != controller.thread &&
            event.eventId != controller.thread,
      );
    } else {
      events.removeWhere(
        (event) => event.relationshipType == RelationshipTypes.thread,
      );
    }

    events.removeWhere(
      (event) {
        if (event.type.startsWith('m.call')) {
          final allCallEventsByCallId = events
              .where((e) => e.content['call_id'] == event.content['call_id'])
              .toList();

          if (allCallEventsByCallId.any(
            (e) =>
                e.type == EventTypes.CallHangup ||
                e.type == EventTypes.CallReject,
          )) {
            if (event.type == EventTypes.CallHangup ||
                event.type == EventTypes.CallReject) {
              return false;
            }
          } else if (allCallEventsByCallId
              .any((e) => e.type == EventTypes.CallInvite)) {
            if (event.type == EventTypes.CallInvite) {
              return false;
            }
          }

          return true;
        }

        return false;
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.isThread() &&
          events.isNotEmpty &&
          controller.threadLastEventId != events[0].eventId) {
        controller.setThreadLastEventId(events[0].eventId);
      }
    });

    // create a map of eventId --> index to greatly improve performance of
    // ListView's findChildIndexCallback
    final thisEventsKeyMap = <String, int>{};
    for (var i = 0; i < events.length; i++) {
      thisEventsKeyMap[events[i].eventId] = i;
    }

    final hasWallpaper =
        controller.room.client.applicationAccountConfig.wallpaperUrl != null;

    return SelectionArea(
      child: ListView.custom(
        padding: EdgeInsets.only(
          top: 16,
          bottom: 8,
          left: horizontalPadding,
          right: horizontalPadding,
        ),
        reverse: true,
        controller: controller.scrollController,
        keyboardDismissBehavior: PlatformInfos.isIOS
            ? ScrollViewKeyboardDismissBehavior.onDrag
            : ScrollViewKeyboardDismissBehavior.manual,
        childrenDelegate: SliverChildBuilderDelegate(
          (BuildContext context, int i) {
            // Footer to display typing indicator and read receipts:
            if (i == 0) {
              if (timeline.isRequestingFuture) {
                return const Center(
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                );
              }
              if (timeline.canRequestFuture) {
                return Center(
                  child: IconButton(
                    onPressed: controller.requestFuture,
                    icon: const Icon(Icons.refresh_outlined),
                  ),
                );
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (controller.isThread()) TypingIndicators(controller),
                ],
              );
            }

            // Request history button or progress indicator:
            if (i == events.length + 1) {
              if (timeline.isRequestingHistory) {
                return const Center(
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                );
              }
              if (timeline.canRequestHistory &&
                  (controller.isThread()
                      ? !events.any(
                          (element) => element.eventId == controller.thread,
                        )
                      : true)) {
                return Builder(
                  builder: (context) {
                    WidgetsBinding.instance
                        .addPostFrameCallback(controller.requestHistory);
                    return Center(
                      child: IconButton(
                        onPressed: controller.requestHistory,
                        icon: const Icon(Icons.refresh_outlined),
                      ),
                    );
                  },
                );
              }
              return const SizedBox.shrink();
            }
            i--;

            // The message at this index:
            final event = events[i];
            final animateIn = animateInEventIndex != null &&
                events.length > animateInEventIndex &&
                event == events[animateInEventIndex];

            if ((event.relationshipType == RelationshipTypes.thread &&
                    !controller.isThread()) ||
                (event.relationshipType != RelationshipTypes.thread &&
                    event.eventId != controller.thread &&
                    controller.isThread()) ||
                (event.relationshipEventId != controller.thread &&
                    event.eventId != controller.thread &&
                    controller.isThread())) {
              return const SizedBox.shrink();
            }

            return AutoScrollTag(
              key: ValueKey(event.eventId),
              index: i,
              controller: controller.scrollController,
              child: Message(
                event,
                animateIn: animateIn,
                resetAnimateIn: () {
                  controller.animateInEventIndex = null;
                },
                onSwipe: () => controller.replyAction(replyTo: event),
                onInfoTab: controller.showEventInfo,
                onAvatarTab: (Event event) => showAdaptiveBottomSheet(
                  context: context,
                  builder: (c) => UserBottomSheet(
                    user: event.senderFromMemoryOrFallback,
                    outerContext: context,
                    onMention: () => controller.sendController.text +=
                        '${event.senderFromMemoryOrFallback.mention} ',
                  ),
                ),
                highlightMarker:
                    controller.scrollToEventIdMarker == event.eventId,
                onSelect: controller.onSelectMessage,
                onHover: controller.onHoverMessage,
                scrollToEventId: (String eventId) =>
                    controller.scrollToEventId(eventId),
                longPressSelect: controller.selectedEvents.isNotEmpty,
                selected: controller.selectedEvents
                    .any((e) => e.eventId == event.eventId),
                timeline: timeline,
                displayReadMarker:
                    i > 0 && controller.readMarkerEventId == event.eventId,
                nextEvent: i + 1 < events.length ? events[i + 1] : null,
                previousEvent: i > 0 ? events[i - 1] : null,
                wallpaperMode: hasWallpaper,
                isHovered: controller.hoveredEvent?.eventId == event.eventId,
                selectedCount: controller.selectedEvents.length,
                canStartThread: !(controller.isArchived ||
                    !event.status.isSent ||
                    event.redacted ||
                    controller.isThread()),
                onStartThread: controller.startThread,
                onEdit: controller.onEdit,
                onCopy: controller.onCopy,
                onPin: controller.onPin,
                onRedact: controller.onRedact,
                canEditEvent: controller.canEditEvent(event),
                canPinEvent: controller.canPinEvent(event),
                canRedactEvent: controller.canRedactEvent(event),
                threadEventCount: thisEventsThreadEventCount[event.eventId]!,
                detectReplyFromThread: controller.detectReplyFromThread,
                getReplyEventIdFromThread: controller.getReplyEventIdFromThread,
                getReplyEventFromThread: (String eventId) =>
                    controller.getReplyEventFromThread(eventId, events),
                threadUnreadData: controller.threadUnreadData,
                isMentionEvent: controller.isMentionEvent,
                onForward: controller.onForward,
                onReply: controller.onReply,
                canForward: controller.canForward(event),
                canReply: controller.canReply(event),
                canCreateLink: controller.canCreateLink(event),
                onCreateLink: controller.onCreateLink,
                controller: controller,
                lastThreadEvent: thisEventsThreadEventLastEvents[event.eventId],
              ),
            );
          },
          childCount: events.length + 2,
          findChildIndexCallback: (key) =>
              controller.findChildIndexCallback(key, thisEventsKeyMap),
        ),
      ),
    );
  }
}
