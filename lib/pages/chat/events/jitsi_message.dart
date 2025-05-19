import 'package:cloudchat/config/app_config.dart';
import 'package:cloudchat/pages/chat/events/html_message.dart';
import 'package:cloudchat/pages/chat/select_link_dialog.dart';
import 'package:cloudchat/utils/date_time_extension.dart';
import 'package:cloudchat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:cloudchat/utils/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:matrix/matrix.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:url_launcher/url_launcher.dart';

class JitsiMessage extends StatelessWidget {
  final Event event;
  final Color textColor;

  const JitsiMessage(this.event, {required this.textColor, super.key});

  void openJitsi(BuildContext context) async {
    final regex = RegExp(r'https?://meet\.[^/\s]+/[^\s]+');
    final links = regex
        .allMatches(event.text)
        .map((match) => match.group(0)!)
        .where(
          (l) => l.contains(
            event.room.client.baseUri!.origin
                .replaceFirst(RegExp(r'(?<=//).*?(?=\.)'), 'meet'),
          ),
        )
        .toList();

    if (links.isEmpty) return;
    if (links.length == 1) {
      final uri = Uri.parse(links[0]);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else {
      await showAdaptiveDialog(
        context: context,
        builder: (c) => SelectLinkDialog(
          links: links,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = AppConfig.messageFontSize * AppConfig.fontSizeFactor;
    var html = event.formattedText;
    if (event.messageType == MessageTypes.Emote) {
      html = '* $html';
    }
    final bigEmotes =
        event.onlyEmotes && event.numberEmotes > 0 && event.numberEmotes <= 3;

    return Column(
      children: [
        Row(
          children: [
            Icon(
              Icons.meeting_room_outlined,
              color: textColor,
            ),
            const SizedBox(width: 16),
            Text(
              "Jitsi meet",
              style: TextStyle(
                color: textColor,
                fontSize: fontSize + 4,
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => openJitsi(context),
                  child: Text(
                    L10n.of(context).joinToMeeting,
                    style: TextStyle(
                      color: textColor,
                      fontSize: fontSize,
                      decorationColor: textColor,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Divider(
            height: 1,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (AppConfig.renderHtml && !event.redacted && event.isRichMessage)
              Align(
                alignment: Alignment.centerLeft,
                child: HtmlMessage(
                  html: html,
                  textColor: textColor,
                  room: event.room,
                ),
              ),
            if (!(AppConfig.renderHtml &&
                !event.redacted &&
                event.isRichMessage))
              Align(
                alignment: Alignment.centerLeft,
                child: Linkify(
                  text: event.calcLocalizedBodyFallback(
                    MatrixLocals(L10n.of(context)),
                    hideReply: true,
                  ),
                  style: TextStyle(
                    color: textColor,
                    fontSize: bigEmotes ? fontSize * 5 : fontSize,
                    decoration:
                        event.redacted ? TextDecoration.lineThrough : null,
                  ),
                  options: const LinkifyOptions(humanize: false),
                  linkStyle: TextStyle(
                    color: textColor.withAlpha(150),
                    fontSize: fontSize,
                    decoration: TextDecoration.underline,
                    decorationColor: textColor.withAlpha(150),
                  ),
                  onOpen: (url) => UrlLauncher(context, url.url).launchUrl(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                event.originServerTs.localizedTimeOfDay(context),
                style: TextStyle(
                  color: textColor.withAlpha(164),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
