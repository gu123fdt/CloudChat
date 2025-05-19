import 'dart:math';

import 'package:cloudchat/pages/chat/chat.dart';
import 'package:cloudchat/pages/chat_details/participant_list_item.dart';
import 'package:cloudchat/widgets/matrix.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';

class JitsiDialog extends StatefulWidget {
  final ChatController controller;

  const JitsiDialog({required this.controller, super.key});

  @override
  JitsiDialogState createState() => JitsiDialogState();
}

class JitsiDialogState extends State<JitsiDialog> {
  final TextEditingController roomNameController = TextEditingController();
  final TextEditingController searchController = TextEditingController();
  List<User> users = [];
  List<User> filteredUsers = [];

  List<String> selectedUserIds = [];

  bool isLoading = false;

  bool? get isAllChecked {
    if (users.length == selectedUserIds.length) {
      return true;
    } else if (selectedUserIds.isEmpty) {
      return false;
    } else {
      return null;
    }
  }

  void onSelect(User user) {
    setState(() {
      if (selectedUserIds.contains(user.id)) {
        selectedUserIds.remove(user.id);
      } else {
        selectedUserIds.add(user.id);
      }
    });
  }

  void getUsers() async {
    setState(() {
      isLoading = true;
    });

    final participants =
        await Matrix.of(
          context,
        ).client.getRoomById(widget.controller.roomId)?.requestParticipants();

    if (participants != null) {
      setState(() {
        users = participants;

        setFilter();
      });
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();

    roomNameController.text =
        "${widget.controller.room.getLocalizedDisplayname().replaceAll(" ", "")}-${Random().nextInt(100001)}";

    getUsers();
  }

  void setFilter([_]) async {
    final filter = searchController.text.toLowerCase().trim();

    if (filter.isEmpty) {
      setState(() {
        filteredUsers =
            users..sort((b, a) => a.powerLevel.compareTo(b.powerLevel));
      });
      return;
    }
    setState(() {
      filteredUsers =
          users
              .where(
                (user) =>
                    user.displayName?.toLowerCase().contains(filter) ??
                    user.id.toLowerCase().contains(filter),
              )
              .toList()
            ..sort((b, a) => a.powerLevel.compareTo(b.powerLevel));
    });
  }

  void onSelectAll(_) {
    setState(() {
      if (users.length == selectedUserIds.length) {
        selectedUserIds = [];
      } else if (selectedUserIds.isEmpty) {
        selectedUserIds = users.map((u) => u.id).toList();
      } else {
        selectedUserIds = users.map((u) => u.id).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(L10n.of(context).jitsiCall),
      content: SizedBox(
        width: 600,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: TextField(
                controller: roomNameController,
                autocorrect: false,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: L10n.of(context).roomName,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Divider(),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: TextField(
                controller: searchController,
                autocorrect: false,
                autofocus: true,
                onChanged: setFilter,
                decoration: InputDecoration(
                  hintText: L10n.of(context).searchUsers,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                children: [
                  Checkbox(
                    tristate: true,
                    value: isAllChecked,
                    onChanged: onSelectAll,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 12.0),
                    child: Text(
                      L10n.of(
                        context,
                      ).selectedOf(selectedUserIds.length, users.length),
                    ),
                  ),
                ],
              ),
            ),
            if (!isLoading)
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filteredUsers.length,
                  itemBuilder:
                      (BuildContext context, int i) => ParticipantListItem(
                        filteredUsers[i],
                        isSelectable: true,
                        onSelect: onSelect,
                        isSelected: selectedUserIds.contains(
                          filteredUsers[i].id,
                        ),
                      ),
                ),
              ),
            if (isLoading) const CircularProgressIndicator.adaptive(),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(L10n.of(context).cancel),
        ),
        TextButton(
          onPressed: () {
            widget.controller.sendJitsiRoom(
              roomNameController.text,
              selectedUserIds,
            );
            Navigator.of(context).pop();
          },
          child: Text(L10n.of(context).send),
        ),
      ],
    );
  }
}
