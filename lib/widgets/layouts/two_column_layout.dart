import 'package:cloudchat/widgets/resizable_widget.dart';
import 'package:flutter/material.dart';

import 'package:cloudchat/config/themes.dart';

class TwoColumnLayout extends StatelessWidget {
  final Widget mainView;
  final Widget sideView;
  final bool displayNavigationRail;

  const TwoColumnLayout({
    super.key,
    required this.mainView,
    required this.sideView,
    required this.displayNavigationRail,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        return ScaffoldMessenger(
          child: Scaffold(
            body: Row(
              children: [
                ResizableWidget(
                  minWidthPercent:
                      (CloudThemes.columnWidth / constraints.maxWidth) * 100,
                  maxWidthPercent: 60,
                  initialWidthPercent: ((CloudThemes.columnWidth +
                              (displayNavigationRail
                                  ? CloudThemes.navRailWidth
                                  : 0)) /
                          constraints.maxWidth) *
                      100,
                  screenWidth: constraints.maxWidth,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: const BoxDecoration(),
                    width: CloudThemes.columnWidth +
                        (displayNavigationRail ? CloudThemes.navRailWidth : 0),
                    child: mainView,
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    child: sideView,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
