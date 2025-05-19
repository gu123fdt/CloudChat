import 'package:cloudchat/pages/chat/events/message_actions.dart';
import 'package:cloudchat/pages/chat/events/message_content.dart';
import 'package:cloudchat/pages/chat/events/message_reactions.dart';
import 'package:cloudchat/pages/chat/events/reply_content.dart';
import 'package:cloudchat/pages/chat/events/state_message.dart';
import 'package:cloudchat/pages/chat/events/verification_request_content.dart';
import 'package:cloudchat/utils/thread_unread_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:matrix/matrix.dart';
import 'package:swipe_to_action/swipe_to_action.dart';

import 'package:cloudchat/config/themes.dart';
import 'package:cloudchat/pages/chat/events/room_creation_state_event.dart';
import 'package:cloudchat/utils/date_time_extension.dart';
import 'package:cloudchat/utils/string_color.dart';
import 'package:cloudchat/widgets/avatar.dart';
import 'package:cloudchat/widgets/matrix.dart';
import '../../../config/app_config.dart';

class Message extends StatelessWidget {
  final Event event;
  final Event? nextEvent;
  final Event? previousEvent;
  final bool displayReadMarker;
  final void Function(Event) onSelect;
  final void Function(Event, bool) onHover;
  final void Function(Event) onAvatarTab;
  final void Function(Event) onInfoTab;
  final void Function(String) scrollToEventId;
  final void Function() onSwipe;
  final bool longPressSelect;
  final bool selected;
  final Timeline timeline;
  final bool highlightMarker;
  final bool animateIn;
  final void Function()? resetAnimateIn;
  final bool wallpaperMode;
  final bool isHovered;
  final int selectedCount;
  final bool canStartThread;
  final bool canEditEvent;
  final bool canPinEvent;
  final bool canRedactEvent;
  final bool canForward;
  final bool canReply;
  final void Function(Event) onStartThread;
  final void Function(Event) onEdit;
  final void Function(Event) onCopy;
  final void Function(Event) onPin;
  final void Function(Event) onRedact;
  final void Function(Event) onForward;
  final void Function(Event) onReply;
  final int threadEventCount;
  final bool Function(Event) detectReplyFromThread;
  final String Function(Event) getReplyEventIdFromThread;
  final Event? Function(String) getReplyEventFromThread;
  final ThreadUnreadData? threadUnreadData;
  final bool canCreateLink;
  final void Function(Event) onCreateLink;

