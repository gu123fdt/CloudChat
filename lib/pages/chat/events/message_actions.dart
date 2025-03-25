import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';

class MessageActions extends StatelessWidget {
  final bool canStartThread;
  final bool canEditEvent;
  final bool canPinEvent;
  final bool canRedactEvent;
  final bool canForward;
  final bool canReply;
  final bool canCreateLink;
  final void Function() onStartThread;
  final void Function() onEdit;
  final void Function() onCopy;
  final void Function() onPin;
  final void Function() onRedact;
  final void Function() onForward;
  final void Function() onReply;
  final void Function() onCreateLink;

  const MessageActions({
    required this.canStartThread,
    required this.canEditEvent,
    required this.canPinEvent,
    required this.canRedactEvent,
    required this.canForward,
    required this.canReply,
    required this.canCreateLink,
    required this.onStartThread,
    required this.onEdit,
    required this.onCopy,
    required this.onPin,
    required this.onRedact,
    required this.onForward,
    required this.onReply,
    required this.onCreateLink,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        children: [
          if (canForward)
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_left_outlined),
              tooltip: L10n.of(context).forward,
              onPressed: onForward,
              key: Key("${DateTime.now().microsecond}-forwardMessage"),
            ),
          if (canStartThread)
            IconButton(
              icon: const Icon(Icons.fork_right_outlined),
              tooltip: L10n.of(context).startThread,
              onPressed: onStartThread,
              key: Key("${DateTime.now().microsecond}-startThread"),
            ),
          if (canEditEvent)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: L10n.of(context).edit,
              onPressed: onEdit,
              key: Key("${DateTime.now().microsecond}-edit"),
            ),
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            tooltip: L10n.of(context).copy,
            onPressed: onCopy,
            key: Key("${DateTime.now().microsecond}-copy"),
          ),
          if (canPinEvent)
            IconButton(
              icon: const Icon(Icons.push_pin_outlined),
              onPressed: onPin,
              tooltip: L10n.of(context).pinMessage,
              key: Key("${DateTime.now().microsecond}-pinMessage"),
            ),
          if (canCreateLink)
            IconButton(
              icon: const Icon(Icons.link_outlined),
              tooltip: L10n.of(context).createLink,
              onPressed: onCreateLink,
              key: Key("${DateTime.now().microsecond}-createLink"),
            ),
          if (canRedactEvent)
            IconButton(
              icon: const Icon(Icons.delete_outlined),
              tooltip: L10n.of(context).redactMessage,
              onPressed: onRedact,
              key: Key("${DateTime.now().microsecond}-redactMessage"),
            ),
          if (canReply)
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_right_outlined),
              tooltip: L10n.of(context).reply,
              onPressed: onReply,
              key: Key("${DateTime.now().microsecond}-replyMessage"),
            ),
        ],
      ),
    );
  }
}
