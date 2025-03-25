import 'package:flutter/material.dart';

import 'package:flutter_gen/gen_l10n/l10n.dart';

Widget markdownContextBuilder(
  BuildContext context,
  EditableTextState editableTextState,
  TextEditingController controller,
  Function onAddLink,
  Function onSetBold,
  Function onSetItalic,
  Function onSetStrikeThrough,
) {
  final value = editableTextState.textEditingValue;
  final selectedText = value.selection.textInside(value.text);
  final buttonItems = editableTextState.contextMenuButtonItems;
  final l10n = L10n.of(context);

  return AdaptiveTextSelectionToolbar.buttonItems(
    anchors: editableTextState.contextMenuAnchors,
    buttonItems: [
      ...buttonItems,
      if (selectedText.isNotEmpty) ...[
        ContextMenuButtonItem(
          label: l10n.link,
          onPressed: () => onAddLink(),
        ),
        ContextMenuButtonItem(
          label: l10n.boldText,
          onPressed: () => onSetBold(),
        ),
        ContextMenuButtonItem(
          label: l10n.italicText,
          onPressed: () => onSetItalic(),
        ),
        ContextMenuButtonItem(
          label: l10n.strikeThrough,
          onPressed: () => onSetStrikeThrough(),
        ),
      ],
    ],
  );
}
