import 'package:matrix/matrix.dart';
import 'dart:collection';

class AllThreadCacheService {
  static final AllThreadCacheService _instance =
      AllThreadCacheService._internal();

  factory AllThreadCacheService() => _instance;

  AllThreadCacheService._internal();

  final Map<String, int> _roomThreadCounts = {};
  final LinkedHashMap<String, List<Event>> _roomThreads = LinkedHashMap();

  static const int _maxRooms = 50;
  static const int _maxEventsPerRoom = 100;

  int? getThreadCount(String roomId) => _roomThreadCounts[roomId];

  void setThreadCount(String roomId, int count) {
    _roomThreadCounts[roomId] = count;
  }

  bool hasThreads(String roomId) => _roomThreads.containsKey(roomId);

  List<Event> getThreads(String roomId) => _roomThreads[roomId] ?? [];

  void setThreads(String roomId, List<Event> threads) {
    if (_roomThreads.containsKey(roomId) || _roomThreads.length < _maxRooms) {
      final limitedThreads = threads.length > _maxEventsPerRoom
          ? threads.sublist(0, _maxEventsPerRoom)
          : threads;

      _roomThreads[roomId] = limitedThreads;
    }
  }

  void clearRoomCache(String roomId) {
    _roomThreadCounts.remove(roomId);
    _roomThreads.remove(roomId);
  }

  void clearAll() {
    _roomThreadCounts.clear();
    _roomThreads.clear();
  }

  List<String> get roomsWithThreads => _roomThreadCounts.entries
      .where((e) => e.value > 0)
      .map((e) => e.key)
      .toList();
}
