import 'package:cloudchat/widgets/matrix.dart';

class ThreadHighlights {
  static final ThreadHighlights _instance = ThreadHighlights._internal();

  factory ThreadHighlights() => _instance;

  ThreadHighlights._internal();

  Map<String, List<String>> highlightsThreads = {};

  bool isHighlightThread(String roomId, String threadId) {
    if (highlightsThreads[roomId] == null) {
      return false;
    }

    return highlightsThreads[roomId]!.contains(threadId);
  }

  void setHighlightThread(String roomId, String threadId) {
    if (highlightsThreads[roomId] == null) {
      highlightsThreads[roomId] = [];
    }
    highlightsThreads[roomId]!.add(threadId);
    highlightsThreads[roomId] = highlightsThreads[roomId]!.toSet().toList();
  }

  void setReadThread(String roomId, String threadId) {
    if (highlightsThreads[roomId] != null) {
      if (highlightsThreads[roomId]!.contains(threadId)) {
        highlightsThreads[roomId]!.remove(threadId);
      }
    }
  }

  bool hasHighlightThreads(String roomId) {
    return highlightsThreads[roomId]?.isNotEmpty ?? false;
  }

  void init(MatrixState matrix) async {
    final unreadRooms =
        matrix.client.rooms.where((room) => room.notificationCount > 0);

    for (var room in unreadRooms) {
      final timeline = await room.getTimeline();
      final events = timeline.events;

      while (true) {
        if (events.length >= room.notificationCount) {
          break;
        }

        await timeline.requestHistory(historyCount: 100);
      }

      events.forEach((event) {
        if (event.relationshipType == "m.thread") {
          if (event.body.contains("@room") ||
              (event.content['formatted_body'] as String)
                  .contains(room.client.userID!) ||
              (event.content['formatted_body'] as String).contains("@room")) {
            setHighlightThread(room.id, event.eventId);
          }
        }
      });

      timeline.cancelSubscriptions();
    }
  }
}
