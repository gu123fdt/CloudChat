import 'package:collection/collection.dart';
import 'package:cloudchat/utils/thread_unread_data.dart';
import 'package:cloudchat/widgets/matrix.dart';
import 'package:matrix/matrix.dart';

class HighlightsRoomsAndThreads {
  static final HighlightsRoomsAndThreads _instance =
      HighlightsRoomsAndThreads._internal();

  factory HighlightsRoomsAndThreads() => _instance;

  HighlightsRoomsAndThreads._internal();

  MatrixState? _matrix;

  Map<String, List<String>> highlightsThreads = {};

  List<String> highlightsRooms = [];

  bool isHighlightThread(String roomId, String threadId) {
    if (highlightsThreads[roomId] == null) {
      return false;
    }

    return highlightsThreads[roomId]!.contains(threadId);
  }

  bool isHighlightRoom(String roomId) {
    return highlightsRooms.contains(roomId);
  }

  void setHighlightThread(String roomId, String threadId) {
    if (highlightsThreads[roomId] == null) {
      highlightsThreads[roomId] = [];
    }
    highlightsThreads[roomId]!.add(threadId);
    highlightsThreads[roomId] = highlightsThreads[roomId]!.toSet().toList();
  }

  void setHighlightRoom(String roomId) {
    if (!highlightsRooms.contains(roomId)) {
      highlightsRooms.add(roomId);
    }
  }

  void setReadThread(String roomId, String threadId) {
    if (highlightsThreads[roomId] != null) {
      if (highlightsThreads[roomId]!.contains(threadId)) {
        highlightsThreads[roomId]!.remove(threadId);
      }
    }
  }

  void setReadRoom(String roomId) {
    if (highlightsRooms.contains(roomId)) {
      highlightsRooms.remove(roomId);
    }
  }

  bool hasHighlightThreads(String roomId) {
    return highlightsThreads[roomId]?.isNotEmpty ?? false;
  }

  Future<bool> isHighlightThreadFromEvent(
      {String? eventId, Event? event, String? roomId,}) async {
    try {
      if ((eventId == null && roomId == null) && event == null) {
        return false;
      }

      if (event == null) {
        final room = _matrix!.client.getRoomById(roomId!);

        if (room != null) {
          event = await room.getEventById(eventId!);
        }
      }

      if (event != null) {
        if (event.body.contains("@room") ||
            (event.content['formatted_body'] as String)
                .contains(_matrix!.client.userID!) ||
            (event.content['formatted_body'] as String).contains("@room")) {
          if (event.relationshipType == "m.thread") {
            return true;
          }
        }
      }
    } catch (_) {}

    return false;
  }

  Future<bool> isHighlightRoomFromEvent(
      {String? eventId, Event? event, String? roomId,}) async {
    try {
      if ((eventId == null && roomId == null) && event == null) {
        return false;
      }

      if (event == null) {
        final room = _matrix!.client.getRoomById(roomId!);

        if (room != null) {
          event = await room.getEventById(eventId!);
        }
      }

      if (event != null) {
        if (event.body.contains("@room") ||
            (event.content['formatted_body'] as String)
                .contains(_matrix!.client.userID!) ||
            (event.content['formatted_body'] as String).contains("@room")) {
          if (event.relationshipType != "m.thread") {
            return true;
          }
        }
      }
    } catch (_) {}

    return false;
  }

  void init(MatrixState matrix) async {
    _matrix = matrix;

    highlightsRooms = [];
    highlightsThreads = {};

    String? next;

    while (true) {
      final notificationsPart =
          await matrix.client.getNotifications(from: next);

      next = notificationsPart.nextToken;

      if (notificationsPart.notifications.isNotEmpty) {
        final rooms =
            groupBy(notificationsPart.notifications, (final e) => e.roomId);

        rooms.forEach((roomId, notifications) async {
          final room = matrix.client.getRoomById(roomId);

          if (room != null) {
            var events = <Event>[];

            for (final notification in notifications) {
              final event = await room.getEventById(notification.event.eventId);

              if (event != null) {
                events.add(event);
              }
            }

            for (final event in events) {
              if (event.relationshipType == "m.thread") {
                ThreadUnreadData().setUnreadThread(
                    roomId, event.relationshipEventId!, matrix.client.userID!,);
              }

              if (event.relationshipType == "m.thread" &&
                  await isHighlightThreadFromEvent(
                      event: event, roomId: roomId,)) {
                setHighlightThread(roomId, event.relationshipEventId!);
              } else if (await isHighlightRoomFromEvent(
                  event: event, roomId: roomId,)) {
                setHighlightRoom(roomId);
              }
            }
          }
        });
      } else {
        break;
      }
    }
  }
}
