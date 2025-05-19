import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:matrix/matrix.dart';

import 'package:cloudchat/pages/image_viewer/image_viewer_view.dart';
import 'package:cloudchat/utils/platform_infos.dart';
import 'package:cloudchat/utils/show_scaffold_dialog.dart';
import 'package:cloudchat/widgets/share_scaffold_dialog.dart';
import '../../utils/matrix_sdk_extensions/event_extension.dart';

class ImageViewer extends StatefulWidget {
  final Event event;
  final BuildContext outerContext;

  const ImageViewer(this.event, {required this.outerContext, super.key});

  @override
  ImageViewerController createState() => ImageViewerController();
}

class ImageViewerController extends State<ImageViewer> {
  /// Forward this image to another room.
  void forwardAction() => showScaffoldDialog(
        context: context,
        builder: (context) => ShareScaffoldDialog(
          items: [ContentShareItem(widget.event.content)],
        ),
      );

  void goToMessage() {
    Navigator.of(context).pop();

    context.go(
      '/${Uri(
        pathSegments: ['rooms', widget.event.roomId!],
        queryParameters: {
          'event': widget.event.eventId,
        },
      )}',
      extra: {
        'from':
            GoRouter.of(context).routeInformationProvider.value.uri.toString(),
      },
    );
  }

  /// Save this file with a system call.
  void saveFileAction(BuildContext context) => widget.event.saveFile(context);

  /// Save this file with a system call.
  void shareFileAction(BuildContext context) => widget.event.shareFile(context);

  static const maxScaleFactor = 1.5;

  /// Go back if user swiped it away
  void onInteractionEnds(ScaleEndDetails endDetails) {
    if (PlatformInfos.usesTouchscreen == false) {
      if (endDetails.velocity.pixelsPerSecond.dy >
          MediaQuery.of(context).size.height * maxScaleFactor) {
        Navigator.of(context, rootNavigator: false).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) => ImageViewerView(this);
}
