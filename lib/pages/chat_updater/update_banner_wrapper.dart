import 'package:cloudchat/pages/chat_updater/update_banner.dart';
import 'package:cloudchat/pages/chat_updater/update_banner_controller.dart';
import 'package:flutter/material.dart';
import 'package:cloudchat/utils/chat_updater/chat_updater.dart';
import 'package:provider/provider.dart';

class UpdateBannerWrapper extends StatelessWidget {
  final Widget child;

  const UpdateBannerWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    ChatUpdater.init(() {
      context.read<UpdateBannerController>().showBanner(
            const UpdateBanner(),
          );
    }, () {
      context.read<UpdateBannerController>().hideBanner();
    });

    final banner = context.watch<UpdateBannerController>().banner;

    return Column(
      children: [
        if (banner != null) banner,
        Expanded(child: child),
      ],
    );
  }
}
