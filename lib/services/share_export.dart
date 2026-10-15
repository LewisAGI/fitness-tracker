import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'export_summary.dart';

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
  final jsonFile = File('${dir.path}/fitness-summary-v1.json');
  final mdFile = File('${dir.path}/summary.md');
  await jsonFile.writeAsString(files.json);
  await mdFile.writeAsString(files.markdown);
  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile(jsonFile.path, mimeType: 'application/json'),
        XFile(mdFile.path, mimeType: 'text/markdown'),
      ],
      sharePositionOrigin: origin,
    ),
  );
}
