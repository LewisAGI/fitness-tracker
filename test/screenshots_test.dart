import 'dart:io';
import 'dart:ui' as ui;

import 'package:fitness_tracker/app.dart';
import 'package:fitness_tracker/data/store.dart';
import 'package:fitness_tracker/services/checkin_scheduler.dart';
import 'package:fitness_tracker/services/speech_capture.dart';
import 'package:fitness_tracker/services/voice_parser.dart';
import 'package:fitness_tracker/widgets/confirm_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/screenshot_fonts.dart';
import 'screens_test.dart' show RecordingNotifications;
import 'support/harness.dart';

const _logicalWidth = 390.0;
const _logicalHeight = 844.0;
const _pixelRatio = 3.0;

void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('screenshots of the main screens', (tester) async {
    await loadAppFonts();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    final store = await openStore();
    await seedDemo(store);
    final boundary = GlobalKey();
    tester.view.devicePixelRatio = _pixelRatio;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.binding.setSurfaceSize(const Size(_logicalWidth, _logicalHeight));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: FitnessApp(
          store: store,
          scheduler: CheckInScheduler(RecordingNotifications()),
          speech: SpeechCapture(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _shoot(tester, boundary, 'today');

    await tester.tap(find.byKey(const ValueKey('morning-status')));
    await tester.pumpAndSettle();
    await _shoot(tester, boundary, 'checkin_morning');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('evening-status')));
    await tester.pumpAndSettle();
    await _shoot(tester, boundary, 'checkin_evening');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    final parser = VoiceParser(store.exercises);
    await _showConfirm(tester, store, parser.parse('bench press, 4 sets of 8 at 70 kilos'));
    await _shoot(tester, boundary, 'confirm_gym');
    await tester.tap(find.byTooltip('Discard'));
    await tester.pumpAndSettle();

    await _showConfirm(
      tester,
      store,
      parser.parse('an hour of technique and pads and 30 minutes of clinch'),
    );
    await _shoot(tester, boundary, 'confirm_thai');
    await tester.tap(find.byTooltip('Discard'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('tab-Plan')));
    await tester.pumpAndSettle();
    await _shoot(tester, boundary, 'plan_weekly_cards');

    await tester.tap(find.byKey(const ValueKey('warning-2026-10-12')));
    await tester.pumpAndSettle();
    await _shoot(tester, boundary, 'plan_warning');
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('tab-Settings')));
    await tester.pumpAndSettle();
    await _shoot(tester, boundary, 'settings');

    await tester.tap(find.byKey(const ValueKey('tab-History')));
    await tester.pumpAndSettle();
    await _shoot(tester, boundary, 'history');

    await tester.tap(find.byKey(const ValueKey('tab-Insights')));
    await tester.pumpAndSettle();
    await _shoot(tester, boundary, 'insights');
    debugDefaultTargetPlatformOverride = null;
  });
}

Future<void> _showConfirm(WidgetTester tester, Store store, ParseResult result) async {
  final context = tester.element(find.byType(Scaffold).first);
  showDialog<void>(
    context: context,
    builder: (context) => ConfirmCard(
      result: result,
      exercises: store.exercises,
      onAlias: store.addAlias,
      onSave: (draft) => store.saveParse(draft),
      autoSaveAfter: null,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _shoot(WidgetTester tester, GlobalKey boundary, String name) async {
  await tester.pump();
  final object = tester.renderObject<RenderRepaintBoundary>(find.byKey(boundary));
  final image = (object.debugLayer! as OffsetLayer).toImageSync(
    object.paintBounds,
    pixelRatio: _pixelRatio,
  );
  expect(image.width, _logicalWidth * _pixelRatio);
  expect(image.height, _logicalHeight * _pixelRatio);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final override = Platform.environment['SCREENSHOT_DIR'];
  final directory = override != null && override.isNotEmpty
      ? override
      : Directory.systemTemp.createTempSync('fitness-screenshots').path;
  final file = File('$directory/$name.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(data!.buffer.asUint8List());
}
