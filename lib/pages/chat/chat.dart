import 'dart:async';
import 'dart:io';

import 'package:cloudchat/pages/chat/jitsi_dialog.dart';
import 'package:cloudchat/utils/thread_favorite.dart';
import 'package:cloudchat/utils/highlights_rooms_and_threads.dart';
import 'package:cloudchat/utils/thread_unread_data.dart';
import 'package:cloudchat/utils/voip/voip_service.dart';
import 'package:cloudchat/widgets/resizable_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:collection/collection.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:matrix/matrix.dart';
import 'package:record/record.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_html/html.dart' as html;

import 'package:cloudchat/config/app_config.dart';
import 'package:cloudchat/config/setting_keys.dart';
import 'package:cloudchat/config/themes.dart';
import 'package:cloudchat/pages/chat/chat_view.dart';
import 'package:cloudchat/pages/chat/event_info_dialog.dart';
import 'package:cloudchat/pages/chat/recording_dialog.dart';
import 'package:cloudchat/pages/chat_details/chat_details.dart';
import 'package:cloudchat/utils/error_reporter.dart';
import 'package:cloudchat/utils/file_selector.dart';
import 'package:cloudchat/utils/matrix_sdk_extensions/event_extension.dart';
import 'package:cloudchat/utils/matrix_sdk_extensions/filtered_timeline_extension.dart';
import 'package:cloudchat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:cloudchat/utils/platform_infos.dart';
import 'package:cloudchat/utils/show_scaffold_dialog.dart';
import 'package:cloudchat/widgets/future_loading_dialog.dart';
import 'package:cloudchat/widgets/matrix.dart';
import 'package:cloudchat/widgets/share_scaffold_dialog.dart';
import '../../utils/account_bundles.dart';
import '../../utils/localized_exception_extension.dart';
import 'send_file_dialog.dart';
import 'send_location_dialog.dart';

class ChatPage extends StatelessWidget {
  final String roomId;
  final List<ShareItem>? shareItems;
  final String? eventId;
  final String? eventIdInThread;
  final String? thread;
  final String? from;

  const ChatPage({
    super.key,
    required this.roomId,
    this.eventId,
    this.eventIdInThread,
    this.shareItems,
    this.thread,
    this.from,
  });

  @override
  Widget build(BuildContext context) {
    final room = Matrix.of(context).client.getRoomById(roomId);

    if (room == null) {
      return Scaffold(
        appBar: AppBar(title: Text(L10n.of(context).oopsSomethingWentWrong)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(L10n.of(context).youAreNoLongerParticipatingInThisChat),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            Offstage(
              offstage:
                  thread != null
                      ? !CloudThemes.isThreeColumnMode(context)
                      : false,
              child: ResizableWidget(
                minWidthPercent:
                    (AppConfig.columnWidth / constraints.maxWidth) * 100,
                maxWidthPercent:
                    100.0 -
                    (AppConfig.columnWidth / constraints.maxWidth) * 100,
                initialWidthPercent: 50.0,
                screenWidth: constraints.maxWidth,
                active: thread != null,
                child: ChatPageWithRoom(
                  key: Key('chat_page_${roomId}_$eventId'),
                  room: room,
                  shareItems: shareItems,
                  eventId: eventId,
                  isOpenThread: thread != null,
                  from: from,
                ),
              ),
            ),
            if (thread != null)
              Expanded(
                child: ChatPageWithRoom(
                  key: Key('chat_page_${roomId}_${thread}_$eventId'),
                  room: room,
                  shareItems: shareItems,
                  eventId: eventIdInThread,
                  thread: thread,
                  from: from,
                ),
              ),
          ],
        );
      },
    );
  }
}

class ChatPageWithRoom extends StatefulWidget {
  final Room room;
  final List<ShareItem>? shareItems;
  final String? eventId;
  final String? thread;
  final bool? isOpenThread;
  final String? from;

  const ChatPageWithRoom({
    super.key,
    required this.room,
    this.shareItems,
    this.eventId,
    this.thread,
    this.isOpenThread,
    this.from,
  });

  @override
  ChatController createState() => ChatController();
}

