import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../widgets/icon_tip.dart';
import 'export_summary.dart';

Future<void> offerExport(BuildContext context, ExportFiles files) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTip(
              icon: Icons.copy,
              message: 'Copy',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: files.plain));
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
            ),
            IconTip(
              icon: Icons.ios_share,
              message: 'Share',
              onPressed: () async {
                await shareExport(dialogContext, files);
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> shareExport(BuildContext context, ExportFiles files) async {
  Rect? origin;
  if (Platform.isIOS) {
    final box = context.findRenderObject();
    if (box is RenderBox && box.hasSize && box.size.width > 0) {
      origin = box.localToGlobal(Offset.zero) & box.size;
    } else {
      origin = const Rect.fromLTWH(1, 1, 2, 2);
    }
  }
  final dir = await getTemporaryDirectory();
  final textFile = File('${dir.path}/fitness.txt');
  final jsonFile = File('${dir.path}/fitness-summary-v1.json');
  final mdFile = File('${dir.path}/summary.md');
  await textFile.writeAsString(files.plain);
  await jsonFile.writeAsString(files.json);
  await mdFile.writeAsString(files.markdown);
  await SharePlus.instance.share(
    ShareParams(
      text: files.plain,
      files: [
        XFile(textFile.path, mimeType: 'text/plain'),
        XFile(jsonFile.path, mimeType: 'application/json'),
        XFile(mdFile.path, mimeType: 'text/markdown'),
      ],
      sharePositionOrigin: origin,
    ),
  );
}
