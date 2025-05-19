import 'package:flutter/material.dart';

import 'package:cloudchat/config/app_config.dart';
import 'package:cloudchat/config/themes.dart';

Future<T?> showAdaptiveBottomSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool isDismissible = true,
  bool isScrollControlled = true,
  double maxHeight = 512,
  bool useRootNavigator = true,
}) =>
    showModalBottomSheet(
      context: context,
      builder: builder,
      // this sadly is ugly on desktops but otherwise breaks `.of(context)` calls
      useRootNavigator: useRootNavigator,
      isDismissible: isDismissible,
      isScrollControlled: isScrollControlled,
      constraints: BoxConstraints(
        maxHeight: maxHeight,
        maxWidth: CloudThemes.columnWidth * 1.25,
      ),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppConfig.borderRadius),
          topRight: Radius.circular(AppConfig.borderRadius),
        ),
      ),
    );
