import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:badges/badges.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:go_router/go_router.dart';
import 'package:cloudchat/pages/chat/edit_text_style.dart';
import 'package:cloudchat/pages/chat/md_editor.dart';
import 'package:matrix/matrix.dart';

import 'package:cloudchat/config/themes.dart';
import 'package:cloudchat/pages/chat/chat.dart';
import 'package:cloudchat/pages/chat/chat_app_bar_list_tile.dart';
import 'package:cloudchat/pages/chat/chat_app_bar_title.dart';
import 'package:cloudchat/pages/chat/chat_event_list.dart';
import 'package:cloudchat/pages/chat/encryption_button.dart';
import 'package:cloudchat/pages/chat/pinned_events.dart';
import 'package:cloudchat/pages/chat/reactions_picker.dart';
import 'package:cloudchat/pages/chat/reply_display.dart';
import 'package:cloudchat/utils/account_config.dart';
import 'package:cloudchat/utils/localized_exception_extension.dart';
import 'package:cloudchat/widgets/chat_settings_popup_menu.dart';
import 'package:cloudchat/widgets/connection_status_header.dart';
import 'package:cloudchat/widgets/future_loading_dialog.dart';
import 'package:cloudchat/widgets/matrix.dart';
import 'package:cloudchat/widgets/mxc_image.dart';
import 'package:cloudchat/widgets/unread_rooms_badge.dart';
import '../../utils/stream_extension.dart';
import 'chat_emoji_picker.dart';
import 'chat_input_row.dart';

enum _EventContextAction { info, report }

class ChatView extends StatelessWidget {
  final ChatController controller;

  const ChatView(this.controller, {super.key});

