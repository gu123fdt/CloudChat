import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:cloudchat/config/themes.dart';
import 'package:cloudchat/pages/chat/chat.dart';
import 'package:cloudchat/utils/room_status_extension.dart';
import 'package:cloudchat/widgets/avatar.dart';
import 'package:cloudchat/widgets/cloud_chat_app.dart';
import 'package:cloudchat/widgets/matrix.dart';
import 'package:matrix/matrix.dart';

import '../../utils/adaptive_bottom_sheet.dart';
import '../user_bottom_sheet/user_bottom_sheet.dart';

class SeenByRow extends StatelessWidget {
  final ChatController controller;
  final String eventId;
  const SeenByRow(this.controller, this.eventId, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final seenByUsers = controller.room
        .getSeenByUsers(controller.timeline!, eventId: eventId)
        .where((u) =>
            controller.room.receiptState.global.otherUsers[u.id]?.eventId ==
            eventId)
        .toList();
    const maxAvatars = 7;
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.only(top: 4),
      child: AnimatedContainer(
        constraints:
            const BoxConstraints(maxWidth: CloudThemes.columnWidth * 2.5),
        height: seenByUsers.isEmpty ? 0 : 24,
        duration:
            seenByUsers.isEmpty ? Duration.zero : CloudThemes.animationDuration,
        curve: CloudThemes.animationCurve,
        alignment: controller.getFilteredEvents().isNotEmpty &&
                controller.getFilteredEvents().first.senderId ==
                    Matrix.of(context).client.userID
            ? Alignment.topRight
            : Alignment.topLeft,
        padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
        child: InkWell(
          onTap: () async => await _AdaptableSeenDialog(
            client: Matrix.of(context).client,
            users: seenByUsers,
          ).show(context),
          borderRadius: BorderRadius.circular(8),
          child: Wrap(
            spacing: 4,
            children: [
              ...(seenByUsers.length > maxAvatars
                      ? seenByUsers.sublist(0, maxAvatars)
                      : seenByUsers)
                  .map(
                (user) => Avatar(
                  mxContent: user.avatarUrl,
                  name: user.calcDisplayname(),
                  size: 16,
                ),
              ),
              if (seenByUsers.length > maxAvatars)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: Material(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(32),
                    child: Center(
                      child: Text(
                        '+${seenByUsers.length - maxAvatars}',
                        style: const TextStyle(fontSize: 9),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdaptableSeenDialog extends StatelessWidget {
  final Client? client;
  final List<User>? users;

  const _AdaptableSeenDialog({
    this.client,
    this.users,
  });

  Future<bool?> show(BuildContext context) => showAdaptiveDialog(
        context: navigatorKey.currentContext!,
        builder: (context) => this,
        barrierDismissible: true,
        useRootNavigator: false,
      );

  @override
  Widget build(BuildContext context) {
    final body = SingleChildScrollView(
      child: Wrap(
        spacing: 8.0,
        runSpacing: 4.0,
        alignment: WrapAlignment.center,
        children: <Widget>[
          for (final user in users!)
            ActionChip(
              avatar: Avatar(
                mxContent: user.avatarUrl,
                name: user.displayName,
                client: client,
                presenceUserId: user.stateKey,
              ),
              label: Text(user.displayName!),
              onPressed: () {
                showAdaptiveBottomSheet(
                  context: context,
                  builder: (c) => UserBottomSheet(
                    user: user,
                    outerContext: context,
                  ),
                );
              },
            ),
        ],
      ),
    );

    final title = Center(child: Text(L10n.of(context).users));

    return AlertDialog.adaptive(
      title: title,
      content: body,
    );
  }
}
