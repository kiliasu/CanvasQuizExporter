import 'dart:io';

import 'package:canvas_quiz_exporter/domain/models.dart';
import 'package:canvas_quiz_exporter/main.dart';
import 'package:canvas_quiz_exporter/services/app_controller.dart';
import 'package:canvas_quiz_exporter/services/settings_store.dart';
import 'package:canvas_quiz_exporter/ui/collapsible_panel.dart';
import 'package:canvas_quiz_exporter/ui/progress_indicators.dart';
import 'package:canvas_quiz_exporter/ui/settings_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support.dart';

void main() {
  late Directory root;
  late AppController c;
  String? copiedText;

  QueueEntry entry(String name) =>
      QueueEntry(p.join(root.path, '$name.html'))
        ..document = QuizDocument(
          title: 'Quiz $name',
          sourcePath: '$name.html',
          sourceHash: '',
          questions: [
            QuizQuestion(
              number: 1,
              type: 'multiple_choice_question',
              text: 'Question of $name',
              options: [QuizOption('Choice', selected: true)],
            ),
          ],
        );

  setUp(() {
    copiedText = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedText = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
    root = Directory.systemTemp.createTempSync('canvas-panels-');
    c = AppController(
      store: SettingsStore(path: p.join(root.path, 'settings.json')),
      fonts: testFonts(),
    );
    c.settings.reducedMotion = true;
    c.settings.language = 'zh';
    c.entries.addAll([entry('first'), entry('second')]);
    c.current = c.entries.first;
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

  double columnWidth(WidgetTester tester, int index) =>
      tester.getSize(find.byType(CollapsibleColumn).at(index)).width;

  testWidgets(
    'side panels collapse to working rails, persist, and keep their state',
    (tester) async {
      await show(tester, const Size(1440, 920));
      expect(columnWidth(tester, 0), 300);
      expect(columnWidth(tester, 1), 340);

      await tester.tap(find.byTooltip('最小化网页文件'));
      await tester.pumpAndSettle();
      expect(c.settings.queueCollapsed, isTrue);
      expect(columnWidth(tester, 0), railPanelWidth);
      expect(find.byTooltip('展开网页文件'), findsOneWidget);
      expect(find.text('网页文件'), findsNothing);
      final second = c.entries.last;
      await tester.tap(find.byKey(ValueKey('rail:${second.path}')));
      await tester.pumpAndSettle();
      expect(c.current, same(second));
      expect(find.text('Quiz second'), findsOneWidget);

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
      await tester.tap(find.byTooltip('最小化导出设置'));
      await tester.pumpAndSettle();
      expect(c.settings.settingsCollapsed, isTrue);
      expect(columnWidth(tester, 1), railPanelWidth);
      expect(find.byKey(const ValueKey('copy-all')), findsNothing);
      expect(find.byKey(const ValueKey('name-template')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('rail-format-pdf')));
      await tester.pumpAndSettle();
      expect(c.settings.formats, containsAll(['txt', 'pdf']));
      await tester.tap(find.byTooltip('同时保存图片资源'));
      await tester.pumpAndSettle();
      expect(c.settings.copyAssets, isFalse);
      await tester.tap(find.byKey(const ValueKey('rail-copy-all')));
      await tester.pump();
      expect(copiedText, c.document!.plainText());
      await tester.pump(const Duration(seconds: 4));

      await tester.pump(const Duration(milliseconds: 400));
      final saved = SettingsStore(path: p.join(root.path, 'settings.json'))
          .load();
      expect(saved.queueCollapsed, isTrue);
      expect(saved.settingsCollapsed, isTrue);

      await tester.tap(find.byTooltip('展开导出设置'));
      await tester.tap(find.byTooltip('展开网页文件'));
      await tester.pumpAndSettle();
      expect(columnWidth(tester, 0), 300);
      expect(columnWidth(tester, 1), 340);
      expect(find.text('网页文件'), findsOneWidget);
      expect(find.byKey(const ValueKey('copy-all')), findsOneWidget);
      // The settings panel stayed mounted, so its expansion survives.
      expect(
        find.byKey(const ValueKey('name-template'), skipOffstage: false),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'collapse animates without overflow and rails fit the minimum window',
    (tester) async {
      c.settings.reducedMotion = false;
      c.results.add(p.join(root.path, 'first.txt'));
      c.logs.add('done');
      c.resultsOpen = true;
      await show(tester, const Size(1080, 720));
      await tester.tap(find.byTooltip('最小化网页文件'));
      await tester.tap(find.byTooltip('最小化导出设置'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      final left = columnWidth(tester, 0), right = columnWidth(tester, 1);
      expect(left, inExclusiveRange(railPanelWidth, 300));
      expect(right, inExclusiveRange(railPanelWidth, 340));
      await tester.pumpAndSettle();
      expect(columnWidth(tester, 0), closeTo(railPanelWidth, .01));
      expect(columnWidth(tester, 1), closeTo(railPanelWidth, .01));
      await tester.tap(find.byTooltip('展开网页文件'));
      await tester.tap(find.byTooltip('展开导出设置'));
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.pumpAndSettle();
      expect(columnWidth(tester, 0), closeTo(300, .01));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('settings JSON keeps the panel layout', (tester) async {
    final settings = AppSettings()
      ..queueCollapsed = true
      ..settingsCollapsed = true;
    final copy = AppSettings.fromJson(settings.toJson());
    expect(copy.queueCollapsed, isTrue);
    expect(copy.settingsCollapsed, isTrue);
    expect(AppSettings.fromJson({}).queueCollapsed, isFalse);
  });

  testWidgets('progress and loading indicators use the design sizes', (
    tester,
  ) async {
    late StateSetter rebuild;
    double? value = .4;
    var wavy = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return Column(
                children: [
                  ReferenceLinearProgress(value: value, wavy: wavy),
                  const ReferenceLoadingIndicator(size: 64, contained: true),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.getSize(find.byType(ReferenceLinearProgress)).height, 12);
    expect(
      tester.getSize(find.byType(ReferenceLoadingIndicator)),
      const Size(64, 64),
    );
    rebuild(() => wavy = false);
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.getSize(find.byType(ReferenceLinearProgress)).height, 4);
    rebuild(() => value = null);
    await tester.pump(const Duration(milliseconds: 800));
    expect(tester.getSize(find.byType(ReferenceLinearProgress)).height, 4);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
