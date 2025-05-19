import 'package:flutter/material.dart';

import 'package:flutter_gen/gen_l10n/l10n.dart';

import 'package:cloudchat/config/themes.dart';
import 'package:cloudchat/pages/chat_search/chat_search_files_tab.dart';
import 'package:cloudchat/pages/chat_search/chat_search_images_tab.dart';
import 'package:cloudchat/pages/chat_search/chat_search_message_tab.dart';
import 'package:cloudchat/pages/chat_search/chat_search_page.dart';
import 'package:cloudchat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:cloudchat/widgets/layouts/max_width_body.dart';

class ChatSearchView extends StatelessWidget {
  final ChatSearchController controller;

  const ChatSearchView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final room = controller.room;
    if (room == null && controller.widget.isGlobal! == false) {
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

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: const Center(child: BackButton()),
        titleSpacing: 0,
        title: Text(
          room != null
              ? L10n.of(context).searchIn(
                  room.getLocalizedDisplayname(MatrixLocals(L10n.of(context))),
                )
              : L10n.of(context).globalSearchMessages,
        ),
      ),
      body: MaxWidthBody(
        withScrolling: false,
        maxWidth: 1800,
        innerPadding: const EdgeInsets.only(left: 64, right: 64),
        child: Column(
          children: [
            if (CloudThemes.isThreeColumnMode(context))
              const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller.searchController,
                      onSubmitted: (_) => controller.restartSearch(),
                      autofocus: true,
                      enabled: controller.tabController.index == 0,
                      decoration: InputDecoration(
                        hintText: L10n.of(context).search,
                        filled: true,
                        fillColor: theme.colorScheme.secondaryContainer,
                        border: OutlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        hintStyle: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                  AnimatedContainer(
                    duration: CloudThemes.animationDuration,
                    curve: CloudThemes.animationCurve,
                    height: 64,
                    width: controller.searchController.text !=
                            controller.oldSearchString
                        ? 64
                        : 0,
                    alignment: Alignment.center,
                    clipBehavior: Clip.antiAliasWithSaveLayer,
                    decoration: const BoxDecoration(),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: IconButton.filled(
                        onPressed: () => controller.restartSearch(),
                        icon: const Icon(Icons.search_outlined),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: controller.tabController,
              tabs: [
                Tab(child: Text(L10n.of(context).messages)),
                if (room != null) Tab(child: Text(L10n.of(context).gallery)),
                if (room != null) Tab(child: Text(L10n.of(context).files)),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: controller.tabController,
                children: [
                  ChatSearchMessageTab(
                    searchQuery: controller.searchController.text,
                    startSearch: controller.startMessageSearch,
                    events: controller.messageEvents,
                    room: room,
                    isLoading: room == null
                        ? controller.searchStreamsSubscriptions.isNotEmpty
                        : controller.searchStreamSubscription != null,
                  ),
                  if (room != null)
                    ChatSearchImagesTab(
                      room: room,
                      startSearch: controller.startGallerySearch,
                      searchStream: controller.galleryStream,
                    ),
                  if (room != null)
                    ChatSearchFilesTab(
                      room: room,
                      startSearch: controller.startFileSearch,
                      searchStream: controller.fileStream,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
