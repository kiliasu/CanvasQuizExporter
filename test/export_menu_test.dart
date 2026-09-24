import 'dart:io';

import 'package:canvas_quiz_exporter/domain/models.dart';
import 'package:canvas_quiz_exporter/main.dart';
import 'package:canvas_quiz_exporter/services/app_controller.dart';
import 'package:canvas_quiz_exporter/services/settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

class RecordingController extends AppController {
  final requests = <bool>[];
  RecordingController(String settingsPath)
    : super(
        store: SettingsStore(path: settingsPath),
        fonts: testFonts(),
      ) {
    settings.language = 'zh';
  }
  @override
  Future<void> export({bool selectedOnly = false}) async {
    requests.add(selectedOnly);
  }
}

void main() {
  testWidgets(
    'export menu appears above its anchor and supports Escape, outside click and keyboard action',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync(
        'canvas-menu-test-',
      );
      final controller = RecordingController('${directory.path}/settings.json');
      final entry = QueueEntry('${directory.path}/demo.html')
        ..document = QuizDocument(
          title: 'Demo quiz',
          sourcePath: 'demo.html',
          sourceHash: '',
          questions: [
            QuizQuestion(
              number: 1,
              type: 'essay_question',
              text: 'Explain the result.',
            ),
          ],
        );
      controller.entries.add(entry);
      controller.current = entry;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 920);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        controller.dispose();
        directory.deleteSync(recursive: true);
      });
      await tester.pumpWidget(
        CanvasApp(controller: controller, nativeWindow: false),
      );
      await tester.pumpAndSettle();
      final toggle = find.byKey(const ValueKey('export-menu-toggle'));
      final selected = find.byKey(const ValueKey('export-selected'));
      expect(find.text('导出全部 · 1'), findsOneWidget);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.text('导出选中 · demo'), findsOneWidget);
      expect(tester.getSize(selected).height, 56);
      expect(
        tester.getRect(selected).bottom,
        closeTo(tester.getRect(toggle).top - 8, .01),
      );
      expect(
        tester.getRect(selected).right,
        closeTo(tester.getRect(toggle).right, .01),
      );
      expect(controller.requests, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(selected, findsNothing);
      expect(tester.widget<IconButton>(toggle).focusNode!.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(selected, findsOneWidget);
      await tester.tapAt(const Offset(500, 32));
      await tester.pumpAndSettle();
      expect(selected, findsNothing);
      expect(controller.requests, isEmpty);
      controller.settings.reducedMotion = true;
      controller.changed();
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(controller.requests, [true]);
      expect(selected, findsNothing);
      final failed = QueueEntry('${directory.path}/broken.html')
        ..error = 'Cannot read quiz';
      controller.entries.add(failed);
      controller.current = failed;
      controller.changed();
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.text('导出选中 · 未选择网页'), findsOneWidget);
      expect(tester.widget<MenuItemButton>(selected).onPressed, isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(controller.requests, [true]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
