import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:chewie/chewie.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:matrix/matrix.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;
import 'package:video_player/video_player.dart';

import 'package:cloudchat/config/app_config.dart';
import 'package:cloudchat/pages/chat/events/image_bubble.dart';
import 'package:cloudchat/utils/localized_exception_extension.dart';
import 'package:cloudchat/utils/matrix_sdk_extensions/event_extension.dart';
import 'package:cloudchat/utils/platform_infos.dart';
import 'package:cloudchat/widgets/blur_hash.dart';
import '../../../utils/error_reporter.dart';

class EventVideoPlayer extends StatefulWidget {
  final Event event;
  const EventVideoPlayer(this.event, {super.key});

  @override
  EventVideoPlayerState createState() => EventVideoPlayerState();
}

class EventVideoPlayerState extends State<EventVideoPlayer> {
  ChewieController? _chewieManager;
  bool _isDownloading = false;
  String? _networkUri;
  File? _tmpFile;

  void _downloadAction() async {
    if (PlatformInfos.isDesktop) {
      widget.event.saveFile(context);
      return;
    }
    setState(() => _isDownloading = true);
    try {
      final videoFile = await widget.event.downloadAndDecryptAttachment();
      if (kIsWeb) {
        final blob = html.Blob([videoFile.bytes]);
        _networkUri = html.Url.createObjectUrlFromBlob(blob);
      } else {
        final tempDir = await getTemporaryDirectory();
        final fileName = Uri.encodeComponent(
          widget.event.attachmentOrThumbnailMxcUrl()!.pathSegments.last,
        );
        final file = File('${tempDir.path}/${fileName}_${videoFile.name}');
        if (await file.exists() == false) {
          await file.writeAsBytes(videoFile.bytes);
        }
        _tmpFile = file;
      }
      final tmpFile = _tmpFile;
      final networkUri = _networkUri;
      if (kIsWeb && networkUri != null && _chewieManager == null) {
        _chewieManager ??= ChewieController(
          videoPlayerController:
              VideoPlayerController.networkUrl(Uri.parse(networkUri)),
          autoPlay: true,
          autoInitialize: true,
        );
      } else if (!kIsWeb && tmpFile != null && _chewieManager == null) {
        _chewieManager ??= ChewieController(
          useRootNavigator: false,
          videoPlayerController: VideoPlayerController.file(tmpFile),
          autoPlay: true,
          autoInitialize: true,
        );
      }
    } on IOException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toLocalizedString(context)),
        ),
      );
    } catch (e, s) {
      ErrorReporter(context, 'Unable to play video').onErrorCallback(e, s);
    } finally {
      // Workaround for Chewie needs time to get the aspectRatio
      await Future.delayed(const Duration(milliseconds: 100));
      setState(() => _isDownloading = false);
    }
  }

  @override
  void dispose() {
    _chewieManager?.dispose();
    super.dispose();
  }

  static const String fallbackBlurHash = 'L5H2EC=PM+yV0g-mq.wG9c010J}I';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final hasThumbnail = widget.event.hasThumbnail;
    final blurHash = (widget.event.infoMap as Map<String, dynamic>)
            .tryGet<String>('xyz.amorgan.blurhash') ??
        fallbackBlurHash;

    final chewieManager = _chewieManager;
    return Material(
      color: Colors.black,
      borderRadius: BorderRadius.circular(AppConfig.borderRadius),
      child: SizedBox(
        height: 300,
        child: chewieManager != null
            ? Center(child: Chewie(controller: chewieManager))
            : Stack(
                children: [
                  if (hasThumbnail)
                    Center(
                      child: ImageBubble(
                        widget.event,
                        tapToView: false,
                      ),
                    )
                  else
                    BlurHash(blurhash: blurHash, width: 300, height: 300),
                  Center(
                    child: IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: theme.colorScheme.surface,
                      ),
                      icon: _isDownloading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator.adaptive(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.play_circle_outlined),
                      tooltip: _isDownloading
                          ? L10n.of(context).loadingPleaseWait
                          : L10n.of(context).videoWithSize(
                              widget.event.sizeString ?? '?MB',
                            ),
                      onPressed: _isDownloading ? null : _downloadAction,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