class ChatController extends State<ChatPageWithRoom>
    with WidgetsBindingObserver {
  Room get room => sendingClient.getRoomById(roomId) ?? widget.room;

  late Client sendingClient;

  Timeline? timeline;

  late final String readMarkerEventId;

  String get roomId => widget.room.id;

  String? get thread => widget.thread;
  bool? get isOpenThread => widget.isOpenThread;

  final AutoScrollController scrollController = AutoScrollController();

  bool isFavoriteThread = false;

  FocusNode inputFocus = FocusNode();
  StreamSubscription<html.Event>? onFocusSub;

  Timer? typingCoolDown;
  Timer? typingTimeout;
  bool currentlyTyping = false;
  bool dragging = false;

  bool isMDEditor = false;

  ThreadUnreadData threadUnreadData = ThreadUnreadData();

  bool isThread() {
    return thread != null;
  }

  void onDragEntered(_) => setState(() => dragging = true);

  void onDragExited(_) => setState(() => dragging = false);

  void onDragDone(DropDoneDetails details) async {
    setState(() => dragging = false);
    if (details.files.isEmpty) return;

    await showAdaptiveDialog(
      context: context,
      builder:
          (c) => SendFileDialog(
            files: details.files,
            room: room,
            outerContext: context,
            threadRootEventId: thread,
            threadLastEventId: threadLastEventId,
          ),
    );
  }

  bool get canSaveSelectedEvent =>
      selectedEvents.length == 1 &&
      {
        MessageTypes.Video,
        MessageTypes.Image,
        MessageTypes.Sticker,
        MessageTypes.Audio,
        MessageTypes.File,
      }.contains(selectedEvents.single.messageType);

  void saveSelectedEvent(context) => selectedEvents.single.saveFile(context);

  void onCreateLink(Event event) {
    Clipboard.setData(
      ClipboardData(text: "https://matrix.to/#/$roomId/${event.eventId}"),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(L10n.of(context).copySuccessfully),
        action: SnackBarAction(
          label: L10n.of(context).close,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  bool canCreateLink(Event event) {
    return !isArchived && event.status.isSent && event.canRedact != false;
  }

  List<Event> selectedEvents = [];

  Event? hoveredEvent;

  final Set<String> unfolded = {};

  Event? replyEvent;

  Event? editEvent;

  bool _scrolledUp = false;

  bool get showScrollDownButton =>
      _scrolledUp || timeline?.allowNewEvent == false;

  bool get selectMode => selectedEvents.isNotEmpty;

  final int _loadHistoryCount = 100;

  String pendingText = '';

  bool showEmojiPicker = false;

  String? threadLastEventId;

  bool isSelectedText = false;
  String selectedText = "";

  bool detectReplyFromThread(Event event) {
    if (event.formattedText.isNotEmpty &&
        event.relationshipType == RelationshipTypes.thread) {
      return event.formattedText.contains("<mx-reply>");
    } else {
      return false;
    }
  }

  String getReplyEventIdFromThread(Event event) {
    if (event.formattedText.contains("<mx-reply>") &&
        event.relationshipType == RelationshipTypes.thread) {
      final linkRegExp = RegExp(r'<a href="([^"]+)">');
      final Match? linkMatch = linkRegExp.firstMatch(event.formattedText);

      if (linkMatch != null) {
        final fullLink = linkMatch.group(1) ?? "";

        return fullLink.split('/').last;
      } else {
        return "";
      }
    } else {
      return "";
    }
  }

  Event? getReplyEventFromThread(String eventId, List<Event> events) {
    return events.firstWhereOrNull((event) => event.eventId == eventId);
  }

  void recreateChat() async {
    final room = this.room;
    final userId = room.directChatMatrixID;
    if (userId == null) {
      throw Exception(
        'Try to recreate a room with is not a DM room. This should not be possible from the UI!',
      );
    }
    await showFutureLoadingDialog(
      context: context,
      future: () => room.invite(userId),
    );
  }

  bool isMentionEvent(Event event) {
    try {
      if (event.body.contains("@room") ||
          (event.content['formatted_body'] as String).contains(
            room.client.userID!,
          ) ||
          (event.content['formatted_body'] as String).contains("@room")) {
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  void leaveChat() async {
    final success = await showFutureLoadingDialog(
      context: context,
      future: room.leave,
    );
    if (success.error != null) return;
    context.go('/rooms');
  }

  void startThread(Event event) async {
    if (!event.redacted && !isThread()) {
      if (_displayChatDetailsColumn.value) {
        await Matrix.of(context).store.setBool(
          SettingKeys.displayChatDetailsColumn,
          !_displayChatDetailsColumn.value,
        );
        _displayChatDetailsColumn.value = !_displayChatDetailsColumn.value;
      }

      context.go('/rooms/${widget.room.id}/?thread=${event.eventId}');
    }
  }

  void setMDEditor() {
    setState(() {
      isMDEditor = !isMDEditor;
      showEmojiPicker = false;
    });
  }

  void setThreadLastEventId(String eventId) {
    setState(() => threadLastEventId = eventId);
  }

  void closeThread() async {
    if (isThread()) {
      context.go('/rooms/${widget.room.id}', extra: {'from': widget.from});
    }
  }

  EmojiPickerType emojiPickerType = EmojiPickerType.keyboard;

  void requestHistory([_]) async {
    Logs().v('Requesting history...');
    await timeline?.requestHistory(historyCount: _loadHistoryCount);
  }

  void requestFuture() async {
    final timeline = this.timeline;
    if (timeline == null) return;
    Logs().v('Requesting future...');
    final mostRecentEventId = getFilteredEvents().first.eventId;
    await timeline.requestFuture(historyCount: _loadHistoryCount);
    setReadMarker(eventId: mostRecentEventId);
  }

  void _updateScrollController() {
    if (!mounted) {
      return;
    }
    if (!scrollController.hasClients) return;
    if (timeline?.allowNewEvent == false ||
        scrollController.position.pixels > 0 && _scrolledUp == false) {
      setState(() => _scrolledUp = true);
    } else if (scrollController.position.pixels <= 0 && _scrolledUp == true) {
      setState(() => _scrolledUp = false);
      setReadMarker();
    }

    if (scrollController.position.pixels == 0 ||
        scrollController.position.pixels == 64) {
      requestFuture();
    }
  }

  void _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draft = prefs.getString('draft_$roomId');
    if (draft != null && draft.isNotEmpty) {
      sendController.text = draft;
    }
  }

  void _shareItems([_]) {
    final shareItems = widget.shareItems;

    if (shareItems != null) {
      for (var i = 0; i < shareItems.length; i++) {
        if (shareItems[i] is ContentShareItem) {
          final item = shareItems[i] as ContentShareItem;
          if (item.value.containsKey("m.relates_to")) {
            final formattedBody = item.value["formatted_body"] as String?;
            if (formattedBody != null) {
              final cleanBody = formattedBody.replaceAll(
                RegExp(r'<mx-reply>.*?</mx-reply>'),
                '',
              );
              shareItems[i] = ContentShareItem({
                "body": cleanBody,
                "msgtype": "m.text",
              });
            }
          }
        }
      }
    }

    if (shareItems == null || shareItems.isEmpty) return;
    for (final item in shareItems) {
      if (item is FileShareItem) continue;
      if (item is TextShareItem) {
        room.sendTextEvent(
          item.value,
          parseMarkdown:
              ((item.value as ContentShareItem).value["body"] as String)
                  .trim()
                  .length >
              1,
        );
      }
      if (item is ContentShareItem) room.sendEvent(item.value);
    }
    final files =
        shareItems
            .whereType<FileShareItem>()
            .map((item) => item.value)
            .toList();
    if (files.isEmpty) return;
    showAdaptiveDialog(
      context: context,
      builder:
          (c) => SendFileDialog(
            files: files,
            room: room,
            outerContext: context,
            threadRootEventId: thread,
            threadLastEventId: threadLastEventId,
          ),
    );
  }

  void setFavoriteThread() {
    ThreadFavorite().setFavorite(roomId, thread!, !isFavoriteThread);

    setState(() {
      isFavoriteThread = !isFavoriteThread;
    });
  }

  @override
  void initState() {
    ThreadFavorite();

    sendingClient = Matrix.of(context).client;

    if (isThread()) {
      threadUnreadData.setReadThread(roomId, thread!, room.client.userID!);
      HighlightsRoomsAndThreads().setReadThread(roomId, thread!);

      setState(() {
        isFavoriteThread = ThreadFavorite().isFavorite(roomId, thread!);
      });
    }

    scrollController.addListener(_updateScrollController);
    inputFocus.addListener(_inputFocusListener);

    _loadDraft();
    WidgetsBinding.instance.addPostFrameCallback(_shareItems);
    super.initState();
    _displayChatDetailsColumn = ValueNotifier(
      Matrix.of(context).store.getBool(SettingKeys.displayChatDetailsColumn) ??
          false,
    );

    readMarkerEventId = room.hasNewMessages ? room.fullyRead : '';
    WidgetsBinding.instance.addObserver(this);
    _tryLoadTimeline();
    if (kIsWeb) {
      onFocusSub = html.window.onFocus.listen((_) => setReadMarker());
    }

    sendController.addListener(_onSelectionChanged);
  }

  void _onSelectionChanged() {
    final selection = sendController.selection;
    if (selection.start != selection.end) {
      setState(() {
        isSelectedText = true;
        selectedText = sendController.text.substring(
          selection.start,
          selection.end,
        );
      });
    } else {
      setState(() {
        isSelectedText = false;
        selectedText = "";
      });
    }
  }

  void addLinkToSelectedText() async {
    final l10n = L10n.of(context);

    final input = await showTextInputDialog(
      context: context,
      title: l10n.addLink,
      okLabel: l10n.ok,
      cancelLabel: l10n.cancel,
      textFields: [
        DialogTextField(
          validator: (text) {
            if (text == null || text.isEmpty) {
              return l10n.pleaseFillOut;
            }
            try {
              text.startsWith('http') ? Uri.parse(text) : Uri.https(text);
            } catch (_) {
              return l10n.invalidUrl;
            }
            return null;
          },
          hintText: 'www...',
          keyboardType: TextInputType.url,
        ),
      ],
    );
    final urlString = input?.singleOrNull;
    if (urlString == null) return;
    final url =
        urlString.startsWith('http')
            ? Uri.parse(urlString)
            : Uri.https(urlString);
    final selection = sendController.selection;
    sendController.text = sendController.text.replaceRange(
      selection.start,
      selection.end,
      '[$selectedText](${url.toString()})',
    );
    ContextMenuController.removeAny();
  }

  void setSelectedTextBold() {
    final selection = sendController.selection;
    sendController.text = sendController.text.replaceRange(
      selection.start,
      selection.end,
      '**$selectedText**',
    );
    ContextMenuController.removeAny();
  }

  void setSelectedTextItalic() {
    final selection = sendController.selection;
    sendController.text = sendController.text.replaceRange(
      selection.start,
      selection.end,
      '*$selectedText*',
    );
    ContextMenuController.removeAny();
  }

  void setSelectedTextStrikethrough() {
    final selection = sendController.selection;
    sendController.text = sendController.text.replaceRange(
      selection.start,
      selection.end,
      '~~$selectedText~~',
    );
    ContextMenuController.removeAny();
  }

  void _tryLoadTimeline() async {
    if (widget.eventId != null && !isThread() && isOpenThread != true) {
      final event = await room.getEventById(widget.eventId!);
      if (event != null && event.relationshipType == RelationshipTypes.thread) {
        context.go(
          '/rooms/${room.id}?thread=${event.relationshipEventId}&event=${event.relationshipEventId}&threadEvent=${event.eventId}',
        );
      }
    }

    loadTimelineFuture = _getTimeline();
    try {
      await loadTimelineFuture;
      if (widget.eventId != null) scrollToEventId(widget.eventId!);

      if (isThread()) {
        setReadMarker();
      }

      var readMarkerEventIndex =
          readMarkerEventId.isEmpty
              ? -1
              : getFilteredEvents()
                  .filterByVisibleInGui(exceptionEventId: readMarkerEventId)
                  .indexWhere((e) => e.eventId == readMarkerEventId);

      // Read marker is existing but not found in first events. Try a single
      // requestHistory call before opening timeline on event context:
      if (readMarkerEventId.isNotEmpty && readMarkerEventIndex == -1) {
        await timeline?.requestHistory(historyCount: _loadHistoryCount);
        readMarkerEventIndex = getFilteredEvents()
            .filterByVisibleInGui(exceptionEventId: readMarkerEventId)
            .indexWhere((e) => e.eventId == readMarkerEventId);
      }

      if (readMarkerEventIndex > 1) {
        Logs().v('Scroll up to visible event', readMarkerEventId);
        scrollToEventId(readMarkerEventId, highlightEvent: false);
        return;
      } else if (readMarkerEventId.isNotEmpty && readMarkerEventIndex == -1) {
        _showScrollUpMaterialBanner(readMarkerEventId);
      }

      // Mark room as read on first visit if requirements are fulfilled
      setReadMarker();

      if (!mounted) return;
    } catch (e, s) {
      ErrorReporter(context, 'Unable to load timeline').onErrorCallback(e, s);
      rethrow;
    }
  }

  String? scrollUpBannerEventId;
  bool? scrollUpBannerEventIsThread;
  String? scrollUpBannerEventRelationshipEventId;
  void discardScrollUpBannerEventId() => setState(() {
    scrollUpBannerEventId = null;
  });

  void _showScrollUpMaterialBanner(String eventId) => setState(() {
    scrollUpBannerEventId = eventId;
  });

  void updateView() {
    if (!mounted) return;
    if (isThread()) {
      threadUnreadData.setReadThread(roomId, thread!, room.client.userID!);
      HighlightsRoomsAndThreads().setReadThread(roomId, thread!);
    }
    setReadMarker();
    setState(() {});
  }

  Future<void>? loadTimelineFuture;

  int? animateInEventIndex;

  void onInsert(int i) {
    // setState will be called by updateView() anyway
    animateInEventIndex = i;
  }

  Future<void> _getTimeline({String? eventContextId}) async {
    await Matrix.of(context).client.roomsLoading;
    await Matrix.of(context).client.accountDataLoading;
    if (eventContextId != null &&
        (!eventContextId.isValidMatrixId || eventContextId.sigil != '\$')) {
      eventContextId = null;
    }
    try {
      timeline?.cancelSubscriptions();
      timeline = await room.getTimeline(
        onUpdate: updateView,
        eventContextId: eventContextId,
        onInsert: onInsert,
      );
    } catch (e, s) {
      Logs().w('Unable to load timeline on event ID $eventContextId', e, s);
      if (!mounted) return;
      timeline = await room.getTimeline(
        onUpdate: updateView,
        onInsert: onInsert,
      );
      if (!mounted) return;
      if (e is TimeoutException || e is IOException) {
        final event = await timeline!.getEventById(eventContextId!);
        scrollUpBannerEventIsThread =
            event!.relationshipType == RelationshipTypes.thread;
        scrollUpBannerEventRelationshipEventId =
            scrollUpBannerEventIsThread == true
                ? event.relationshipEventId
                : null;
        _showScrollUpMaterialBanner(eventContextId);
      }
    }
    timeline!.requestKeys(onlineKeyBackupOnly: false);
    if (room.markedUnread) room.markUnread(false);

    if (eventContextId != null) {
      final event = await timeline!.getEventById(eventContextId);

      /*if (event != null && event.relationshipType == RelationshipTypes.thread) {
        context.go(
          '/${Uri(
            pathSegments: ['rooms', room.id],
            queryParameters: {
              'event': event.eventId,
              'threadEvent': event.relationshipEventId,
            },
          )}',
        );
      }*/
    }

    return;
  }

  String? scrollToEventIdMarker;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    setReadMarker();
  }

  Future<void>? _setReadMarkerFuture;

  void setReadMarker({String? eventId}) async {
    if (_setReadMarkerFuture != null) return;
    if (_scrolledUp) return;
    if (scrollUpBannerEventId != null) return;
    if (thread != null && eventId == null) return;

    if (eventId == null &&
        !room.hasNewMessages &&
        room.notificationCount == 0) {
      return;
    }

    // Do not send read markers when app is not in foreground
    if (kIsWeb && !Matrix.of(context).webHasFocus) return;
    if (!kIsWeb &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }

    final timeline = this.timeline;
    if (timeline == null || getFilteredEvents().isEmpty) return;

    if (!isThread()) {
      if (eventId == null &&
          timeline.room.lastEvent?.relationshipType ==
              RelationshipTypes.thread) {
        eventId = getFilteredEvents().last.eventId;
      }

      if (eventId != null) {
        final event = await room.getEventById(eventId);

        if (event == null &&
            event?.relationshipType == RelationshipTypes.thread) {
          return;
        }
      }
    }

    Logs().d('Set read marker...', eventId);
    // ignore: unawaited_futures
    _setReadMarkerFuture = timeline
        .setReadMarker(
          eventId: eventId,
          public: AppConfig.sendPublicReadReceipts,
        )
        .then((_) {
          _setReadMarkerFuture = null;
        });
    if (eventId == null || eventId == timeline.room.lastEvent?.eventId) {
      Matrix.of(context).backgroundPush?.cancelNotification(roomId);
      HighlightsRoomsAndThreads().setReadRoom(roomId);
    }
  }

  @override
  void dispose() {
    timeline?.cancelSubscriptions();
    timeline = null;
    inputFocus.removeListener(_inputFocusListener);
    onFocusSub?.cancel();
    super.dispose();
  }

  TextEditingController sendController = TextEditingController();

  void setSendingClient(Client c) {
    // first cancel typing with the old sending client
    if (currentlyTyping) {
      // no need to have the setting typing to false be blocking
      typingCoolDown?.cancel();
      typingCoolDown = null;
      room.setTyping(false);
      currentlyTyping = false;
    }
    // then cancel the old timeline
    // fixes bug with read reciepts and quick switching
    loadTimelineFuture = _getTimeline(eventContextId: room.fullyRead).onError(
      ErrorReporter(
        context,
        'Unable to load timeline after changing sending Client',
      ).onErrorCallback,
    );

    // then set the new sending client
    setState(() => sendingClient = c);
  }

  void setActiveClient(Client c) => setState(() {
    Matrix.of(context).setActiveClient(c);
  });

  Future<void> send() async {
    if (sendController.text.trim().isEmpty) return;
    _storeInputTimeoutTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('draft_$roomId');
    var parseCommands = true;

    final commandMatch = RegExp(r'^\/(\w+)').firstMatch(sendController.text);
    if (commandMatch != null &&
        !sendingClient.commands.keys.contains(commandMatch[1]!.toLowerCase())) {
      final l10n = L10n.of(context);
      final dialogResult = await showOkCancelAlertDialog(
        context: context,
        title: l10n.commandInvalid,
        message: l10n.commandMissing(commandMatch[0]!),
        okLabel: l10n.sendAsText,
        cancelLabel: l10n.cancel,
      );
      if (dialogResult == OkCancelResult.cancel) return;
      parseCommands = false;
    }

    // ignore: unawaited_futures
    room.sendTextEvent(
      sendController.text,
      inReplyTo: replyEvent,
      editEventId: editEvent?.eventId,
      parseCommands: parseCommands,
      parseMarkdown: sendController.text.trim().length > 1,
      threadRootEventId: thread,
      threadLastEventId: threadLastEventId,
    );
    sendController.value = TextEditingValue(
      text: pendingText,
      selection: const TextSelection.collapsed(offset: 0),
    );

    setState(() {
      sendController.text = pendingText;
      _inputTextIsEmpty = pendingText.isEmpty;
      replyEvent = null;
      editEvent = null;
      pendingText = '';
    });
  }

  void sendJitsiRoom(String roomName, List<String> userIds) async {
    final roomUrl =
        "${room.client.baseUri?.origin.replaceFirst(RegExp(r'(?<=//).*?(?=\.)'), 'meet')}/$roomName";

    final messageText = "$roomUrl\n${userIds.join(", ")}";

    room.sendTextEvent(
      messageText,
      parseMarkdown: messageText.trim().length > 1,
    );

    sendController.value = TextEditingValue(
      text: pendingText,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  void sendFileAction() async {
    final files = await selectFiles(context, allowMultiple: true);
    if (files.isEmpty) return;
    await showAdaptiveDialog(
      context: context,
      builder:
          (c) => SendFileDialog(
            files: files,
            room: room,
            outerContext: context,
            threadRootEventId: thread,
            threadLastEventId: threadLastEventId,
          ),
    );
  }

  void sendImageFromClipBoard(Uint8List? image) async {
    if (image == null) return;

    final directory = await getApplicationSupportDirectory();
    final tempDirectoryPath = '${directory.path}\\temp';
    Directory(tempDirectoryPath).createSync(recursive: true);
    final formattedDate = DateTime.now().toString().replaceAll(
      RegExp(r'[^0-9]'),
      '-',
    );
    final filePath = '$tempDirectoryPath\\$formattedDate-temp.png';
    final file = File(filePath);
    await file.writeAsBytes(image);

    await showAdaptiveDialog(
      context: context,
      builder:
          (c) => SendFileDialog(
            files: [XFile(filePath)],
            room: room,
            outerContext: context,
            threadRootEventId: thread,
            threadLastEventId: threadLastEventId,
          ),
    );
  }

  void sendFilesFromClipBoard(List<String> files) async {
    if (files.isEmpty) return;

    final xFiles = files.map((path) => XFile(path)).toList();

    await showAdaptiveDialog(
      context: context,
      builder:
          (c) => SendFileDialog(
            files: xFiles,
            room: room,
            outerContext: context,
            threadRootEventId: thread,
            threadLastEventId: threadLastEventId,
          ),
    );
  }

  void sendImageAction() async {
    final files = await selectFiles(
      context,
      allowMultiple: true,
      type: FileSelectorType.images,
    );
    if (files.isEmpty) return;

    await showAdaptiveDialog(
      context: context,
      builder:
          (c) => SendFileDialog(
            files: files,
            room: room,
            outerContext: context,
            threadRootEventId: thread,
            threadLastEventId: threadLastEventId,
          ),
    );
  }

  void openCameraAction() async {
    // Make sure the textfield is unfocused before opening the camera
    FocusScope.of(context).requestFocus(FocusNode());
    final file = await ImagePicker().pickImage(source: ImageSource.camera);
    if (file == null) return;

    await showAdaptiveDialog(
      context: context,
      builder:
          (c) => SendFileDialog(
            files: [file],
            room: room,
            outerContext: context,
            threadRootEventId: thread,
            threadLastEventId: threadLastEventId,
          ),
    );
  }

  void openVideoCameraAction() async {
    // Make sure the textfield is unfocused before opening the camera
    FocusScope.of(context).requestFocus(FocusNode());
    final file = await ImagePicker().pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(minutes: 1),
    );
    if (file == null) return;

    await showAdaptiveDialog(
      context: context,
      builder:
          (c) => SendFileDialog(
            files: [file],
            room: room,
            outerContext: context,
            threadRootEventId: thread,
            threadLastEventId: threadLastEventId,
          ),
    );
  }

  void voiceMessageAction() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    if (PlatformInfos.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      if (info.version.sdkInt < 19) {
        showOkAlertDialog(
          context: context,
          title: L10n.of(context).unsupportedAndroidVersion,
          message: L10n.of(context).unsupportedAndroidVersionLong,
          okLabel: L10n.of(context).close,
        );
        return;
      }
    }

    if (await AudioRecorder().hasPermission() == false) return;
    final result = await showDialog<RecordingResult>(
      context: context,
      barrierDismissible: false,
      builder: (c) => const RecordingDialog(),
    );
    if (result == null) return;
    final audioFile = XFile(result.path);
    final file = MatrixAudioFile(
      bytes: await audioFile.readAsBytes(),
      name: result.fileName ?? audioFile.path,
    );
    await room
        .sendFileEvent(
          file,
          inReplyTo: replyEvent,
          extraContent: {
            'info': {...file.info, 'duration': result.duration},
            'org.matrix.msc3245.voice': {},
            'org.matrix.msc1767.audio': {
              'duration': result.duration,
              'waveform': result.waveform,
            },
          },
          threadRootEventId: thread,
          threadLastEventId: threadLastEventId,
        )
        .catchError((e) {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text((e as Object).toLocalizedString(context))),
          );
          return null;
        });
    setState(() {
      replyEvent = null;
    });
  }

  void hideEmojiPicker() {
    setState(() => showEmojiPicker = false);
  }

  void emojiPickerAction() {
    if (showEmojiPicker) {
      inputFocus.requestFocus();
    } else {
      inputFocus.unfocus();
    }
    emojiPickerType = EmojiPickerType.keyboard;
    setState(() {
      showEmojiPicker = !showEmojiPicker;
      isMDEditor = false;
    });
  }

  void _inputFocusListener() {
    if (showEmojiPicker && inputFocus.hasFocus) {
      emojiPickerType = EmojiPickerType.keyboard;
      setState(() => showEmojiPicker = false);
    }
  }

  void sendLocationAction() async {
    /*
    await showAdaptiveDialog(
      context: context,
      builder: (c) => SendLocationDialog(room: room),
    );
    */
  }

  String _getSelectedEventString() {
    var copyString = '';
    if (selectedEvents.length == 1) {
      return selectedEvents.first
          .getDisplayEvent(timeline!)
          .calcLocalizedBodyFallback(MatrixLocals(L10n.of(context)));
    }
    for (final event in selectedEvents) {
      if (copyString.isNotEmpty) copyString += '\n\n';
      copyString += event
          .getDisplayEvent(timeline!)
          .calcLocalizedBodyFallback(
            MatrixLocals(L10n.of(context)),
            withSenderNamePrefix: true,
          );
    }
    return copyString;
  }

  void copyEventsAction() {
    Clipboard.setData(ClipboardData(text: _getSelectedEventString()));
    setState(() {
      showEmojiPicker = false;
      selectedEvents.clear();
    });
  }

  void onCopy(Event event) {
    Clipboard.setData(
      ClipboardData(
        text: event
            .getDisplayEvent(timeline!)
            .calcLocalizedBodyFallback(MatrixLocals(L10n.of(context))),
      ),
    );
  }

  void reportEventAction() async {
    final event = selectedEvents.single;
    final score = await showConfirmationDialog<int>(
      context: context,
      title: L10n.of(context).reportMessage,
      message: L10n.of(context).howOffensiveIsThisContent,
      cancelLabel: L10n.of(context).cancel,
      okLabel: L10n.of(context).ok,
      actions: [
        AlertDialogAction(key: -100, label: L10n.of(context).extremeOffensive),
        AlertDialogAction(key: -50, label: L10n.of(context).offensive),
        AlertDialogAction(key: 0, label: L10n.of(context).inoffensive),
      ],
    );
    if (score == null) return;
    final reason = await showTextInputDialog(
      context: context,
      title: L10n.of(context).whyDoYouWantToReportThis,
      okLabel: L10n.of(context).ok,
      cancelLabel: L10n.of(context).cancel,
      textFields: [DialogTextField(hintText: L10n.of(context).reason)],
    );
    if (reason == null || reason.single.isEmpty) return;
    final result = await showFutureLoadingDialog(
      context: context,
      future:
          () => Matrix.of(context).client.reportEvent(
            event.roomId!,
            event.eventId,
            reason: reason.single,
            score: score,
          ),
    );
    if (result.error != null) return;
    setState(() {
      showEmojiPicker = false;
      selectedEvents.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(L10n.of(context).contentHasBeenReported)),
    );
  }

  void deleteErrorEventsAction() async {
    try {
      if (selectedEvents.any((event) => event.status != EventStatus.error)) {
        throw Exception(
          'Tried to delete failed to send events but one event is not failed to sent',
        );
      }
      for (final event in selectedEvents) {
        await event.cancelSend();
      }
      setState(selectedEvents.clear);
    } catch (e, s) {
      ErrorReporter(
        context,
        'Error while delete error events action',
      ).onErrorCallback(e, s);
    }
  }

  void redactEventsAction() async {
    final reasonInput =
        selectedEvents.any((event) => event.status.isSent)
            ? await showTextInputDialog(
              context: context,
              title: L10n.of(context).redactMessage,
              message: L10n.of(context).redactMessageDescription,
              isDestructiveAction: true,
              textFields: [
                DialogTextField(
                  hintText: L10n.of(context).optionalRedactReason,
                ),
              ],
              okLabel: L10n.of(context).remove,
              cancelLabel: L10n.of(context).cancel,
            )
            : <String>[];
    if (reasonInput == null) return;
    final reason = reasonInput.single.isEmpty ? null : reasonInput.single;
    for (final event in selectedEvents) {
      await showFutureLoadingDialog(
        context: context,
        future: () async {
          if (event.status.isSent) {
            if (event.canRedact) {
              await event.redactEvent(reason: reason);
            } else {
              final client = currentRoomBundle.firstWhere(
                (cl) => selectedEvents.first.senderId == cl!.userID,
                orElse: () => null,
              );
              if (client == null) {
                return;
              }
              final room = client.getRoomById(roomId)!;
              await Event.fromJson(
                event.toJson(),
                room,
              ).redactEvent(reason: reason);
            }
          } else {
            await event.cancelSend();
          }
        },
      );
    }
    setState(() {
      showEmojiPicker = false;
      selectedEvents.clear();
    });
  }

  void onRedact(Event event) async {
    final reasonInput =
        event.status.isSent
            ? await showTextInputDialog(
              context: context,
              title: L10n.of(context).redactMessage,
              message: L10n.of(context).redactMessageDescription,
              isDestructiveAction: true,
              textFields: [
                DialogTextField(
                  hintText: L10n.of(context).optionalRedactReason,
                ),
              ],
              okLabel: L10n.of(context).remove,
              cancelLabel: L10n.of(context).cancel,
            )
            : <String>[];
    if (reasonInput == null) return;
    final reason = reasonInput.single.isEmpty ? null : reasonInput.single;
    await showFutureLoadingDialog(
      context: context,
      future: () async {
        if (event.status.isSent) {
          if (event.canRedact) {
            await event.redactEvent(reason: reason);
          } else {
            final client = currentRoomBundle.firstWhere(
              (cl) => event.senderId == cl!.userID,
              orElse: () => null,
            );
            if (client == null) {
              return;
            }
            final room = client.getRoomById(roomId)!;
            await Event.fromJson(
              event.toJson(),
              room,
            ).redactEvent(reason: reason);
          }
        } else {
          await event.cancelSend();
        }
      },
    );

    selectedEvents.remove(event);
  }

  List<Client?> get currentRoomBundle {
    final clients = Matrix.of(context).currentBundle!;
    clients.removeWhere((c) => c!.getRoomById(roomId) == null);
    return clients;
  }

  bool get canRedactSelectedEvents {
    if (isArchived) return false;
    final clients = Matrix.of(context).currentBundle;
    for (final event in selectedEvents) {
      if (!event.status.isSent) return false;
      if (event.canRedact == false &&
          !(clients!.any((cl) => event.senderId == cl!.userID))) {
        return false;
      }
    }
    return true;
  }

  bool canRedactEvent(Event event) {
    if (isArchived) return false;
    final clients = Matrix.of(context).currentBundle;
    if (!event.status.isSent) return false;
    if (event.canRedact == false &&
        !(clients!.any((cl) => event.senderId == cl!.userID))) {
      return false;
    }
    return true;
  }

  bool get canPinSelectedEvents {
    if (isArchived ||
        !room.canChangeStateEvent(EventTypes.RoomPinnedEvents) ||
        selectedEvents.length != 1 ||
        !selectedEvents.single.status.isSent ||
        selectedEvents[0].type.startsWith('m.call') ||
        isThread()) {
      return false;
    }
    return true;
  }

  bool canPinEvent(Event event) {
    if (isArchived ||
        !event.status.isSent ||
        !room.canChangeStateEvent(EventTypes.RoomPinnedEvents) ||
        isThread() ||
        event.type.startsWith('m.call')) {
      return false;
    }
    return true;
  }

  bool get canEditSelectedEvents {
    if (isArchived ||
        selectedEvents.length != 1 ||
        !selectedEvents.first.status.isSent) {
      return false;
    }
    return currentRoomBundle.any(
      (cl) => selectedEvents.first.senderId == cl!.userID,
    );
  }

  bool canEditEvent(Event event) {
    if (isArchived || !event.status.isSent || event.type.startsWith('m.call')) {
      return false;
    }
    return currentRoomBundle.any((cl) => event.senderId == cl!.userID);
  }

  bool canForward(Event event) {
    if (isArchived || !event.status.isSent || event.type.startsWith('m.call')) {
      return false;
    }
    return true;
  }

  bool canReply(Event event) {
    if (isArchived || !event.status.isSent || event.type.startsWith('m.call')) {
      return false;
    }
    return true;
  }

  bool get canStartThread {
    if (isArchived ||
        selectedEvents.length != 1 ||
        !selectedEvents.first.status.isSent ||
        isThread()) {
      return false;
    }

    return true;
  }

  void forwardEventsAction() async {
    if (selectedEvents.isEmpty) return;
    await showScaffoldDialog(
      context: context,
      builder:
          (context) => ShareScaffoldDialog(
            items:
                selectedEvents
                    .map((event) => ContentShareItem(event.content))
                    .toList(),
          ),
    );
    if (!mounted) return;
    setState(() => selectedEvents.clear());
  }

  void sendAgainAction() {
    final event = selectedEvents.first;
    if (event.status.isError) {
      event.sendAgain();
    }
    final allEditEvents = event
        .aggregatedEvents(timeline!, RelationshipTypes.edit)
        .where((e) => e.status.isError);
    for (final e in allEditEvents) {
      e.sendAgain();
    }
    setState(() => selectedEvents.clear());
  }

  void replyAction({Event? replyTo}) {
    setState(() {
      replyEvent = replyTo ?? selectedEvents.first;
      selectedEvents.clear();
    });
    inputFocus.requestFocus();
  }

  void onForward(Event event) async {
    await showScaffoldDialog(
      context: context,
      builder:
          (context) =>
              ShareScaffoldDialog(items: [ContentShareItem(event.content)]),
    );
    if (!mounted) return;
  }

  void onReply(Event event) {
    setState(() {
      replyEvent = event;
      selectedEvents.clear();
    });
    inputFocus.requestFocus();
  }

  List<Event> getFilteredEvents() {
    if (timeline != null) {
      if (isThread()) {
        return timeline!.events
            .where(
              (event) =>
                  event.relationshipEventId == thread ||
                  event.eventId == thread,
            )
            .toList();
      } else {
        return timeline!.events
            .where(
              (event) => event.relationshipType != RelationshipTypes.thread,
            )
            .toList();
      }
    }

    return []; // Пустой список событий
  }

  void scrollToEventId(String eventId, {bool highlightEvent = true}) async {
    if (eventId == scrollUpBannerEventId &&
        scrollUpBannerEventIsThread == true &&
        scrollUpBannerEventRelationshipEventId != thread) {
      context.go(
        '/${Uri(pathSegments: ['rooms', room.id], queryParameters: {'event': scrollUpBannerEventId, 'thread': scrollUpBannerEventRelationshipEventId})}',
      );
      return;
    }

    final foundEvent = getFilteredEvents().firstWhereOrNull(
      (event) => event.eventId == eventId,
    );

    final eventIndex =
        foundEvent == null
            ? -1
            : getFilteredEvents()
                .filterByVisibleInGui(exceptionEventId: eventId)
                .indexOf(foundEvent);

    if (eventIndex == -1) {
      if (!mounted) return;
      setState(() {
        timeline = null;
        _scrolledUp = false;
        loadTimelineFuture = _getTimeline(eventContextId: eventId).onError(
          ErrorReporter(
            context,
            'Unable to load timeline after scroll to ID',
          ).onErrorCallback,
        );
      });
      await loadTimelineFuture;
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        scrollToEventId(eventId);
      });
      return;
    }
    if (highlightEvent) {
      setState(() {
        scrollToEventIdMarker = eventId;
      });
    }
    await scrollController.scrollToIndex(
      eventIndex + 1,
      duration: CloudThemes.animationDuration,
      preferPosition: AutoScrollPosition.middle,
    );
    _updateScrollController();
  }

  void scrollDown() async {
    if (!timeline!.allowNewEvent) {
      setState(() {
        timeline = null;
        _scrolledUp = false;
        loadTimelineFuture = _getTimeline().onError(
          ErrorReporter(
            context,
            'Unable to load timeline after scroll down',
          ).onErrorCallback,
        );
      });
      await loadTimelineFuture;
    }
    scrollController.jumpTo(0);
  }

  void onEmojiSelected(_, Emoji? emoji) {
    switch (emojiPickerType) {
      case EmojiPickerType.reaction:
        senEmojiReaction(emoji);
        break;
      case EmojiPickerType.keyboard:
        typeEmoji(emoji);
        onInputBarChanged(sendController.text);
        break;
    }
  }

  void senEmojiReaction(Emoji? emoji) {
    setState(() => showEmojiPicker = false);
    if (emoji == null) return;
    // make sure we don't send the same emoji twice
    if (_allReactionEvents.any(
      (e) => e.content.tryGetMap('m.relates_to')?['key'] == emoji.emoji,
    )) {
      return;
    }
    return sendEmojiAction(emoji.emoji);
  }

  void typeEmoji(Emoji? emoji) {
    if (emoji == null) return;
    final text = sendController.text;
    final selection = sendController.selection;
    final newText =
        sendController.text.isEmpty
            ? emoji.emoji
            : selection.start == selection.end
            ? text + emoji.emoji
            : text.replaceRange(selection.start, selection.end, emoji.emoji);
    sendController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        // don't forget an UTF-8 combined emoji might have a length > 1
        offset: selection.baseOffset + emoji.emoji.length,
      ),
    );
  }

  late Iterable<Event> _allReactionEvents;

  void emojiPickerBackspace() {
    switch (emojiPickerType) {
      case EmojiPickerType.reaction:
        setState(() => showEmojiPicker = false);
        break;
      case EmojiPickerType.keyboard:
        sendController
          ..text = sendController.text.characters.skipLast(1).toString()
          ..selection = TextSelection.fromPosition(
            TextPosition(offset: sendController.text.length),
          );
        break;
    }
  }

  void pickEmojiReactionAction(Iterable<Event> allReactionEvents) async {
    _allReactionEvents = allReactionEvents;
    emojiPickerType = EmojiPickerType.reaction;
    setState(() => showEmojiPicker = true);
  }

  void sendEmojiAction(String? emoji) async {
    final events = List<Event>.from(selectedEvents);
    setState(() => selectedEvents.clear());
    for (final event in events) {
      await room.sendReaction(event.eventId, emoji!);
    }
  }

  void clearSelectedEvents() => setState(() {
    selectedEvents.clear();
    showEmojiPicker = false;
  });

  void clearSingleSelectedEvent() {
    if (selectedEvents.length <= 1) {
      clearSelectedEvents();
    }
  }

  void editSelectedEventAction() {
    final client = currentRoomBundle.firstWhere(
      (cl) => selectedEvents.first.senderId == cl!.userID,
      orElse: () => null,
    );
    if (client == null) {
      return;
    }
    setSendingClient(client);
    setState(() {
      pendingText = sendController.text;
      editEvent = selectedEvents.first;
      sendController.text = editEvent!
          .getDisplayEvent(timeline!)
          .calcLocalizedBodyFallback(
            MatrixLocals(L10n.of(context)),
            withSenderNamePrefix: false,
            hideReply: true,
          );
      selectedEvents.clear();
    });
    inputFocus.requestFocus();
  }

  void onEdit(Event event) {
    final client = currentRoomBundle.firstWhere(
      (cl) => event.senderId == cl!.userID,
      orElse: () => null,
    );
    if (client == null) {
      return;
    }
    setSendingClient(client);
    setState(() {
      pendingText = sendController.text;
      editEvent = event;
      sendController.text = editEvent!
          .getDisplayEvent(timeline!)
          .calcLocalizedBodyFallback(
            MatrixLocals(L10n.of(context)),
            withSenderNamePrefix: false,
            hideReply: true,
          );
      selectedEvents.clear();
    });
    inputFocus.requestFocus();
  }

  void goToNewRoomAction() async {
    if (OkCancelResult.ok !=
        await showOkCancelAlertDialog(
          context: context,
          title: L10n.of(context).goToTheNewRoom,
          message:
              room
                  .getState(EventTypes.RoomTombstone)!
                  .parsedTombstoneContent
                  .body,
          okLabel: L10n.of(context).ok,
          cancelLabel: L10n.of(context).cancel,
        )) {
      return;
    }
    final result = await showFutureLoadingDialog(
      context: context,
      future:
          () => room.client.joinRoom(
            room
                .getState(EventTypes.RoomTombstone)!
                .parsedTombstoneContent
                .replacementRoom,
          ),
    );
    await showFutureLoadingDialog(context: context, future: room.leave);
    if (result.error == null) {
      context.go('/rooms/${result.result!}');
    }
  }

  void onSelectMessage(Event event) {
    if (!event.redacted) {
      if (selectedEvents.contains(event)) {
        setState(() => selectedEvents.remove(event));
      } else {
        setState(() => selectedEvents.add(event));
      }
      selectedEvents.sort(
        (a, b) => a.originServerTs.compareTo(b.originServerTs),
      );
    }
    setState(() {
      isMDEditor = false;
    });
  }

  void onHoverMessage(Event event, bool isHovered) {
    if (isHovered) {
      setState(() => hoveredEvent = event);
    } else {
      setState(() => hoveredEvent = null);
    }
  }

  int? findChildIndexCallback(Key key, Map<String, int> thisEventsKeyMap) {
    // this method is called very often. As such, it has to be optimized for speed.
    if (key is! ValueKey) {
      return null;
    }
    final eventId = key.value;
    if (eventId is! String) {
      return null;
    }
    // first fetch the last index the event was at
    final index = thisEventsKeyMap[eventId];
    if (index == null) {
      return null;
    }
    // we need to +1 as 0 is the typing thing at the bottom
    return index + 1;
  }

  void onInputBarSubmitted(_) {
    send();
    FocusScope.of(context).requestFocus(inputFocus);
  }

  void onAddPopupMenuButtonSelected(String choice) {
    if (choice == 'file') {
      sendFileAction();
    }
    if (choice == 'image') {
      sendImageAction();
    }
    if (choice == 'camera') {
      openCameraAction();
    }
    if (choice == 'camera-video') {
      openVideoCameraAction();
    }
    /*if (choice == 'location') {
      sendLocationAction();
    }*/
  }

  unpinEvent(String eventId) async {
    final response = await showOkCancelAlertDialog(
      context: context,
      title: L10n.of(context).unpin,
      message: L10n.of(context).confirmEventUnpin,
      okLabel: L10n.of(context).unpin,
      cancelLabel: L10n.of(context).cancel,
    );
    if (response == OkCancelResult.ok) {
      final events =
          room.pinnedEventIds..removeWhere((oldEvent) => oldEvent == eventId);
      showFutureLoadingDialog(
        context: context,
        future: () => room.setPinnedEvents(events),
      );
    }
  }

  void pinEvent() {
    final pinnedEventIds = room.pinnedEventIds;
    final selectedEventIds = selectedEvents.map((e) => e.eventId).toSet();
    final unpin =
        selectedEventIds.length == 1 &&
        pinnedEventIds.contains(selectedEventIds.single);
    if (unpin) {
      pinnedEventIds.removeWhere(selectedEventIds.contains);
    } else {
      pinnedEventIds.addAll(selectedEventIds);
    }
    showFutureLoadingDialog(
      context: context,
      future: () => room.setPinnedEvents(pinnedEventIds),
    );
  }

  void onPin(Event event) {
    final pinnedEventIds = room.pinnedEventIds;
    final unpin = pinnedEventIds.contains(event.eventId);
    if (unpin) {
      pinnedEventIds.removeWhere([event.eventId].contains);
    } else {
      pinnedEventIds.add(event.eventId);
    }
    showFutureLoadingDialog(
      context: context,
      future: () => room.setPinnedEvents(pinnedEventIds),
    );
  }

  Timer? _storeInputTimeoutTimer;
  static const Duration _storeInputTimeout = Duration(milliseconds: 500);

  void onInputBarChanged(String text) {
    if (_inputTextIsEmpty != text.isEmpty) {
      setState(() {
        _inputTextIsEmpty = text.isEmpty;
      });
    }

    _storeInputTimeoutTimer?.cancel();
    _storeInputTimeoutTimer = Timer(_storeInputTimeout, () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('draft_$roomId', text);
    });
    if (text.endsWith(' ') && Matrix.of(context).hasComplexBundles) {
      final clients = currentRoomBundle;
      for (final client in clients) {
        final prefix = client!.sendPrefix;
        if ((prefix.isNotEmpty) &&
            text.toLowerCase() == '${prefix.toLowerCase()} ') {
          setSendingClient(client);
          setState(() {
            sendController.clear();
          });
          return;
        }
      }
    }
    if (AppConfig.sendTypingNotifications) {
      typingCoolDown?.cancel();
      typingCoolDown = Timer(const Duration(seconds: 2), () {
        typingCoolDown = null;
        currentlyTyping = false;
        room.setTyping(false);
      });
      typingTimeout ??= Timer(const Duration(seconds: 30), () {
        typingTimeout = null;
        currentlyTyping = false;
      });
      if (!currentlyTyping) {
        currentlyTyping = true;
        room.setTyping(
          true,
          timeout: const Duration(seconds: 30).inMilliseconds,
        );
      }
    }
  }

  bool _inputTextIsEmpty = true;

  bool get isArchived =>
      {Membership.leave, Membership.ban}.contains(room.membership);

  void showEventInfo([Event? event]) =>
      (event ?? selectedEvents.single).showInfoDialog(context);

  void onPhoneButtonTap() async {
    // VoIP required Android SDK 21
    if (PlatformInfos.isAndroid) {
      DeviceInfoPlugin().androidInfo.then((value) {
        if (value.version.sdkInt < 21) {
          Navigator.pop(context);
          showOkAlertDialog(
            context: context,
            title: L10n.of(context).unsupportedAndroidVersion,
            message: L10n.of(context).unsupportedAndroidVersionLong,
            okLabel: L10n.of(context).close,
          );
        }
      });
    }
    final callType = await showModalActionSheet(
      context: context,
      title: room.isDirectChat ? L10n.of(context).warning : null,
      message:
          room.isDirectChat ? L10n.of(context).videoCallsBetaWarning : null,
      cancelLabel: L10n.of(context).cancel,
      actions: [
        if (room.isDirectChat)
          SheetAction(
            label: L10n.of(context).voiceCall,
            icon: Icons.phone_outlined,
            key: CallType.kVoice,
          ),
        if (room.isDirectChat)
          SheetAction(
            label: L10n.of(context).videoCall,
            icon: Icons.video_call_outlined,
            key: CallType.kVideo,
          ),
        SheetAction(
          label: L10n.of(context).jitsiCall,
          icon: Icons.video_call_outlined,
          key: "jitsi",
        ),
      ],
    );
    if (callType == null) return;

    if (callType == "jitsi") {
      await showDialog(
        context: context,
        builder: (c) => JitsiDialog(controller: this),
      );
      return;
    }

    final voIPService = Matrix.of(context).voIPService;
    try {
      await voIPService!.startCall(room);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toLocalizedString(context))));
    }
  }

  void cancelReplyEventAction() => setState(() {
    if (editEvent != null) {
      sendController.text = pendingText;
      pendingText = '';
    }
    replyEvent = null;
    editEvent = null;
  });

  late final ValueNotifier<bool> _displayChatDetailsColumn;

  void toggleDisplayChatDetailsColumn() async {
    if (isOpenThread == true) context.go('/rooms/$roomId');

    await Matrix.of(context).store.setBool(
      SettingKeys.displayChatDetailsColumn,
      !_displayChatDetailsColumn.value,
    );
    _displayChatDetailsColumn.value = !_displayChatDetailsColumn.value;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(child: ChatView(this)),
        AnimatedSize(
          duration: CloudThemes.animationDuration,
          curve: CloudThemes.animationCurve,
          child: ValueListenableBuilder(
            valueListenable: _displayChatDetailsColumn,
            builder: (context, displayChatDetailsColumn, _) {
              if (!CloudThemes.isThreeColumnMode(context) ||
                  room.membership != Membership.join ||
                  !displayChatDetailsColumn) {
                return const SizedBox(height: double.infinity, width: 0);
              }
              return Container(
                width: CloudThemes.columnWidth,
                clipBehavior: Clip.antiAliasWithSaveLayer,
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(width: 1, color: theme.dividerColor),
                  ),
                ),
                child: ChatDetails(
                  roomId: roomId,
                  embeddedCloseButton: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: toggleDisplayChatDetailsColumn,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

enum EmojiPickerType { reaction, keyboard }
