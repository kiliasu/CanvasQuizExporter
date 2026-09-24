import 'dart:io';

import 'package:canvas_quiz_exporter/main.dart';
import 'package:canvas_quiz_exporter/services/app_controller.dart';
import 'package:canvas_quiz_exporter/services/settings_store.dart';
import 'package:canvas_quiz_exporter/domain/parser.dart';
import 'package:canvas_quiz_exporter/domain/models.dart';
import 'package:canvas_quiz_exporter/ui/settings_panel.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support.dart';

void main() {
  late Directory root;
  late AppController c;
  String? copiedText;
  setUp(() {
    copiedText = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedText = (call.arguments as Map)['text'] as String;
          }
          if (call.method == 'Clipboard.getData') return {'text': copiedText};
          return null;
        });
    root = Directory.systemTemp.createTempSync('canvas-widgets-');
    c = AppController(
      store: SettingsStore(path: p.join(root.path, 'settings.json')),
      fonts: testFonts(),
    );
    c.settings.reducedMotion = true;
    c.settings.language = 'zh';
  });
  tearDown(() {
    c.dispose();
    root.deleteSync(recursive: true);
  });
  Future<void> show(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(CanvasApp(controller: c, nativeWindow: false));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'empty workspace, help, theme, and minimum width have no layout errors',
    (tester) async {
      await show(tester, const Size(1080, 720));
      expect(find.text('网页里的知识，整理到手边'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('export-all')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('切换深色'));
      await tester.pumpAndSettle();
      expect(c.settings.dark, isTrue);
      await tester.tap(find.byTooltip('配色方案'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('青绿'));
      await tester.pumpAndSettle();
      expect(c.settings.scheme, 'teal');
      await tester.sendKeyEvent(LogicalKeyboardKey.f1);
      await tester.pumpAndSettle();
      expect(find.text('从网页到资料，只需三步'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'search, literal filtering and full copy use the same data; editing Delete preserves queue',
    (tester) async {
      final source = writeQuiz(
        root,
        'quiz.html',
        quizHtml(text: 'Remove phrase. Choose the even number.'),
      );
      final entry = QueueEntry(source.path)..document = parseQuiz(source.path);
      c.entries.add(entry);
      c.current = entry;
      await show(tester, const Size(1440, 900));
      await tester.enterText(
        find.byKey(const ValueKey('question-search')),
        'not found',
      );
      await tester.pumpAndSettle();
      expect(find.text('没有匹配的题目'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('question-search')), '');
      final filter = find.descendant(
        of: find.byKey(const ValueKey('filters')),
        matching: find.byType(TextField),
      );
      await tester.enterText(filter, 'remove phrase.');
      await tester.pumpAndSettle();
      expect(c.document!.questions.single.text, 'Choose the even number.');
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      expect(c.entries.length, 1);
      await tester.tap(find.byKey(const ValueKey('copy-all')));
      await tester.pump();
      expect(copiedText, c.document!.plainText());
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'results, settings expansion and actual controller export fit minimum window',
    (tester) async {
      final source = writeQuiz(root, 'quiz.html', quizHtml());
      final entry = QueueEntry(source.path)..document = parseQuiz(source.path);
      c.entries.add(entry);
      c.current = entry;
      await show(tester, const Size(1080, 720));
      await tester.runAsync(() => c.export());
      await tester.pumpAndSettle();
      expect(c.results.length, 1);
      expect(find.text('导出记录'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('收起结果'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('advanced-options')),
        180,
        scrollable: find
            .descendant(
              of: find.byType(SettingsPanel),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.byKey(const ValueKey('advanced-options')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('name-template')),
        150,
        scrollable: find
            .descendant(
              of: find.byType(SettingsPanel),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.byKey(const ValueKey('name-template')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'PDF tab renders the generated document and navigates real pages',
    (tester) async {
      c.settings.reducedMotion = false;
      Pdfrx.cacheDirectoryPath = Directory.systemTemp.path;
      final entry = QueueEntry(p.join(root.path, 'demo.html'))
        ..document = QuizDocument(
          title: 'PDF pagination test',
          sourcePath: 'demo',
          sourceHash: '',
          questions: [
            for (var i = 1; i <= 24; i++)
              QuizQuestion(
                number: i,
                type: 'essay_question',
                text: 'Explain the circuit and describe the current.',
                userAnswer: 'Each component affects the behavior of the complete circuit.',
              ),
          ],
        );
      c.entries.add(entry);
      c.current = entry;
      await show(tester, const Size(1440, 900));
      await tester.tap(find.text('PDF 分页'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      // The painted sheet: offstage neighbors are skipped by the finders.
      final sheet = find.byType(PdfPageView);
      final image = find.descendant(of: sheet, matching: find.byType(RawImage));
      int shownPage() => tester.widget<PdfPageView>(sheet).pageNumber;
      for (var i = 0; i < 60 && image.evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      expect(sheet, findsOneWidget);
      expect(shownPage(), 1);
      expect(image, findsOneWidget);
      final pageRect = tester.getRect(sheet);
      await tester.tap(find.byTooltip('下一页'));
      await tester.pump();
      // Every frame keeps a rendered sheet in place: the previous page stays
      // until the next one is ready, so paging never flashes a blank page.
      for (var i = 0; i < 60 && shownPage() != 2; i++) {
        expect(image, findsOneWidget);
        expect(tester.getRect(sheet), pageRect);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      expect(shownPage(), 2);
      expect(image, findsOneWidget);
      expect(tester.getRect(sheet), pageRect);
      await tester.tap(find.byTooltip('上一页'));
      await tester.pump();
      // The previous page was kept rendered, so it returns in one frame.
      expect(shownPage(), 1);
      expect(image, findsOneWidget);
      await tester.pumpAndSettle();
      await tester.tap(find.text('总览'));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'normal motion supports theme, palette and result panel transitions',
    (tester) async {
      c.settings.reducedMotion = false;
      await show(tester, const Size(1440, 920));
      await tester.tap(find.byTooltip('配色方案'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('切换深色'));
      await tester.pumpAndSettle();
      c.resultsOpen = true;
      c.logs.add('Synthetic export log');
      c.changed();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('收起结果'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
