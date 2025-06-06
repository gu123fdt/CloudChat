import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:matrix/matrix.dart';
import 'package:mime/mime.dart';

import 'package:cloudchat/config/app_config.dart';
import 'package:cloudchat/utils/localized_exception_extension.dart';
import 'package:cloudchat/utils/matrix_sdk_extensions/matrix_file_extension.dart';
import 'package:cloudchat/utils/platform_infos.dart';
import 'package:cloudchat/utils/size_string.dart';
import 'package:cloudchat/widgets/adaptive_dialog_action.dart';
import 'package:path_provider/path_provider.dart';
import '../../utils/resize_video.dart';

class SendFileDialog extends StatefulWidget {
  final Room room;
  final List<XFile> files;
  final BuildContext outerContext;
  final String? threadRootEventId;
  final String? threadLastEventId;

  const SendFileDialog({
    required this.room,
    required this.files,
    required this.outerContext,
    this.threadRootEventId,
    this.threadLastEventId,
    super.key,
  });

  @override
  SendFileDialogState createState() => SendFileDialogState();
}

class SendFileDialogState extends State<SendFileDialog> {
  bool compress = true;

  /// Images smaller than 20kb don't need compression.
  static const int minSizeToCompress = 20 * 1024;
  late final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final scaffoldMessenger = ScaffoldMessenger.of(widget.outerContext);
    final l10n = L10n.of(context);

    try {
      scaffoldMessenger.showLoadingSnackBar(l10n.prepareSendingAttachment);
      Navigator.of(context, rootNavigator: false).pop();
      final clientConfig = await widget.room.client.getConfig();
      final maxUploadSize = clientConfig.mUploadSize ?? 100 * 1024 * 1024;

      for (final xfile in widget.files) {
        final MatrixFile file;
        MatrixImageFile? thumbnail;
        final length = await xfile.length();
        final mimeType = xfile.mimeType ?? lookupMimeType(xfile.path);

        // If file is a video, shrink it!
        if (PlatformInfos.isMobile &&
            mimeType != null &&
            mimeType.startsWith('video') &&
            length > minSizeToCompress &&
            compress) {
          scaffoldMessenger.showLoadingSnackBar(l10n.compressVideo);
          file = await xfile.resizeVideo();
          scaffoldMessenger.showLoadingSnackBar(l10n.generatingVideoThumbnail);
          thumbnail = await xfile.getVideoThumbnail();
        } else {
          if (length > maxUploadSize) {
            throw FileTooBigMatrixException(length, maxUploadSize);
          }

          // Else we just create a MatrixFile
          file = MatrixFile(
            bytes: await xfile.readAsBytes(),
            name: xfile.name,
            mimeType: mimeType,
          ).detectFileType;
        }

        if (file.bytes.length > maxUploadSize) {
          throw FileTooBigMatrixException(length, maxUploadSize);
        }

        if (widget.files.length > 1) {
          scaffoldMessenger.showLoadingSnackBar(
            l10n.sendingAttachmentCountOfCount(
              widget.files.indexOf(xfile) + 1,
              widget.files.length,
            ),
          );
        } else {
          scaffoldMessenger.clearSnackBars();
        }

        try {
          await widget.room.sendFileEvent(
            file,
            thumbnail: thumbnail,
            shrinkImageMaxDimension: compress ? 1600 : null,
            threadRootEventId: widget.threadRootEventId,
            threadLastEventId: widget.threadLastEventId,
          );
        } on MatrixException catch (e) {
          final retryAfterMs = e.retryAfterMs;
          if (e.error != MatrixError.M_LIMIT_EXCEEDED || retryAfterMs == null) {
            rethrow;
          }
          final retryAfterDuration =
              Duration(milliseconds: retryAfterMs + 1000);

          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                l10n.serverLimitReached(retryAfterDuration.inSeconds),
              ),
            ),
          );
          await Future.delayed(retryAfterDuration);

          scaffoldMessenger.showLoadingSnackBar(l10n.sendingAttachment);

