import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:cloudchat/utils/chat_updater/chat_updater.dart';

enum CallBannerType { incoming, outgoing, connected }

class UpdateBanner extends StatefulWidget {
  const UpdateBanner({
    super.key,
  });

  @override
  UpdateBannerState createState() => UpdateBannerState();
}

class UpdateBannerState extends State<UpdateBanner>
    with SingleTickerProviderStateMixin {
  bool updateInProgress = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          setState(() {
            updateInProgress = true;
            ChatUpdater.startUpdate();
          });
        },
        child: Column(
          children: [
            SizedBox(
              height: 48,
              width: double.infinity,
              child: Container(
                color: const Color(0xFF8EAD32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 380,
                    minWidth: 0,
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              L10n.of(context).newChatVersionAvailable,
                              style: theme.textTheme.bodyLarge
                                  ?.copyWith(color: Colors.white),
                            ),
                            if (updateInProgress) const SizedBox(width: 16),
                            if (updateInProgress)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.download,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                setState(() {
                                  updateInProgress = true;
                                  ChatUpdater.startUpdate();
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Divider(
              height: 1,
              color: theme.dividerColor,
            ),
          ],
        ),
      ),
    );
  }
}
