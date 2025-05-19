
class ThreadUnreadData {
  static final ThreadUnreadData _instance = ThreadUnreadData._internal();

  factory ThreadUnreadData() => _instance;

  ThreadUnreadData._internal();

  Map<String, Map<String, List<String>>> unreadThreads = {};

  bool isUnreadThread(String roomId, String threadId, String userId) {
    if (unreadThreads[userId] == null) {
      unreadThreads[userId] = {};
    }

    if (unreadThreads[userId]![roomId] == null) {
      return false;
    }

    return unreadThreads[userId]![roomId]!.contains(threadId);
  }

  void setUnreadThread(String roomId, String threadId, String userId) {
    if (unreadThreads[userId] == null) {
      unreadThreads[userId] = {};
    }

    if (unreadThreads[userId]![roomId] == null) {
      unreadThreads[userId]![roomId] = [];
    }
    unreadThreads[userId]![roomId]!.add(threadId);
    unreadThreads[userId]![roomId] =
        unreadThreads[userId]![roomId]!.toSet().toList();
  }

  void setReadThread(String roomId, String threadId, String userId) {
    if (unreadThreads[userId] == null) {
      unreadThreads[userId] = {};
    }

    if (unreadThreads[userId]![roomId] != null) {
      if (unreadThreads[userId]![roomId]!.contains(threadId)) {
        unreadThreads[userId]![roomId]!.remove(threadId);
      }
    }
  }
}
