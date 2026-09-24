import 'dart:io';

import 'package:canvas_quiz_exporter/domain/models.dart';
import 'package:canvas_quiz_exporter/main.dart';
import 'package:canvas_quiz_exporter/services/app_controller.dart';
import 'package:canvas_quiz_exporter/services/settings_store.dart';
import 'package:canvas_quiz_exporter/ui/question_card.dart';
import 'package:canvas_quiz_exporter/ui/reference_controls.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  late Directory temp;
  late AppController c;
  String? copiedText;
  setUp(() {
    copiedText = null;
    temp = Directory.systemTemp.createTempSync('canvas-interaction-');
    c = AppController(
      store: SettingsStore(path: '${temp.path}/settings.json'),
      fonts: testFonts(),
    )..settings.language = 'zh';
    final entry = QueueEntry('${temp.path}/quiz.html')
      ..document = QuizDocument(
        title: 'Quiz',
        sourcePath: 'quiz.html',
        sourceHash: '',
        questions: [
          for (var i = 1; i <= 30; i++)
            QuizQuestion(
              number: i,
              type: 'multiple_choice_question',
              text: 'Question $i',
              options: [QuizOption('Choice $i', selected: true)],
            ),
        ],
      );
    c.entries.add(entry);
    c.current = entry;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedText = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
  });
  tearDown(() {
    c.dispose();
    temp.deleteSync(recursive: true);
  });
  Future<void> show(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1000);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(CanvasApp(controller: c, nativeWindow: false));
    await tester.pumpAndSettle();
  }

  QueueEntry addOtherPage() {
    final other = QueueEntry('${temp.path}/other.html')
      ..document = QuizDocument(
        title: 'Other quiz',
        sourcePath: 'other.html',
        sourceHash: '',
        questions: [
          QuizQuestion(
            number: 1,
            type: 'multiple_choice_question',
            text: 'Other question',
            options: [QuizOption('Other choice')],
          ),
        ],
      );
    c.entries.add(other);
    return other;
  }

  testWidgets(
    'palette keeps its two solid halves when a settings switch changes',
    (tester) async {
      await show(tester);
      final palette = find.byTooltip('配色方案');
      LinearGradient gradient() =>
          (tester
                          .widget<DecoratedBox>(
                            find.descendant(
                              of: palette,
                              matching: find.byWidgetPredicate(
                                (w) =>
                                    w is DecoratedBox &&
                                    w.decoration is BoxDecoration &&
                                    (w.decoration as BoxDecoration).gradient !=
                                        null,
                              ),
                            ),
                          )
                          .decoration
                      as BoxDecoration)
                  .gradient
              as LinearGradient;
      final before = gradient();
      await tester.tap(find.byType(ReferenceSwitch).first);
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 80));
        expect(gradient().stops, before.stops);
        expect(
          gradient().colors.map((c) => c.toARGB32()),
          before.colors.map((c) => c.toARGB32()),
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'overview tabs retain their elastic animation across mode changes',
    (tester) async {
      await show(tester);
      final group = find
          .ancestor(
            of: find.text('PDF 分页'),
            matching: find.byType(ReferenceButtonGroup<bool>),
          )
          .first;
      final before = tester.state(group);
      final surfaces = find.descendant(
        of: group,
        matching: find.byType(AnimatedContainer),
      );
      final idleWidth = tester.getSize(surfaces.last).width;
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('PDF 分页')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final pressedWidth = tester.getSize(surfaces.last).width;
      expect(pressedWidth, greaterThan(idleWidth));
      await gesture.up();
      await tester.pump();
      expect(tester.state(group), same(before));
      expect(tester.getSize(surfaces.last).width, closeTo(pressedWidth, .1));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getSize(surfaces.last).width, lessThan(pressedWidth));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 250)),
      );
    },
  );
  testWidgets(
    'returning to overview shows questions without replaying an entrance',
    (tester) async {
      await show(tester);
      c.setView(true);
      await tester.pump();
      c.setView(false);
      await tester.pump();
      final card = find.byType(QuestionCard).first;
      final top = tester.getTopLeft(card);
      await tester.pump(const Duration(milliseconds: 450));
      expect(tester.getTopLeft(card), top);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'switching pages shows the header and questions without an entrance',
    (tester) async {
      final other = addOtherPage();
      await show(tester);
      c.select(other);
      await tester.pump();
      final targets = {
        'title': find.text('Other quiz'),
        'chip': find.descendant(
          of: find.byType(ReferenceChip),
          matching: find.text('1 道题'),
        ),
        'question': find.text('Other question'),
        'option': find.text('Other choice'),
      };
      final rects = {
        for (final target in targets.entries)
          target.key: tester.getRect(target.value),
      };
      for (final target in targets.entries) {
        expect(
          find.ancestor(
            of: target.value,
            matching: find.byWidgetPredicate(
              (w) =>
                  (w is Opacity && w.opacity < 1) ||
                  (w is FadeTransition && w.opacity.value < 1),
            ),
          ),
          findsNothing,
          reason: '${target.key} faded in',
        );
      }
      await tester.pump(const Duration(milliseconds: 450));
      for (final target in targets.entries) {
        expect(
          tester.getRect(target.value),
          rects[target.key],
          reason: target.key,
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'fast scrolling shows question text in place and keeps the list offset',
    (tester) async {
      final other = addOtherPage();
      await show(tester);
      ScrollPosition list() =>
          Scrollable.of(tester.element(find.byType(QuestionCard).first))
              .position;
      final wheel = TestPointer(1, PointerDeviceKind.mouse)
        ..hover(tester.getCenter(find.byType(QuestionCard).first));
      for (var step = 0; step < 3; step++) {
        await tester.sendEventToBinding(wheel.scroll(const Offset(0, 800)));
        await tester.pump();
        // Selectable text scrolls internally. Restoring the list's saved
        // offset there drew newly built text above its card, then slid it in.
        final texts = tester.stateList<ScrollableState>(
          find.descendant(
            of: find.byType(QuestionCard),
            matching: find.byType(Scrollable),
          ),
        );
        expect(texts, isNotEmpty);
        for (final text in texts) {
          expect(text.position.pixels, 0);
        }
      }
      final offset = list().pixels;
      expect(offset, greaterThan(0));
      await tester.pump(const Duration(seconds: 2));
      c.setView(true);
      await tester.pump();
      c.setView(false);
      await tester.pump();
      expect(list().pixels, offset, reason: 'back from PDF pagination');
      c.select(other);
      await tester.pump();
      c.select(c.entries.first);
      await tester.pump();
      expect(list().pixels, offset, reason: 'back from another page');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('clickable controls show the hand cursor on desktop', (
    tester,
  ) async {
    await show(tester);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    Future<MouseCursor?> cursorAt(Offset position) async {
      await mouse.moveTo(position);
      await tester.pump();
      // flutter_test gives mouse pointers device 1 by default.
      return RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1);
    }

    final clickable = {
      'filled button': find.text('添加网页'),
      'icon button': find.byTooltip('配色方案'),
      'panel toggle': find.byTooltip('最小化网页文件'),
      'queue item': find.text('quiz'),
      'copy all': find.byKey(const ValueKey('copy-all')),
      'export': find.byKey(const ValueKey('export-all')),
      'export menu': find.byKey(const ValueKey('export-menu-toggle')),
      'checkbox': find.text('PDF 文档'),
    };
    for (final target in clickable.entries) {
      expect(
        await cursorAt(tester.getCenter(target.value)),
        SystemMouseCursors.click,
        reason: target.key,
      );
    }
    expect(
      await cursorAt(
        tester.getTopLeft(find.byType(QuestionCard).first) +
            const Offset(10, 50),
      ),
      SystemMouseCursors.click,
      reason: 'question card',
    );
    expect(
      await cursorAt(tester.getCenter(find.text('内容预览'))),
      SystemMouseCursors.basic,
    );
    c.busy = true;
    c.changed();
    await tester.pump();
    expect(
      await cursorAt(tester.getCenter(find.text('添加网页'))),
      SystemMouseCursors.basic,
      reason: 'disabled button',
    );
    c.busy = false;
    c.changed();
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'copy feedback is a centered 48px pill above the footer and replaces itself',
    (tester) async {
      await show(tester);
      await tester.tap(find.byKey(const ValueKey('copy-all')));
      await tester.pumpAndSettle();
      final toast = find.byKey(const ValueKey('reference-toast'));
      expect(toast, findsOneWidget);
      expect(tester.getSize(toast).height, 48);
      expect(tester.getRect(toast).center.dx, 720);
      expect(tester.getRect(toast).bottom, 896);
      expect(find.text('已复制全文 · 30 道题'), findsOneWidget);
      expect(copiedText, c.document!.plainText());
      c.results.addAll(['${temp.path}/one.txt', '${temp.path}/two.json']);
      c.resultsOpen = true;
      c.changed();
      await tester.pumpAndSettle();
      await tester.tap(find.text('复制文件路径'));
      await tester.pumpAndSettle();
      expect(copiedText, c.results.join('\n'));
      expect(find.text('已复制全文 · 30 道题'), findsNothing);
      expect(find.text('已复制 2 个文件路径'), findsOneWidget);
      await tester.tap(toast);
      await tester.pumpAndSettle();
      expect(find.text('已复制 2 个文件路径'), findsNothing);
      await tester.tap(find.text('复制').first);
      await tester.pumpAndSettle();
      expect(find.text('已复制第 1 题'), findsOneWidget);
      expect(copiedText, c.document!.questions.first.plainText());
      await tester.pump(const Duration(milliseconds: 3200));
      await tester.pumpAndSettle();
      expect(toast, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
