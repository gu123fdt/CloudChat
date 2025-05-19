import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:cloudchat/pages/all_threads/all_threads_view.dart';
import 'package:cloudchat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:cloudchat/utils/thread_favorite.dart';
import 'package:cloudchat/utils/highlights_rooms_and_threads.dart';
import 'package:cloudchat/utils/thread_unread_data.dart';
import 'package:cloudchat/widgets/matrix.dart';
import 'package:matrix/matrix.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';

import 'all_threads_cache.dart';

class AllThreads extends StatefulWidget {
  final String? roomId;
  final String? roomsSearch;
  final String? threadsSearch;

  const AllThreads({
    super.key,
    this.roomId,
    this.roomsSearch,
    this.threadsSearch,
  });

  @override
  AllThreadsController createState() => AllThreadsController();
}

class AllThreadsController extends State<AllThreads> {
  List<Room> rooms = [];
  List<Room> filteredRooms = [];

  Map<String, int> roomsThreadCounts = {};

  TextEditingController searchRoomsController = TextEditingController();
  TextEditingController searchThreadsController = TextEditingController();

  String? roomId;
  List<Event> roomThreads = [];
  List<Event> filteredRoomThreads = [];

  ThreadUnreadData threadUnreadData = ThreadUnreadData();

  void filter() {
    if (roomId == null) {
      _filterRooms();
    } else {
      _filterRoomThreads();
    }
  }

  void _filterRooms() async {
    setState(() {
      List<Room> filtered;
      if (searchRoomsController.text.isEmpty) {
        filtered =
            rooms.where((room) => roomsThreadCounts[room.id] != 0).toList();
      } else {
        filtered = rooms
            .where(
              (room) =>
                  room.getLocalizedDisplayname().toLowerCase().contains(
                        searchRoomsController.text.toLowerCase().trim(),
                      ) &&
                  roomsThreadCounts[room.id] != 0,
            )
            .toList();
      }

      filtered.sort((a, b) {
        final aHasHighlights =
            HighlightsRoomsAndThreads().hasHighlightThreads(a.id);
        final bHasHighlights =
            HighlightsRoomsAndThreads().hasHighlightThreads(b.id);
        if (aHasHighlights && !bHasHighlights) return -1;
        if (!aHasHighlights && bHasHighlights) return 1;

        final aIsFavorite = ThreadFavorite().hasRoomFavorites(a.id);
        final bIsFavorite = ThreadFavorite().hasRoomFavorites(b.id);
        if (aIsFavorite && !bIsFavorite) return -1;
        if (!aIsFavorite && bIsFavorite) return 1;

        return 0;
      });

      filteredRooms = filtered;
    });
  }

  void _filterRoomThreads() async {
    setState(() {
      if (searchThreadsController.text.isEmpty) {
        filteredRoomThreads = roomThreads;
      } else {
        filteredRoomThreads = roomThreads
            .where(
              (event) =>
                  event.body.toLowerCase().contains(
                        searchThreadsController.text.toLowerCase().trim(),
                      ) ||
                  event.senderFromMemoryOrFallback
                      .calcDisplayname(
                        i18n: MatrixLocals(L10n.of(context)),
                      )
                      .toLowerCase()
                      .contains(
                        searchThreadsController.text.toLowerCase().trim(),
                      ) ||
                  event
                      .calcLocalizedBodyFallback(
                        plaintextBody: true,
                        removeMarkdown: true,
                        MatrixLocals(
                          L10n.of(context),
                        ),
                      )
                      .contains(
                        searchThreadsController.text.toLowerCase().trim(),
                      ),
            )
            .toList();
      }
    });
  }

  void updateUrl() {
    final uri = Uri.parse("/rooms/threads");
    final params = Map<String, String>.from(uri.queryParameters);

    if (roomId != null) params["roomId"] = roomId!;
    if (searchRoomsController.text.isNotEmpty) {
      params["roomsSearch"] = searchRoomsController.text;
    }
    if (searchThreadsController.text.isNotEmpty) {
      params["threadsSearch"] = searchThreadsController.text;
    }

    final updatedUri = uri.replace(queryParameters: params);
    context.go(updatedUri.toString());
  }

  void _loadThreadsCount() async {
    final cache = AllThreadCacheService();

    for (final room in rooms) {
      final threads =
          await Matrix.of(context).client.getThreadRoots(room.id, limit: 9999);

      cache.setThreadCount(room.id, threads.chunk.length);

      setState(() {
        roomsThreadCounts[room.id] = threads.chunk.length;
        filter();
      });
    }
  }

  void openThreads(String roomId) async {
    final cache = AllThreadCacheService();
    roomThreads = cache.getThreads(roomId);

    setState(() => this.roomId = roomId);

    updateUrl();

    final response =
        await Matrix.of(context).client.getThreadRoots(roomId, limit: 9999);

    response.chunk.forEach((mEvent) async {
      await rooms
          .firstWhere((room) => room.id == roomId)
          .getEventById(mEvent.eventId)
          .then((event) {
        setState(() {
          if (roomThreads.any((e) => e.eventId == event!.eventId)) {
            roomThreads[roomThreads
                .indexWhere((e) => e.eventId == event!.eventId)] = event!;
          } else {
            roomThreads.add(event!);
          }

          roomThreads.sort((a, b) {
            final aIsHighlight = HighlightsRoomsAndThreads()
                .isHighlightThread(roomId, a.eventId);
            final bIsHighlight = HighlightsRoomsAndThreads()
                .isHighlightThread(roomId, b.eventId);

            if (aIsHighlight && !bIsHighlight) return -1;
            if (!aIsHighlight && bIsHighlight) return 1;

            final aIsFavorite = ThreadFavorite().isFavorite(roomId, a.eventId);
            final bIsFavorite = ThreadFavorite().isFavorite(roomId, b.eventId);

            if (aIsFavorite && !bIsFavorite) return -1;
            if (!aIsFavorite && bIsFavorite) return 1;

            return b.originServerTs.compareTo(a.originServerTs);
          });
          filter();

          cache.setThreads(roomId, roomThreads);
        });

        filter();
      });
    });
  }

  void goBackToRoomList() {
    setState(() {
      roomId = null;
      roomThreads = [];
      filteredRoomThreads = [];
      searchThreadsController.text = "";
    });

    updateUrl();
  }

  @override
  void initState() {
    super.initState();

    rooms = Matrix.of(context).client.rooms;

    final cache = AllThreadCacheService();

    for (final room in rooms) {
      final count = cache.getThreadCount(room.id);
      if (count != null) {
        roomsThreadCounts[room.id] = count;
      }
    }

    filteredRooms = rooms;
    filter();

    _loadThreadsCount();

    if (widget.roomsSearch != null) {
      searchRoomsController.text = widget.roomsSearch!;
      filter();
    }
    if (widget.threadsSearch != null) {
      searchThreadsController.text = widget.threadsSearch!;
    }

    if (widget.roomId != null) {
      openThreads(widget.roomId!);
    }
  }

  void setFavoriteThread(String eventId) {
    setState(() {
      ThreadFavorite().setFavorite(
        roomId!,
        eventId,
        !ThreadFavorite().isFavorite(roomId!, eventId),
      );
    });
  }

  @override
  Widget build(BuildContext context) => AllThreadsView(this);
}
