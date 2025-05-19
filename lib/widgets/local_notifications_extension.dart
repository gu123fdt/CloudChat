import 'dart:io';

import 'package:cloudchat/utils/highlights_rooms_and_threads.dart';
import 'package:cloudchat/widgets/cloud_chat_app.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:desktop_notifications/desktop_notifications.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:universal_html/html.dart' as html;

import 'package:cloudchat/config/app_config.dart';
import 'package:cloudchat/utils/client_download_content_extension.dart';
import 'package:cloudchat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:cloudchat/utils/platform_infos.dart';
import 'package:cloudchat/widgets/matrix.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:window_manager/window_manager.dart';

extension LocalNotificationsExtension on MatrixState {
  static final html.AudioElement _audioPlayer = html.AudioElement()
    ..src = 'assets/assets/sounds/notification.ogg'
    ..load();

  void showLocalNotification(EventUpdate eventUpdate) async {
    final roomId = eventUpdate.roomID;

    final room = client.getRoomById(roomId);
    if (room == null) {
      Logs().w('Can not display notification for unknown room $roomId');
      return;
    }

    final event = Event.fromJson(eventUpdate.content, room);

    if (eventUpdate.content["content"]?["m.relates_to"]?["rel_type"] ==
        RelationshipTypes.thread) {
      threadUnreadData.setUnreadThread(
        roomId,
        eventUpdate.content["content"]["m.relates_to"]["event_id"],
        client.userID!,
      );

      if (await HighlightsRoomsAndThreads()
          .isHighlightThreadFromEvent(event: event, roomId: roomId)) {
        HighlightsRoomsAndThreads()
            .setHighlightThread(roomId, event.relationshipEventId!);
      }
    } else {
      if (await HighlightsRoomsAndThreads()
          .isHighlightRoomFromEvent(event: event, roomId: roomId)) {
        HighlightsRoomsAndThreads().setHighlightRoom(roomId);
      }
    }

    if (activeRoomId == roomId) {
      if (kIsWeb && webHasFocus) return;
      if (PlatformInfos.isDesktop &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        return;
      }
    }

    if (room.notificationCount == 0) return;

    final title = room.getLocalizedDisplayname(MatrixLocals(L10n.of(context)));
    final body = await event.calcLocalizedBody(
      MatrixLocals(L10n.of(context)),
      withSenderNamePrefix:
          !room.isDirectChat || room.lastEvent?.senderId == client.userID,
      plaintextBody: true,
      hideReply: true,
      hideEdit: true,
      removeMarkdown: true,
    );

    if (kIsWeb) {
      final avatarUrl = event.senderFromMemoryOrFallback.avatarUrl;
      Uri? thumbnailUri;

      if (avatarUrl != null) {
        const size = 64;
        const thumbnailMethod = ThumbnailMethod.crop;
        // Pre-cache so that we can later just set the thumbnail uri as icon:
        await client.downloadMxcCached(
          avatarUrl,
          width: size,
          height: size,
          thumbnailMethod: thumbnailMethod,
          isThumbnail: true,
        );

        thumbnailUri =
            await event.senderFromMemoryOrFallback.avatarUrl?.getThumbnailUri(
          client,
          width: size,
          height: size,
          method: thumbnailMethod,
        );
      }

      _audioPlayer.play();

      html.Notification(
        title,
        body: body,
        icon: thumbnailUri?.toString(),
        tag: event.room.id,
      );
    } else if (Platform.isLinux) {
      final notification = await linuxNotifications!.notify(
        title,
        body: body,
        replacesId: linuxNotificationIds[roomId] ?? 0,
        appName: AppConfig.applicationName,
        appIcon: 'cloudchat',
        actions: [
          NotificationAction(
            DesktopNotificationActions.openChat.name,
            L10n.of(context).openChat,
          ),
          NotificationAction(
            DesktopNotificationActions.seen.name,
            L10n.of(context).markAsRead,
          ),
        ],
        hints: [
          NotificationHint.soundName('message-new-instant'),
        ],
      );
      notification.action.then((actionStr) {
        final action = DesktopNotificationActions.values
            .singleWhere((a) => a.name == actionStr);
        switch (action) {
          case DesktopNotificationActions.seen:
            room.setReadMarker(
              event.eventId,
              mRead: event.eventId,
              public: AppConfig.sendPublicReadReceipts,
            );
            break;
          case DesktopNotificationActions.openChat:
            context.go('/rooms/${room.id}');
            break;
        }
      });
      linuxNotificationIds[roomId] = notification.id;
    } else if (Platform.isWindows) {
      final notification = LocalNotification(
        title: title,
        body: body,
      );

      final relationshipType =
          event.relationshipType == RelationshipTypes.thread;
      final relationshipEventId = event.relationshipEventId;
      final eventId = event.eventId;
      notification.onClick = () async {
        await windowManager.show();
        await windowManager.restore();
        await windowManager.focus();

        if (relationshipType) {
          navigatorKey.currentContext!.go(
            '/${Uri(
              pathSegments: ['rooms', room.id],
              queryParameters: {
                'threadEvent': eventId,
                'event': event.relationshipEventId,
                'thread': relationshipEventId,
              },
            )}',
          );
        } else {
          navigatorKey.currentContext!.go(
            '/${Uri(
              pathSegments: ['rooms', room.id],
              queryParameters: {'event': eventId},
            )}',
          );
        }
      };

      notification.show();
    }
  }
}

enum DesktopNotificationActions { seen, openChat }
