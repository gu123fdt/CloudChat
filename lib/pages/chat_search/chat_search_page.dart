import 'dart:async';

import 'package:flutter/material.dart';

import 'package:matrix/matrix.dart';

import 'package:cloudchat/pages/chat_search/chat_search_view.dart';
import 'package:cloudchat/widgets/matrix.dart';

class ChatSearchPage extends StatefulWidget {
  final String? roomId;
  final bool? isGlobal;
  final String? searchQuery;
  const ChatSearchPage(
      {this.roomId = "",
      this.isGlobal = false,
      this.searchQuery = "",
      super.key,});

  @override
  ChatSearchController createState() => ChatSearchController();
}

class ChatSearchController extends State<ChatSearchPage>
    with SingleTickerProviderStateMixin {
  Room? get room => Matrix.of(context).client.getRoomById(widget.roomId ?? "");
  List<Room> rooms = List.empty();

  final TextEditingController searchController = TextEditingController();
  late final TabController tabController;

  Timeline? timeline;
  Map<String, Timeline> timelines = <String, Timeline>{};

  Stream<(List<Event>, String?)>? searchStream;
  Map<String, Stream<(List<Event>, String?)>> searchStreams =
      <String, Stream<(List<Event>, String?)>>{};
  Map<String, StreamSubscription> searchStreamsSubscriptions =
      <String, StreamSubscription>{};
  StreamSubscription? searchStreamSubscription;

  Stream<(List<Event>, String?)>? galleryStream;
  Stream<(List<Event>, String?)>? fileStream;

  List<Event> messageEvents = [];

  String oldSearchString = "";

  void _combineSearchStreams() async {
    messageEvents = [];
    for (final subscription in searchStreamsSubscriptions.values) {
      subscription.cancel();
    }

    if (widget.isGlobal!) {
      if (searchStreams.isEmpty) return;

      final streams = searchStreams.values.toList();

      for (var i = 0; i < streams.length; i++) {
        searchStreamsSubscriptions[rooms[i].id] = streams[i].listen(
          (result) {
            setState(() {
              final existingEventIds =
                  messageEvents.map((e) => e.eventId).toSet();

              final uniqueEvents = result.$1
                  .where((event) => !existingEventIds.contains(event.eventId))
                  .toList();

              messageEvents.addAll(uniqueEvents);
              messageEvents
                  .sort((a, b) => b.originServerTs.compareTo(a.originServerTs));
            });
          },
          onDone: () {
            searchStreamsSubscriptions[rooms[i].id]!.cancel();
            searchStreamsSubscriptions.remove(rooms[i].id);
          },
        );
      }
    } else {
      if (searchStream == null) return;
      searchStreamSubscription = searchStream!.listen(
        (result) {
          setState(() {
            final existingEventIds =
                messageEvents.map((e) => e.eventId).toSet();

            final uniqueEvents = result.$1
                .where((event) => !existingEventIds.contains(event.eventId))
                .toList();

            messageEvents.addAll(uniqueEvents);
          });
        },
        onDone: () {
          searchStreamSubscription!.cancel();
          searchStreamSubscription = null;
        },
      );
    }
  }

  void restartSearch() {
    if (searchController.text.isEmpty) {
      setState(() {
        searchStream = null;
      });
      return;
    }
    setState(() {
      searchStream = const Stream.empty();
    });
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      startMessageSearch();
    });
  }

  void setMessageEvents() {}

  void startMessageSearch({
    String? prevBatch,
    List<Event>? previousSearchResult,
  }) async {
    setState(() {
      oldSearchString = searchController.text;
    });

    if (tabController.index == 0 && searchController.text.isEmpty) {
      return;
    }

    for (var i = 0; i < rooms.length; i++) {
      Timeline timeline;

      if (widget.isGlobal!) {
        timeline = timelines[rooms[i].id] ??= await rooms[i].getTimeline();
      } else {
        timeline = this.timeline ??= await room!.getTimeline();
      }

      final searchStream = timeline
          .startSearch(
            searchTerm: searchController.text,
            prevBatch: prevBatch,
            requestHistoryCount: 1000,
            limit: 200,
          )
          .map(
            (result) => (
              [
                if (previousSearchResult != null) ...previousSearchResult,
                ...result.$1,
              ],
              result.$2,
            ),
          )
          // Deduplication workaround for
          // https://github.com/famedly/matrix-dart-sdk/issues/1831
          .map(
            (result) => (
              <String, Event>{
                for (final event in result.$1) event.eventId: event,
              }.values.toList(),
              result.$2,
            ),
          )
          .asBroadcastStream();

      if (widget.isGlobal!) {
        setState(() {
          searchStreams[rooms[i].id] = searchStream;
        });
      } else {
        setState(() {
          this.searchStream = searchStream;
        });
      }
    }

    _combineSearchStreams();
  }

  void startGallerySearch({
    String? prevBatch,
    List<Event>? previousSearchResult,
  }) async {
    final timeline = this.timeline ??= await room!.getTimeline();

    setState(() {
      galleryStream = timeline
          .startSearch(
            searchFunc: (event) => {
              MessageTypes.Image,
              MessageTypes.Video,
            }.contains(event.messageType),
            prevBatch: prevBatch,
            requestHistoryCount: 1000,
            limit: 32,
          )
          .map(
            (result) => (
              [
                if (previousSearchResult != null) ...previousSearchResult,
                ...result.$1,
              ],
              result.$2,
            ),
          )
          // Deduplication workaround for
          // https://github.com/famedly/matrix-dart-sdk/issues/1831
          .map(
            (result) => (
              <String, Event>{
                for (final event in result.$1) event.eventId: event,
              }.values.toList(),
              result.$2,
            ),
          )
          .asBroadcastStream();
    });
  }

  void startFileSearch({
    String? prevBatch,
    List<Event>? previousSearchResult,
  }) async {
    final timeline = this.timeline ??= await room!.getTimeline();

    setState(() {
      fileStream = timeline
          .startSearch(
            searchFunc: (event) =>
                event.messageType == MessageTypes.File ||
                (event.messageType == MessageTypes.Audio &&
                    !event.content.containsKey('org.matrix.msc3245.voice')),
            prevBatch: prevBatch,
            requestHistoryCount: 1000,
            limit: 32,
          )
          .map(
            (result) => (
              [
                if (previousSearchResult != null) ...previousSearchResult,
                ...result.$1,
              ],
              result.$2,
            ),
          )
          // Deduplication workaround for
          // https://github.com/famedly/matrix-dart-sdk/issues/1831
          .map(
            (result) => (
              <String, Event>{
                for (final event in result.$1) event.eventId: event,
              }.values.toList(),
              result.$2,
            ),
          )
          .asBroadcastStream();
    });
  }

  void _onTabChanged() {
    switch (tabController.index) {
      case 1:
        startGallerySearch();
        break;
      case 2:
        startFileSearch();
        break;
      default:
        restartSearch();
        break;
    }
  }

  void _initRooms() {
    if (widget.isGlobal!) {
      rooms = Matrix.of(context).client.rooms.toList();
    } else {
      rooms = [room!];
    }
  }

  @override
  void initState() {
    super.initState();
    _initRooms();

    tabController = TabController(
        initialIndex: 0, length: room == null ? 1 : 3, vsync: this,);
    tabController.addListener(_onTabChanged);

    if (widget.isGlobal!) {
      searchController.text = widget.searchQuery!;

      startMessageSearch();
    }
  }

  @override
  void dispose() {
    tabController.removeListener(_onTabChanged);
    for (final subscription in searchStreamsSubscriptions.values) {
      subscription.cancel();
    }
    searchStreamSubscription!.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChatSearchView(this);
}
