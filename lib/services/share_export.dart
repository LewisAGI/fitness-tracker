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

/// The button's rect, used to anchor an iPad share popover.
Rect? shareAnchorRect(BuildContext context) {
  final box = context.findRenderObject();
  if (box is RenderBox &&
      box.hasSize &&
      box.size.width > 0 &&
      box.size.height > 0) {
    return box.localToGlobal(Offset.zero) & box.size;
  }
  return null;
}

Rect? sharePositionOrigin(BuildContext context) {
  if (!Platform.isIOS) {
    return null;
  }
  return shareAnchorRect(context) ?? const Rect.fromLTWH(1, 1, 2, 2);
}

Future<void> shareText(BuildContext context, String text) async {
  await SharePlus.instance.share(
    ShareParams(text: text, sharePositionOrigin: sharePositionOrigin(context)),
  );
}

Future<List<File>> writeExportFiles(
  Directory directory,
  ExportFiles files,
) async {
  final written = [
    File('${directory.path}/fitness.txt'),
    File('${directory.path}/fitness-summary-v1.json'),
    File('${directory.path}/summary.md'),
  ];
  await written[0].writeAsString(files.plain);
  await written[1].writeAsString(files.json);
  await written[2].writeAsString(files.markdown);
  return written;
}

Future<void> deleteExportFiles(List<File> files) async {
  for (final file in files) {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException {
      // The sheet may already have removed it.
    }
  }
}

/// Runs [share], then removes [files] whether the sheet completed or threw.
Future<void> shareWrittenFiles(
  List<File> files,
  Future<void> Function() share,
) async {
  try {
    await share();
  } finally {
    await deleteExportFiles(files);
  }
}

Future<void> shareExport(BuildContext context, ExportFiles files) async {
  final origin = sharePositionOrigin(context);
  final written = await writeExportFiles(await getTemporaryDirectory(), files);
  await shareWrittenFiles(written, () async {
    await SharePlus.instance.share(
      ShareParams(
        text: files.plain,
        files: [
          XFile(written[0].path, mimeType: 'text/plain'),
          XFile(written[1].path, mimeType: 'application/json'),
          XFile(written[2].path, mimeType: 'text/markdown'),
        ],
        sharePositionOrigin: origin,
      ),
    );
  });
}