          await widget.room.sendFileEvent(
            file,
            thumbnail: thumbnail,
            shrinkImageMaxDimension: compress ? null : 1600,
            threadRootEventId: widget.threadRootEventId,
            threadLastEventId: widget.threadLastEventId,
          );
        } finally {
          final directory = await getApplicationSupportDirectory();
          final tempDirectoryPath = '${directory.path}\\temp';
          if (xfile.path.contains(tempDirectoryPath)) {
            final file = File(xfile.path);
            await file.delete();
          }
        }
      }
      scaffoldMessenger.clearSnackBars();
    } catch (e) {
      scaffoldMessenger.clearSnackBars();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(e.toLocalizedString(widget.outerContext)),
          duration: const Duration(seconds: 30),
          showCloseIcon: true,
        ),
      );
      rethrow;
    }

    return;
  }

  void _deleteTempFiles() async {
    for (final xfile in widget.files) {
      final directory = await getApplicationSupportDirectory();
      final tempDirectoryPath = '${directory.path}\\temp';
      if (xfile.path.contains(tempDirectoryPath)) {
        final file = File(xfile.path);
        await file.delete();
      }
    }
  }

  Future<String> _calcCombinedFileSize() async {
    final lengths =
        await Future.wait(widget.files.map((file) => file.length()));
    return lengths.fold<double>(0, (p, length) => p + length).sizeString;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var sendStr = L10n.of(context).sendFile;
    final uniqueMimeType = widget.files
        .map((file) => file.mimeType ?? lookupMimeType(file.name))
        .toSet()
        .singleOrNull;

    final fileName = widget.files.length == 1
        ? widget.files.single.name
        : L10n.of(context).countFiles(widget.files.length.toString());
    final fileTypes = widget.files
        .map((file) => file.name.split('.').last)
        .toSet()
        .join(', ')
        .toUpperCase();

    if (uniqueMimeType?.startsWith('image') ?? false) {
      if (widget.files.length == 1) {
        sendStr = L10n.of(context).sendImage;
      } else {
        sendStr = L10n.of(context).sendImages(widget.files.length);
      }
    } else if (uniqueMimeType?.startsWith('audio') ?? false) {
      sendStr = L10n.of(context).sendAudio;
    } else if (uniqueMimeType?.startsWith('video') ?? false) {
      sendStr = L10n.of(context).sendVideo;
    }

    return FutureBuilder<String>(
      future: _calcCombinedFileSize(),
      builder: (context, snapshot) {
        final sizeString =
            snapshot.data ?? L10n.of(context).calculatingFileSize;

        return AlertDialog.adaptive(
          title: Text(sendStr),
          content: SizedBox(
            width: 256,
            child: RawKeyboardListener(
              focusNode: _focusNode,
              autofocus: true,
              onKey: (RawKeyEvent event) {
                if (event.isKeyPressed(LogicalKeyboardKey.enter)) {
                  _send();
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  if (uniqueMimeType?.startsWith('image') ?? false)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: SizedBox(
                        height: 256,
                        child: Center(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: widget.files.length,
                            scrollDirection: Axis.horizontal,
                            itemBuilder: (context, i) => Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Material(
                                borderRadius: BorderRadius.circular(
                                  AppConfig.borderRadius / 2,
                                ),
                                clipBehavior: Clip.antiAliasWithSaveLayer,
                                child: kIsWeb
                                    ? Image.network(
                                        widget.files[i].path,
                                        height: 256,
                                      )
                                    : Image.file(
                                        File(widget.files[i].path),
                                        height: 256,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (uniqueMimeType?.startsWith('image') != true)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Row(
                        children: [
                          Icon(
                            uniqueMimeType == null
                                ? Icons.description_outlined
                                : uniqueMimeType.startsWith('video')
                                    ? Icons.video_file_outlined
                                    : uniqueMimeType.startsWith('audio')
                                        ? Icons.audio_file_outlined
                                        : Icons.description_outlined,
                            size: 32,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fileName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '$sizeString - $fileTypes',
                                  style: theme.textTheme.labelSmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Workaround for SwitchListTile.adaptive crashes in CupertinoDialog
                  if (uniqueMimeType != null &&
                      (uniqueMimeType.startsWith('image') ||
                          uniqueMimeType.startsWith('video')))
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if ({TargetPlatform.iOS, TargetPlatform.macOS}
                            .contains(theme.platform))
                          CupertinoSwitch(
                            value: compress,
                            onChanged: uniqueMimeType.startsWith('video') &&
                                    !PlatformInfos.isMobile
                                ? null
                                : (v) => setState(() => compress = v),
                          )
                        else
                          Switch.adaptive(
                            value: compress,
                            onChanged: uniqueMimeType.startsWith('video') &&
                                    !PlatformInfos.isMobile
                                ? null
                                : (v) => setState(() => compress = v),
                          ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    L10n.of(context).compress,
                                    style: theme.textTheme.titleMedium,
                                    textAlign: TextAlign.left,
                                  ),
                                ],
                              ),
                              if (!compress)
                                Text(
                                  ' ($sizeString)',
                                  style: theme.textTheme.labelSmall,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            AdaptiveDialogAction(
              onPressed: () => {
                _deleteTempFiles(),
                Navigator.of(context, rootNavigator: false).pop(),
              },
              child: Text(L10n.of(context).cancel),
            ),
            AdaptiveDialogAction(
              onPressed: _send,
              child: Text(L10n.of(context).send),
            ),
          ],
        );
      },
    );
  }
}

extension on ScaffoldMessengerState {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showLoadingSnackBar(
    String title,
  ) {
    clearSnackBars();
    return showSnackBar(
      SnackBar(
        duration: const Duration(minutes: 5),
        dismissDirection: DismissDirection.none,
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator.adaptive(
                strokeWidth: 2,
              ),
            ),
            const SizedBox(width: 16),
            Text(title),
          ],
        ),
      ),
    );
  }
}
