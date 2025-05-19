import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SelectLinkDialog extends StatefulWidget {
  final List<String> links;

  const SelectLinkDialog({
    required this.links,
    super.key,
  });

  @override
  SelectLinkDialogState createState() => SelectLinkDialogState();
}

class SelectLinkDialogState extends State<SelectLinkDialog> {
  void goToLink(String link) async {
    final uri = Uri.parse(link);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog.adaptive(
      title: const Text("Select link"),
      content: SizedBox(
        width: 600,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.links.length,
          itemBuilder: (context, i) {
            return Container(
              padding: const EdgeInsets.symmetric(
                vertical: 8,
              ),
              width: double.infinity,
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(widget.links[i]),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.chevron_right_outlined,
                    ),
                    onPressed: () {
                      goToLink(widget.links[i]);
                      Navigator.of(context, rootNavigator: false).pop();
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
