import 'package:flutter/material.dart';

import 'package:badges/badges.dart';
import 'package:matrix/matrix.dart';

import 'package:cloudchat/config/app_config.dart';
import 'package:cloudchat/widgets/hover_builder.dart';
import 'package:cloudchat/widgets/unread_rooms_badge.dart';
import '../../config/themes.dart';

class NaviRailItem extends StatelessWidget {
  final String toolTip;
  final bool isSelected;
  final void Function() onTap;
  final Widget icon;
  final Widget? selectedIcon;
  final bool Function(Room)? unreadBadgeFilter;
  final int? badgeCount;

  const NaviRailItem({
    required this.toolTip,
    required this.isSelected,
    required this.onTap,
    required this.icon,
    this.selectedIcon,
    this.unreadBadgeFilter,
    this.badgeCount,
    super.key,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final borderRadius = BorderRadius.circular(AppConfig.borderRadius);
    final icon = isSelected ? selectedIcon ?? this.icon : this.icon;
    final unreadBadgeFilter = this.unreadBadgeFilter;
    return HoverBuilder(
      builder: (context, hovered) {
        return SizedBox(
          height: CloudThemes.navRailWidth,
          width: CloudThemes.navRailWidth,
          child: Stack(
            children: [
              Positioned(
                top: 16,
                bottom: 16,
                left: 0,
                child: AnimatedContainer(
                  width: isSelected ? 4 : 0,
                  duration: CloudThemes.animationDuration,
                  curve: CloudThemes.animationCurve,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(90),
                      bottomRight: Radius.circular(90),
                    ),
                  ),
                ),
              ),
              Center(
                child: AnimatedScale(
                  scale: hovered ? 1.2 : 1.0,
                  duration: CloudThemes.animationDuration,
                  curve: CloudThemes.animationCurve,
                  child: Material(
                    borderRadius: borderRadius,
                    color: isSelected
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surface,
                    child: Tooltip(
                      message: toolTip,
                      child: InkWell(
                        borderRadius: borderRadius,
                        onTap: onTap,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 8.0,
                          ),
                          child: unreadBadgeFilter != null || badgeCount != null
                              ? UnreadRoomsBadge(
                                  filter: unreadBadgeFilter,
                                  badgePosition: BadgePosition.topEnd(
                                    top: -12,
                                    end: -8,
                                  ),
                                  count: badgeCount,
                                  child: icon,
                                )
                              : icon,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
