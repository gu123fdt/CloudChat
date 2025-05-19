import 'package:cloudchat/widgets/call_banner_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CallBannerWrapper extends StatelessWidget {
  final Widget? child;

  const CallBannerWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final banner = context.watch<CallBannerController>().banner;

    return Column(
      children: [
        if (banner != null) banner,
        Expanded(child: child ?? const SizedBox.shrink()),
      ],
    );
  }
}
