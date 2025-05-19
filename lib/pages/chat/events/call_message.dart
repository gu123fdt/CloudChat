import 'package:cloudchat/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';

class CallMessage extends StatelessWidget {
  final Event event;
  final Color textColor;

  const CallMessage(this.event, {required this.textColor, super.key});
  @override
  Widget build(BuildContext context) {
    final fontSize = AppConfig.messageFontSize * AppConfig.fontSizeFactor;

    if (event.type == EventTypes.CallInvite) {
      return FutureBuilder<User?>(
        future: event.fetchSenderUser(),
        builder: (context, snapshot) {
          return Text(
            '📞  ${L10n.of(context).startedACall(
              snapshot.data?.calcDisplayname() ??
                  event.senderFromMemoryOrFallback.calcDisplayname(),
            )}',
            style: TextStyle(
              color: textColor,
              fontSize: fontSize,
            ),
          );
        },
      );
    } else {
      return FutureBuilder<User?>(
        future: event.fetchSenderUser(),
        builder: (context, snapshot) {
          return Text(
            '📞  ${L10n.of(context).endedTheCall(
              snapshot.data?.calcDisplayname() ??
                  event.senderFromMemoryOrFallback.calcDisplayname(),
            )}',
            style: TextStyle(
              color: textColor,
              fontSize: fontSize,
            ),
          );
        },
      );
    }
  }
}
