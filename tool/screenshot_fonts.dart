import 'dart:io';

import 'package:flutter/services.dart';

/// Loads Roboto and Material Icons from the Flutter SDK so widget screenshots
/// are not drawn with the test font (Ahem).
Future<void> loadAppFonts() async {
  final directory = _materialFontsDirectory();
  final roboto = FontLoader('Roboto');
  for (final name in const [
    'Roboto-Regular.ttf',
    'Roboto-Italic.ttf',
    'Roboto-Medium.ttf',
    'Roboto-MediumItalic.ttf',
    'Roboto-Bold.ttf',
    'Roboto-BoldItalic.ttf',
  ]) {
    roboto.addFont(_readFont(File('${directory.path}/$name')));
  }
  await roboto.load();

  final icons = FontLoader('MaterialIcons')
    ..addFont(_readFont(File('${directory.path}/MaterialIcons-Regular.otf')));
  await icons.load();
}

Future<ByteData> _readFont(File file) async {
  if (!file.existsSync()) {
    throw StateError('Font file not found: ${file.path}');
  }
  final bytes = await file.readAsBytes();
  return ByteData.sublistView(bytes);
}

Directory _materialFontsDirectory() {
  final candidates = <String>[
    if (Platform.environment['FLUTTER_ROOT'] case final root?)
      '$root/bin/cache/artifacts/material_fonts',
    '${Platform.environment['HOME']}/sdk/flutter/bin/cache/artifacts/material_fonts',
    '${Platform.environment['HOME']}/flutter/bin/cache/artifacts/material_fonts',
  ];
  for (final path in candidates) {
    final directory = Directory(path);
    if (directory.existsSync()) {
      return directory;
    }
  }
  throw StateError(
    'Material fonts not found. Set FLUTTER_ROOT to the Flutter SDK. Looked in: $candidates',
  );
}