  List<Widget> _appBarActions(BuildContext context) {
    if (controller.selectMode) {
      return [
        if (controller.canStartThread)
          IconButton(
            icon: const Icon(Icons.fork_right_outlined),
            tooltip: L10n.of(context).startThread,
            onPressed: () =>
                controller.startThread(controller.selectedEvents[0]),
          ),
        if (controller.canEditSelectedEvents)
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: L10n.of(context).edit,
            onPressed: controller.editSelectedEventAction,
          ),
        IconButton(
          icon: const Icon(Icons.copy_outlined),
          tooltip: L10n.of(context).copy,
          onPressed: controller.copyEventsAction,
        ),
        if (controller.canSaveSelectedEvent)
          // Use builder context to correctly position the share dialog on iPad
          Builder(
            builder: (context) => IconButton(
              icon: Icon(Icons.adaptive.share),
              tooltip: L10n.of(context).share,
              onPressed: () => controller.saveSelectedEvent(context),
            ),
          ),
        if (controller.canPinSelectedEvents)
          IconButton(
            icon: const Icon(Icons.push_pin_outlined),
            onPressed: controller.pinEvent,
            tooltip: L10n.of(context).pinMessage,
          ),
        if (controller.canRedactSelectedEvents)
          IconButton(
            icon: const Icon(Icons.delete_outlined),
            tooltip: L10n.of(context).redactMessage,
            onPressed: controller.redactEventsAction,
          ),
        if (controller.selectedEvents.length == 1)
          PopupMenuButton<_EventContextAction>(
            onSelected: (action) {
              switch (action) {
                case _EventContextAction.info:
                  controller.showEventInfo();
                  controller.clearSelectedEvents();
                  break;
                case _EventContextAction.report:
                  controller.reportEventAction();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _EventContextAction.info,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outlined),
                    const SizedBox(width: 12),
                    Text(L10n.of(context).messageInfo),
                  ],
                ),
              ),
              if (controller.selectedEvents.single.status.isSent)
                PopupMenuItem(
                  value: _EventContextAction.report,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 12),
                      Text(L10n.of(context).reportMessage),
                    ],
                  ),
                ),
            ],
          ),
      ];
    } else if (!controller.room.isArchived && !controller.isThread()) {
      return [
        if (Matrix.of(context).voIPService != null)
          IconButton(
            onPressed: controller.onPhoneButtonTap,
            icon: const Icon(Icons.call_outlined),
            tooltip: L10n.of(context).placeCall,
          ),
        EncryptionButton(controller.room),
        ChatSettingsPopupMenu(controller.room, true),
      ];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (controller.room.membership == Membership.invite) {
      showFutureLoadingDialog(
        context: context,
        future: () => controller.room.join(),
        exceptionContext: ExceptionContext.joinRoom,
      );
    }
    final bottomSheetPadding = CloudThemes.isColumnMode(context) ? 16.0 : 8.0;
    final scrollUpBannerEventId = controller.scrollUpBannerEventId;

    final accountConfig = Matrix.of(context).client.applicationAccountConfig;

    return PopScope(
      canPop: controller.selectedEvents.isEmpty && !controller.showEmojiPicker,
      onPopInvokedWithResult: (pop, _) async {
        if (pop) return;
        if (controller.selectedEvents.isNotEmpty) {
          controller.clearSelectedEvents();
        } else if (controller.showEmojiPicker) {
          controller.emojiPickerAction();
        }
      },
      child: StreamBuilder(
        stream: controller.room.client.onRoomState.stream
            .where((update) => update.roomId == controller.room.id)
            .rateLimit(const Duration(seconds: 1)),
        builder: (context, snapshot) => FutureBuilder(
          future: controller.loadTimelineFuture,
          builder: (BuildContext context, snapshot) {
            var appbarBottomHeight = 0.0;
            if (controller.room.pinnedEventIds.isNotEmpty) {
              appbarBottomHeight += ChatAppBarListTile.fixedHeight;
            }
            if (scrollUpBannerEventId != null) {
              appbarBottomHeight += ChatAppBarListTile.fixedHeight;
            }
            final tombstoneEvent =
                controller.room.getState(EventTypes.RoomTombstone);
            if (tombstoneEvent != null) {
              appbarBottomHeight += ChatAppBarListTile.fixedHeight;
            }
            return Scaffold(
              appBar: AppBar(
                actionsIconTheme: IconThemeData(
                  color: controller.selectedEvents.isEmpty
                      ? null
                      : theme.colorScheme.primary,
                ),
                leading: controller.selectMode
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: controller.clearSelectedEvents,
                        tooltip: L10n.of(context).close,
                        color: theme.colorScheme.primary,
                      )
                    : controller.isThread()
                        ? IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: controller.closeThread,
                            tooltip: L10n.of(context).close,
                            color: theme.colorScheme.primary,
                          )
                        : StreamBuilder<Object>(
                            stream:
                                Matrix.of(context).client.onSync.stream.where(
                                      (syncUpdate) => syncUpdate.hasRoomUpdate,
                                    ),
                            builder: (context, _) => UnreadRoomsBadge(
                              filter: (r) => r.id != controller.roomId,
                              badgePosition:
                                  BadgePosition.topEnd(end: 8, top: 4),
                              child: Center(
                                child: BackButton(
                                  onPressed: controller.widget.from != null
                                      ? () {
                                          GoRouter.of(context)
                                              .go(controller.widget.from!);
                                        }
                                      : null,
                                ),
                              ),
                            ),
                          ),
                titleSpacing: 0,
                title: ChatAppBarTitle(controller),
                actions: _appBarActions(context),
                bottom: PreferredSize(
                  preferredSize: Size.fromHeight(appbarBottomHeight),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PinnedEvents(controller),
                      if (tombstoneEvent != null)
                        ChatAppBarListTile(
                          title: tombstoneEvent.parsedTombstoneContent.body,
                          leading: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(Icons.upgrade_outlined),
                          ),
                          trailing: TextButton(
                            onPressed: controller.goToNewRoomAction,
                            child: Text(L10n.of(context).goToTheNewRoom),
                          ),
                        ),
                      if (scrollUpBannerEventId != null)
                        ChatAppBarListTile(
                          leading: IconButton(
                            color: theme.colorScheme.onSurfaceVariant,
                            icon: const Icon(Icons.close),
                            tooltip: L10n.of(context).close,
                            onPressed: () {
                              controller.discardScrollUpBannerEventId();
                              controller.setReadMarker();
                            },
                          ),
                          title: L10n.of(context).jumpToLastReadMessage,
                          trailing: TextButton(
                            onPressed: () {
                              controller.scrollToEventId(
                                scrollUpBannerEventId,
                              );
                              controller.discardScrollUpBannerEventId();
                            },
                            child: Text(L10n.of(context).jump),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              floatingActionButton: controller.showScrollDownButton &&
                      controller.selectedEvents.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 56.0),
                      child: FloatingActionButton(
                        onPressed: controller.scrollDown,
                        heroTag: null,
                        mini: true,
                        child: const Icon(Icons.arrow_downward_outlined),
                      ),
                    )
                  : null,
              body: DropTarget(
                onDragDone: controller.onDragDone,
                onDragEntered: controller.onDragEntered,
                onDragExited: controller.onDragExited,
                child: Stack(
                  children: <Widget>[
                    if (accountConfig.wallpaperUrl != null)
                      Opacity(
                        opacity: accountConfig.wallpaperOpacity ?? 0.5,
                        child: ImageFiltered(
                          imageFilter: ui.ImageFilter.blur(
                            sigmaX: accountConfig.wallpaperBlur ?? 0.0,
                            sigmaY: accountConfig.wallpaperBlur ?? 0.0,
                          ),
                          child: MxcImage(
                            cacheKey: accountConfig.wallpaperUrl.toString(),
                            uri: accountConfig.wallpaperUrl,
                            fit: BoxFit.cover,
                            height: MediaQuery.of(context).size.height,
                            width: MediaQuery.of(context).size.width,
                            isThumbnail: false,
                            placeholder: (_) => Container(),
                          ),
                        ),
                      ),
                    SafeArea(
                      child: Column(
                        children: <Widget>[
                          Expanded(
                            child: GestureDetector(
                              onTap: controller.clearSingleSelectedEvent,
                              child: ChatEventList(controller: controller),
                            ),
                          ),
                          if (controller.room.canSendDefaultMessages &&
                              controller.room.membership == Membership.join)
                            Container(
                              margin: EdgeInsets.only(
                                bottom: bottomSheetPadding,
                                left: bottomSheetPadding,
                                right: bottomSheetPadding,
                              ),
                              constraints: const BoxConstraints(
                                maxWidth: CloudThemes.columnWidth * 2.5,
                              ),
                              alignment: Alignment.center,
                              child: Material(
                                clipBehavior: Clip.antiAliasWithSaveLayer,
                                color: theme.colorScheme.surfaceContainerHigh,
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(24),
                                ),
                                child: controller.room.isAbandonedDMRoom == true
                                    ? Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          TextButton.icon(
                                            style: TextButton.styleFrom(
                                              padding: const EdgeInsets.all(
                                                16,
                                              ),
                                              foregroundColor:
                                                  theme.colorScheme.error,
                                            ),
                                            icon: const Icon(
                                              Icons.archive_outlined,
                                            ),
                                            onPressed: controller.leaveChat,
                                            label: Text(
                                              L10n.of(context).leave,
                                            ),
                                          ),
                                          TextButton.icon(
                                            style: TextButton.styleFrom(
                                              padding: const EdgeInsets.all(
                                                16,
                                              ),
                                            ),
                                            icon: const Icon(
                                              Icons.forum_outlined,
                                            ),
                                            onPressed: controller.recreateChat,
                                            label: Text(
                                              L10n.of(context).reopenChat,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const ConnectionStatusHeader(),
                                          ReactionsPicker(controller),
                                          ReplyDisplay(controller),
                                          EditTextStyle(controller),
                                          ChatInputRow(controller),
                                          ChatEmojiPicker(controller),
                                          MDEditor(controller),
                                        ],
                                      ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (controller.dragging)
                      Container(
                        color: theme.scaffoldBackgroundColor.withOpacity(0.9),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.upload_outlined,
                          size: 100,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