  const Message(
    this.event, {
    this.nextEvent,
    this.previousEvent,
    this.displayReadMarker = false,
    this.longPressSelect = false,
    required this.onSelect,
    required this.onHover,
    required this.onInfoTab,
    required this.onAvatarTab,
    required this.scrollToEventId,
    required this.onSwipe,
    this.selected = false,
    required this.timeline,
    this.highlightMarker = false,
    this.animateIn = false,
    this.resetAnimateIn,
    this.wallpaperMode = false,
    this.isHovered = false,
    this.selectedCount = 0,
    this.canStartThread = false,
    this.canEditEvent = false,
    this.canPinEvent = false,
    this.canRedactEvent = false,
    required this.onStartThread,
    required this.onEdit,
    required this.onCopy,
    required this.onPin,
    required this.onRedact,
    this.threadEventCount = 0,
    required this.detectReplyFromThread,
    required this.getReplyEventIdFromThread,
    required this.getReplyEventFromThread,
    this.threadUnreadData,
    this.canForward = false,
    this.canReply = false,
    required this.onForward,
    required this.onReply,
    this.canCreateLink = false,
    required this.onCreateLink,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!{
      EventTypes.Message,
      EventTypes.Sticker,
      EventTypes.Encrypted,
      EventTypes.CallInvite,
      EventTypes.CallHangup,
      EventTypes.CallReject,
      EventTypes.CallCandidates,
    }.contains(event.type)) {
      if (event.type.startsWith('m.call.')) {
        return const SizedBox.shrink();
      }
      if (event.type == EventTypes.RoomCreate) {
        return RoomCreationStateEvent(event: event);
      }
      return StateMessage(event);
    }

    if (event.type == EventTypes.Message &&
        event.messageType == EventTypes.KeyVerificationRequest) {
      return VerificationRequestContent(event: event, timeline: timeline);
    }

    final client = Matrix.of(context).client;
    final ownMessage = event.senderId == client.userID;
    final alignment = ownMessage ? Alignment.topRight : Alignment.topLeft;

    var color = theme.colorScheme.surfaceContainerHigh;
    final displayTime = event.type == EventTypes.RoomCreate ||
        nextEvent == null ||
        !event.originServerTs.sameEnvironment(nextEvent!.originServerTs);
    final nextEventSameSender = nextEvent != null &&
        {
          EventTypes.Message,
          EventTypes.Sticker,
          EventTypes.Encrypted,
        }.contains(nextEvent!.type) &&
        nextEvent!.senderId == event.senderId &&
        !displayTime;

    final previousEventSameSender = previousEvent != null &&
        {
          EventTypes.Message,
          EventTypes.Sticker,
          EventTypes.Encrypted,
        }.contains(previousEvent!.type) &&
        previousEvent!.senderId == event.senderId &&
        previousEvent!.originServerTs.sameEnvironment(event.originServerTs);

    final textColor =
        ownMessage ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;
    final rowMainAxisAlignment =
        ownMessage ? MainAxisAlignment.end : MainAxisAlignment.start;

    final displayEvent = event.getDisplayEvent(timeline);
    const hardCorner = Radius.circular(4);
    const roundedCorner = Radius.circular(AppConfig.borderRadius);
    final borderRadius = BorderRadius.only(
      topLeft: !ownMessage && nextEventSameSender ? hardCorner : roundedCorner,
      topRight: ownMessage && nextEventSameSender ? hardCorner : roundedCorner,
      bottomLeft:
          !ownMessage && previousEventSameSender ? hardCorner : roundedCorner,
      bottomRight:
          ownMessage && previousEventSameSender ? hardCorner : roundedCorner,
    );
    final noBubble = ({
              MessageTypes.Video,
              MessageTypes.Image,
              MessageTypes.Sticker,
            }.contains(event.messageType) &&
            !event.redacted) ||
        (event.messageType == MessageTypes.Text &&
            event.relationshipType == null &&
            event.onlyEmotes &&
            event.numberEmotes > 0 &&
            event.numberEmotes <= 3);
    final noPadding = {
      MessageTypes.File,
      MessageTypes.Audio,
    }.contains(event.messageType);

    if (ownMessage) {
      color = displayEvent.status.isError
          ? Colors.redAccent
          : theme.colorScheme.primary;
    }

    final resetAnimateIn = this.resetAnimateIn;
    var animateIn = this.animateIn;

    final row = StatefulBuilder(
      builder: (context, setState) {
        if (animateIn && resetAnimateIn != null) {
          WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
            animateIn = false;
            setState(resetAnimateIn);
          });
        }
        return AnimatedSize(
          duration: CloudThemes.animationDuration,
          curve: CloudThemes.animationCurve,
          clipBehavior: Clip.none,
          alignment: ownMessage ? Alignment.bottomRight : Alignment.bottomLeft,
          child: animateIn
              ? const SizedBox(height: 0, width: double.infinity)
              : Stack(
                  children: [
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: InkWell(
                        onTap: () => onSelect(event),
                        onLongPress: () => onSelect(event),
                        onHover: (isHovered) => onHover(event, isHovered),
                        borderRadius:
                            BorderRadius.circular(AppConfig.borderRadius / 2),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Material(
                              borderRadius: BorderRadius.circular(
                                  AppConfig.borderRadius / 2,),
                              color: selected
                                  ? theme.colorScheme.secondaryContainer
                                      .withAlpha(100)
                                  : highlightMarker
                                      ? theme.colorScheme.tertiaryContainer
                                          .withAlpha(100)
                                      : Colors.transparent,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: rowMainAxisAlignment,
                      children: [
                        if (longPressSelect)
                          SizedBox(
                            height: 32,
                            width: Avatar.defaultSize,
                            child: Checkbox.adaptive(
                              value: selected,
                              shape: const CircleBorder(),
                              onChanged: (_) => onSelect(event),
                            ),
                          )
                        else if (nextEventSameSender || ownMessage)
                          SizedBox(
                            width: Avatar.defaultSize,
                            child: Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: event.status == EventStatus.error
                                    ? const Icon(Icons.error, color: Colors.red)
                                    : event.fileSendingStatus != null
                                        ? const CircularProgressIndicator
                                            .adaptive(
                                            strokeWidth: 1,
                                          )
                                        : null,
                              ),
                            ),
                          )
                        else
                          FutureBuilder<User?>(
                            future: event.fetchSenderUser(),
                            builder: (context, snapshot) {
                              final user = snapshot.data ??
                                  event.senderFromMemoryOrFallback;
                              return Avatar(
                                mxContent: user.avatarUrl,
                                name: user.calcDisplayname(),
                                presenceUserId: user.stateKey,
                                presenceBackgroundColor:
                                    wallpaperMode ? Colors.transparent : null,
                                onTap: () => onAvatarTab(event),
                              );
                            },
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!nextEventSameSender)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 8.0,
                                    bottom: 4,
                                  ),
                                  child: ownMessage || event.room.isDirectChat
                                      ? const SizedBox(height: 12)
                                      : FutureBuilder<User?>(
                                          future: event.fetchSenderUser(),
                                          builder: (context, snapshot) {
                                            final displayname = snapshot.data
                                                    ?.calcDisplayname() ??
                                                event.senderFromMemoryOrFallback
                                                    .calcDisplayname();
                                            return Text(
                                              displayname,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: (theme.brightness ==
                                                        Brightness.light
                                                    ? displayname.color
                                                    : displayname
                                                        .lightColorText),
                                                shadows: !wallpaperMode
                                                    ? null
                                                    : [
                                                        const Shadow(
                                                          offset: Offset(
                                                            0.0,
                                                            0.0,
                                                          ),
                                                          blurRadius: 3,
                                                          color: Colors.black,
                                                        ),
                                                      ],
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            );
                                          },
                                        ),
                                ),
                              Column(
                                children: [
                                  Container(
                                    alignment: alignment,
                                    padding: const EdgeInsets.only(left: 8),
                                    child: GestureDetector(
                                      onLongPress: longPressSelect
                                          ? null
                                          : () {
                                              HapticFeedback.heavyImpact();
                                              onSelect(event);
                                            },
                                      child: AnimatedOpacity(
                                        opacity: animateIn
                                            ? 0
                                            : event.messageType ==
                                                        MessageTypes
                                                            .BadEncrypted ||
                                                    event.status.isSending
                                                ? 0.5
                                                : 1,
                                        duration: CloudThemes.animationDuration,
                                        curve: CloudThemes.animationCurve,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: noBubble
                                                ? Colors.transparent
                                                : color,
                                            borderRadius: borderRadius,
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                AppConfig.borderRadius,
                                              ),
                                            ),
                                            padding: noBubble || noPadding
                                                ? EdgeInsets.zero
                                                : const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 8,
                                                  ),
                                            constraints: const BoxConstraints(
                                              maxWidth:
                                                  CloudThemes.columnWidth * 1.5,
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: <Widget>[
                                                if (event.relationshipType ==
                                                        RelationshipTypes
                                                            .reply ||
                                                    detectReplyFromThread(
                                                        event,))
                                                  FutureBuilder<Event?>(
                                                    future: event.getReplyEvent(
                                                        timeline,),
                                                    builder: (
                                                      BuildContext context,
                                                      snapshot,
                                                    ) {
                                                      final empty = Event(
                                                        eventId: event
                                                            .relationshipEventId!,
                                                        content: {
                                                          'msgtype': 'm.text',
                                                          'body': '...',
                                                        },
                                                        senderId:
                                                            event.senderId,
                                                        type: 'm.room.message',
                                                        room: event.room,
                                                        status:
                                                            EventStatus.sent,
                                                        originServerTs:
                                                            DateTime.now(),
                                                      );

                                                      final replyEvent = snapshot
                                                              .hasData
                                                          ? snapshot.data!
                                                          : detectReplyFromThread(
                                                                  event,)
                                                              ? getReplyEventFromThread(
                                                                      getReplyEventIdFromThread(
                                                                          event,),) ??
                                                                  empty
                                                              : empty;
                                                      return Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                          bottom: 4.0,
                                                        ),
                                                        child: InkWell(
                                                          borderRadius:
                                                              ReplyContent
                                                                  .borderRadius,
                                                          onTap: () =>
                                                              scrollToEventId(
                                                            replyEvent.eventId,
                                                          ),
                                                          child: AbsorbPointer(
                                                            child: ReplyContent(
                                                              replyEvent,
                                                              ownMessage:
                                                                  ownMessage,
                                                              timeline:
                                                                  timeline,
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                MessageContent(
                                                  displayEvent,
                                                  textColor: textColor,
                                                  onInfoTab: onInfoTab,
                                                  borderRadius: borderRadius,
                                                  isJitsi: true,
                                                ),
                                                if (event.hasAggregatedEvents(
                                                  timeline,
                                                  RelationshipTypes.edit,
                                                ))
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                      top: 4.0,
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.edit_outlined,
                                                          color: textColor
                                                              .withAlpha(164),
                                                          size: 14,
                                                        ),
                                                        Text(
                                                          ' - ${displayEvent.originServerTs.localizedTimeShort(context)}',
                                                          style: TextStyle(
                                                            color: textColor
                                                                .withAlpha(164),
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (canStartThread && threadEventCount > 0)
                                    Container(
                                      alignment: alignment,
                                      padding: const EdgeInsets.only(
                                        left: 8,
                                        top: 8,
                                        bottom: 8,
                                      ),
                                      child: IntrinsicWidth(
                                        child: SizedBox(
                                          height: 40,
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.only(
                                                  right: 8,
                                                ),
                                                child: Text(
                                                  L10n.of(context).countAnswers(
                                                      threadEventCount,),
                                                ),
                                              ),
                                              Stack(
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons
                                                        .fork_right_outlined,),
                                                    tooltip: L10n.of(context)
                                                        .toThread,
                                                    onPressed: () =>
                                                        onStartThread(event),
                                                  ),
                                                  Positioned(
                                                    right: 2,
                                                    top: 2,
                                                    child: Container(
                                                      height: 10,
                                                      width: 10,
                                                      decoration: BoxDecoration(
                                                        color: threadUnreadData!
                                                                .isUnreadThread(
                                                          event.roomId!,
                                                          event.eventId,
                                                          Matrix.of(context)
                                                              .client
                                                              .userID!,
                                                        )
                                                            ? Colors.red
                                                            : Colors
                                                                .transparent,
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (isHovered)
                      Positioned(
                        left: ownMessage
                            ? selected || selectedCount > 0
                                ? 46
                                : 0
                            : null,
                        right: ownMessage ? null : 0,
                        child: MouseRegion(
                          onEnter: (_) => onHover(event, true),
                          onExit: (_) => onHover(event, false),
                          child: MessageActions(
                            canStartThread: canStartThread,
                            canEditEvent: canEditEvent,
                            canPinEvent: canPinEvent,
                            canRedactEvent: canRedactEvent,
                            canForward: canForward,
                            canReply: canReply,
                            canCreateLink: canCreateLink,
                            onCreateLink: () => onCreateLink(event),
                            onStartThread: () => onStartThread(event),
                            onEdit: () => onEdit(event),
                            onCopy: () => onCopy(event),
                            onPin: () => onPin(event),
                            onRedact: () => onRedact(event),
                            onForward: () => onForward(event),
                            onReply: () => onReply(event),
                            key: ValueKey(event.eventId),
                          ),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
    Widget container;
    final showReceiptsRow =
        event.hasAggregatedEvents(timeline, RelationshipTypes.reaction);
    if (showReceiptsRow || displayTime || selected || displayReadMarker) {
      container = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            ownMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: <Widget>[
          if (displayTime || selected)
            Padding(
              padding: displayTime
                  ? const EdgeInsets.symmetric(vertical: 8.0)
                  : EdgeInsets.zero,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Material(
                    borderRadius:
                        BorderRadius.circular(AppConfig.borderRadius * 2),
                    color: theme.colorScheme.surface.withAlpha(128),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 2.0,
                      ),
                      child: Text(
                        event.originServerTs.localizedTime(context),
                        style: TextStyle(
                          fontSize: 12 * AppConfig.fontSizeFactor,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          row,
          AnimatedSize(
            duration: CloudThemes.animationDuration,
            curve: CloudThemes.animationCurve,
            child: !showReceiptsRow
                ? const SizedBox.shrink()
                : Padding(
                    padding: EdgeInsets.only(
                      top: 4.0,
                      left: (ownMessage ? 0 : Avatar.defaultSize) + 12.0,
                      right: ownMessage ? 0 : 12.0,
                    ),
                    child: MessageReactions(event, timeline),
                  ),
          ),
          if (displayReadMarker)
            Row(
              children: [
                Expanded(
                  child:
                      Divider(color: theme.colorScheme.surfaceContainerHighest),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 16.0,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(AppConfig.borderRadius / 3),
                    color: theme.colorScheme.surface.withAlpha(128),
                  ),
                  child: Text(
                    L10n.of(context).readUpToHere,
                    style: TextStyle(
                      fontSize: 12 * AppConfig.fontSizeFactor,
                    ),
                  ),
                ),
                Expanded(
                  child:
                      Divider(color: theme.colorScheme.surfaceContainerHighest),
                ),
              ],
            ),
        ],
      );
    } else {
      container = row;
    }

    return Center(
      child: Swipeable(
        key: ValueKey(event.eventId),
        background: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.0),
          child: Center(
            child: Icon(Icons.check_outlined),
          ),
        ),
        direction: AppConfig.swipeRightToLeftToReply
            ? SwipeDirection.endToStart
            : SwipeDirection.startToEnd,
        onSwipe: (_) => onSwipe(),
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: CloudThemes.columnWidth * 2.5,
          ),
          padding: EdgeInsets.only(
            left: 8.0,
            right: 8.0,
            top: nextEventSameSender ? 1.0 : 4.0,
            bottom: previousEventSameSender ? 1.0 : 4.0,
          ),
          child: container,
        ),
      ),
    );
  }
}
