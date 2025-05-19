import 'package:flutter/material.dart';
import 'package:cloudchat/config/themes.dart';
import 'package:cloudchat/pages/chat/chat.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';

class EditTextStyle extends StatelessWidget {
  final ChatController controller;
  const EditTextStyle(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (controller.showEmojiPicker ||
        controller.selectedEvents.isNotEmpty ||
        !controller.isSelectedText ||
        controller.isMDEditor) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: CloudThemes.animationDuration,
      curve: CloudThemes.animationCurve,
      child: Padding(
        padding: const EdgeInsets.only(left: 8, top: 8),
        child: Material(
          color: Colors.transparent,
          child: Builder(
            builder: (context) {
              return Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_link),
                    tooltip: L10n.of(context).link,
                    onPressed: controller.addLinkToSelectedText,
                  ),
                  IconButton(
                    icon: const Icon(Icons.format_bold),
                    tooltip: L10n.of(context).boldText,
                    onPressed: controller.setSelectedTextBold,
                  ),
                  IconButton(
                    icon: const Icon(Icons.format_italic),
                    tooltip: L10n.of(context).italicText,
                    onPressed: controller.setSelectedTextItalic,
                  ),
                  IconButton(
                    icon: const Icon(Icons.format_strikethrough),
                    tooltip: L10n.of(context).strikeThrough,
                    onPressed: controller.setSelectedTextStrikethrough,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
