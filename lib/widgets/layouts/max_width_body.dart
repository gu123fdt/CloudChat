import 'package:flutter/material.dart';

import 'package:cloudchat/config/app_config.dart';
import 'package:cloudchat/config/themes.dart';

class MaxWidthBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final bool withScrolling;
  final EdgeInsets innerPadding;

  const MaxWidthBody({
    required this.child,
    this.maxWidth = 0,
    this.withScrolling = true,
    this.innerPadding = const EdgeInsets.all(0),
    super.key,
  });
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final theme = Theme.of(context);

          final desiredWidth =
              maxWidth != 0 ? maxWidth : CloudThemes.columnWidth * 1.5;
          final body = Padding(
            padding: innerPadding,
            child: constraints.maxWidth <= desiredWidth
                ? child
                : Container(
                    alignment: Alignment.topCenter,
                    padding: const EdgeInsets.all(32),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: maxWidth != 0
                            ? desiredWidth
                            : CloudThemes.columnWidth * 1.5,
                      ),
                      child: Material(
                        elevation:
                            theme.appBarTheme.scrolledUnderElevation ?? 4,
                        clipBehavior: Clip.antiAliasWithSaveLayer,
                        borderRadius:
                            BorderRadius.circular(AppConfig.borderRadius),
                        shadowColor: theme.appBarTheme.shadowColor,
                        child: child,
                      ),
                    ),
                  ),
          );
          if (!withScrolling) return body;

          return SingleChildScrollView(
            padding: innerPadding,
            physics: const ScrollPhysics(),
            child: body,
          );
        },
      ),
    );
  }
}
