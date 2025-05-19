import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:async/async.dart' as async;
import 'package:cloudchat/utils/platform_infos.dart';
import 'package:cloudchat/widgets/matrix.dart';
import 'package:matrix/matrix.dart';

import 'package:cloudchat/utils/size_string.dart';
import 'package:cloudchat/widgets/future_loading_dialog.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'matrix_file_extension.dart';

extension LocalizedBody on Event {
  Future<async.Result<MatrixFile?>> _getFile(BuildContext context) =>
      showFutureLoadingDialog(
        context: context,
        future: downloadAndDecryptAttachment,
      );

  void saveFile(BuildContext context) async {
    final matrixFile = await _getFile(context);

    matrixFile.result?.save(context);
  }

  void openFile(BuildContext context) async {
    final path = Matrix.of(
      context,
    ).store.getString(content.tryGet<String>('filename') ?? body);

    if (path != null) {
      if (PlatformInfos.isDesktop) {
        _revealInFileManager(path);
      } else if (PlatformInfos.isMobile) {
        await OpenFile.open(path);
      }
    }
  }

  void _revealInFileManager(String filePath) {
    final directory = p.dirname(filePath);

    if (Platform.isWindows) {
      Process.run('explorer', ['/select,', filePath]);
    } else if (Platform.isMacOS) {
      Process.run('open', ['-R', filePath]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [directory]);
    }
  }

  void shareFile(BuildContext context) async {
    final matrixFile = await _getFile(context);
    inspect(matrixFile);

    matrixFile.result?.share(context);
  }

  bool get isAttachmentSmallEnough =>
      infoMap['size'] is int &&
      infoMap['size'] < room.client.database!.maxFileSize;

  bool get isThumbnailSmallEnough =>
      thumbnailInfoMap['size'] is int &&
      thumbnailInfoMap['size'] < room.client.database!.maxFileSize;

  bool get showThumbnail =>
      [
        MessageTypes.Image,
        MessageTypes.Sticker,
        MessageTypes.Video,
      ].contains(messageType) &&
      (kIsWeb ||
          isAttachmentSmallEnough ||
          isThumbnailSmallEnough ||
          (content['url'] is String));

  String? get sizeString =>
      content
          .tryGetMap<String, dynamic>('info')
          ?.tryGet<int>('size')
          ?.sizeString;
}
