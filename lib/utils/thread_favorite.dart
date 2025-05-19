import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ThreadFavorite {
  static final ThreadFavorite _instance = ThreadFavorite._internal();
  static const String _storeKey = 'favorite_threads';
  late SharedPreferences _store;
  Map<String, List<String>> favoriteThreads = {};

  factory ThreadFavorite() => _instance;

  ThreadFavorite._internal() {
    _initStore();
  }

  Future<void> _initStore() async {
    _store = await SharedPreferences.getInstance();
    _loadFromStore();
  }

  void _loadFromStore() {
    final storedData = _store.getString(_storeKey);
    if (storedData != null) {
      final Map<String, dynamic> decoded = json.decode(storedData);
      favoriteThreads = decoded.map((key, value) => 
        MapEntry(key, List<String>.from(value)),);
    }
  }

  void _saveToStore() {
    _store.setString(_storeKey, json.encode(favoriteThreads));
  }

  void setFavorite(String roomId, String threadId, bool isFavorite) {
    if (!favoriteThreads.containsKey(roomId)) {
      favoriteThreads[roomId] = [];
    }

    if (isFavorite && !favoriteThreads[roomId]!.contains(threadId)) {
      favoriteThreads[roomId]!.add(threadId);
    } else if (!isFavorite) {
      favoriteThreads[roomId]!.remove(threadId);
      if (favoriteThreads[roomId]!.isEmpty) {
        favoriteThreads.remove(roomId);
      }
    }
    _saveToStore();
  }

  bool isFavorite(String roomId, String threadId) {
    return favoriteThreads[roomId]?.contains(threadId) ?? false;
  }

  List<String> getFavoriteThreads(String roomId) {
    return favoriteThreads[roomId] ?? [];
  }

  bool hasRoomFavorites(String roomId) {
    return favoriteThreads.containsKey(roomId) && 
           favoriteThreads[roomId]!.isNotEmpty;
  }
}
