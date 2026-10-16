import 'dart:io';

import 'package:fitness_tracker/services/export_summary.dart';
import 'package:fitness_tracker/services/share_export.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'temp export files are deleted after sharing, including when it throws',
    () async {
      final dir = await Directory.systemTemp.createTemp('fitness-share');
      addTearDown(() async {
        if (dir.existsSync()) {
          await dir.delete(recursive: true);
        }
      });
      const files = ExportFiles(json: '{}', markdown: '# m', plain: 'plain');

      final thrown = await writeExportFiles(dir, files);
      expect(thrown, hasLength(3));
      for (final file in thrown) {
        expect(file.existsSync(), isTrue);
      }
      await expectLater(
        shareWrittenFiles(thrown, () async {
          throw StateError('sheet closed');
        }),
        throwsA(isA<StateError>()),
      );
      for (final file in thrown) {
        expect(file.existsSync(), isFalse);
      }

      final shared = await writeExportFiles(dir, files);
      var sawFiles = false;
      await shareWrittenFiles(shared, () async {
        sawFiles = true;
        expect(shared[0].readAsStringSync(), 'plain');
        expect(shared[1].readAsStringSync(), '{}');
        expect(shared[2].readAsStringSync(), '# m');
      });
      expect(sawFiles, isTrue);
      for (final file in shared) {
        expect(file.existsSync(), isFalse);
      }
    },
  );

  testWidgets('the share anchor is the tapped button', (tester) async {
    late BuildContext buttonContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) {
                buttonContext = context;
                return const SizedBox(
                  key: ValueKey('share-files'),
                  width: 56,
                  height: 56,
                );
              },
            ),
          ),
        ),
      ),
    );
    final button = tester.getRect(find.byKey(const ValueKey('share-files')));
    final rect = shareAnchorRect(buttonContext);
    expect(rect, isNotNull);
    expect(rect!.left, button.left);
    expect(rect.top, button.top);
    expect(rect.width, button.width);
    expect(rect.height, button.height);
    expect(rect.width, greaterThan(0));
    expect(rect.height, greaterThan(0));
    expect(sharePositionOrigin(buttonContext), isNull);
  });
}
