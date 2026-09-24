import 'dart:convert';
import 'dart:io';

import 'package:canvas_quiz_exporter/domain/models.dart';
import 'package:canvas_quiz_exporter/domain/parser.dart';
import 'package:canvas_quiz_exporter/l10n/localizations.dart';
import 'package:canvas_quiz_exporter/main.dart';
import 'package:canvas_quiz_exporter/services/app_controller.dart';
import 'package:canvas_quiz_exporter/services/settings_store.dart';
import 'package:canvas_quiz_exporter/ui/app_theme.dart';
import 'package:canvas_quiz_exporter/ui/question_card.dart';
import 'package:canvas_quiz_exporter/ui/settings_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support.dart';

final _chinese = RegExp(r'[\u3000-\u303f\u4e00-\u9fff\uff00-\uffef]');

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Measure text with the bundled fonts: the square test font makes Latin
    // text about twice as wide as it really is.
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final family in manifest) {
      final loader = FontLoader(family['family'] as String);
      for (final font in family['fonts'] as List) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
  });

  test('the language setting resolves against the system language', () {
    expect(Strings.resolve('system', 'zh'), 'zh');
    expect(Strings.resolve('system', 'en'), 'en');
    expect(Strings.resolve('system', 'ja'), 'en');
    expect(Strings.resolve('en', 'zh'), 'en');
    expect(Strings.resolve('zh', 'fr'), 'zh');
  });

  test('settings keep the language; older settings stay in Chinese', () {
    expect(AppSettings().language, 'system');
    expect(AppSettings.fromJson({}).language, 'zh');
    expect(AppSettings.fromJson({'language': 'en'}).language, 'en');
    expect(AppSettings.fromJson({'language': 'fr'}).language, 'system');
    expect((AppSettings()..language = 'en').snapshot().language, 'en');
  });

  test('English counts and summaries read naturally', () {
    expect(Strings.english.questions(1), '1 question');
    expect(Strings.english.questions(3), '3 questions');
    expect(Strings.chinese.questions(3), '3 道题');
    expect(
      Strings.english.exportSummary(
        outcome: Strings.english.exportCancelled,
        itemCount: 1,
        seconds: '0.4',
        failures: 1,
        done: 1,
        total: 3,
        cancelled: true,
      ),
      'Cancelled · 1 item · 0.4 s · 1 failed · 1/3 processed',
    );
  });

  test('reading and settings errors use the requested language', () {
    final root = Directory.systemTemp.createTempSync('canvas-l10n-');
    addTearDown(() => root.deleteSync(recursive: true));
    final empty = writeQuiz(root, 'empty.html', '<html><body></body></html>');
    String error(Strings strings) {
      try {
        parseQuiz(empty.path, strings: strings);
      } on FormatException catch (e) {
        return e.message;
      }
      fail('No error');
    }

    expect(error(Strings.english), startsWith('No questions were found.'));
    expect(error(Strings.chinese), startsWith('网页中没有可识别的题目。'));
    expect(
      () => (AppSettings()..formats.clear()).validate(Strings.english),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          'Choose at least one export format.',
        ),
      ),
    );
  });

  testWidgets('English question cards fit and label everything in English', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(false, 'violet'),
        locale: const Locale('en'),
        supportedLocales: supportedLocales,
        localizationsDelegates: localizationsDelegates,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 344,
              child: QuestionCard(
                question: QuizQuestion(
                  number: 5,
                  type: 'multiple_answers_question',
                  text: 'Choose the answers.',
                  options: [
                    QuizOption('Both markers', selected: true, correct: true),
                  ],
                  images: [
                    QuizImage(
                      alt: 'Figure 1',
                      key: 'figure.png',
                      bytes: base64Decode(pixel),
                      width: 4,
                      height: 4,
                    ),
                  ],
                  correctAnswer: 'Other',
                ),
                reducedMotion: true,
                notify: (_, {error = false}) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Multiple answers'), findsOneWidget);
    expect(find.text('Selected · Correct'), findsOneWidget);
    // Too narrow for the English markers beside the text: they go under it.
    expect(
      tester.getTopLeft(find.text('Selected · Correct')).dy,
      greaterThan(tester.getBottomLeft(find.text('Both markers')).dy),
    );
    expect(find.text('Figure 1 · local file'), findsOneWidget);
    expect(find.text('Correct answer'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.byTooltip('View full image'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('English interface', () {
    late Directory root;
    late AppController c;
    setUp(() {
      root = Directory.systemTemp.createTempSync('canvas-english-');
      c = AppController(
        store: SettingsStore(path: p.join(root.path, 'settings.json')),
        fonts: testFonts(),
      );
      c.settings
        ..language = 'en'
        ..reducedMotion = true;
    });
    tearDown(() {
      c.dispose();
      root.deleteSync(recursive: true);
    });

    Future<void> show(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1080, 720);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(CanvasApp(controller: c, nativeWindow: false));
      await tester.pumpAndSettle();
    }

    void expectEnglish(WidgetTester tester, String screen) {
      final labels = [
        for (final text in tester.widgetList<RichText>(find.byType(RichText)))
          text.text.toPlainText(),
        for (final tip in tester.widgetList<Tooltip>(find.byType(Tooltip)))
          tip.message ?? '',
      ];
      for (final label in labels) {
        expect(_chinese.hasMatch(label), isFalse, reason: '$screen: $label');
      }
      expect(tester.takeException(), isNull, reason: screen);
    }

    testWidgets('every screen is English and fits the minimum window', (
      tester,
    ) async {
      await show(tester);
      expectEnglish(tester, 'empty workspace');

      final entry = QueueEntry(p.absolute('assets/demo.html'))
        ..document = parseQuiz('assets/demo.html');
      c.entries.add(entry);
      c.current = entry;
      c.changed();
      await tester.pumpAndSettle();
      expect(find.text('Add pages'), findsOneWidget);
      expect(find.text('Multiple choice'), findsOneWidget);
      expectEnglish(tester, 'preview');

      final settings = find
          .descendant(
            of: find.byType(SettingsPanel),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Custom folder'),
        120,
        scrollable: settings,
      );
      await tester.tap(find.text('Custom folder'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('advanced-options')),
        120,
        scrollable: settings,
      );
      await tester.tap(find.byKey(const ValueKey('advanced-options')));
      await tester.pumpAndSettle();
      expectEnglish(tester, 'settings');
      await tester.scrollUntilVisible(
        find.text('Reduce motion'),
        120,
        scrollable: settings,
      );
      expectEnglish(tester, 'advanced settings');

      await tester.tap(find.text('PDF pages'));
      await tester.pump();
      expectEnglish(tester, 'PDF preview');
      await tester.tap(find.text('Overview'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Minimize pages'));
      await tester.tap(find.byTooltip('Minimize export settings'));
      await tester.pumpAndSettle();
      expectEnglish(tester, 'collapsed panels');
      await tester.tap(find.byTooltip('Expand pages'));
      await tester.tap(find.byTooltip('Expand export settings'));
      await tester.pumpAndSettle();

      c.results.addAll([
        p.join(root.path, 'Circuit fundamentals.txt'),
        p.join(root.path, 'Circuit fundamentals_assets'),
      ]);
      c.logs.add(Strings.english.wrote(c.results.first));
      c.status = Strings.english.exportDone;
      c.resultsOpen = true;
      c.changed();
      await tester.pumpAndSettle();
      expect(find.text('Assets'), findsOneWidget);
      expectEnglish(tester, 'export results');

      await tester.tap(find.text('View log'));
      await tester.pumpAndSettle();
      expectEnglish(tester, 'export log');
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Help · F1'));
      await tester.pumpAndSettle();
      expectEnglish(tester, 'help');
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the header menu switches the language live and saves it', (
      tester,
    ) async {
      await show(tester);
      expect(find.text('Add your first page'), findsOneWidget);
      BuildContext context() => tester.element(find.byType(Scaffold).first);
      expect(MaterialLocalizations.of(context()).copyButtonLabel, 'Copy');

      await tester.tap(find.byKey(const ValueKey('language-menu')));
      await tester.pumpAndSettle();
      expect(find.text('System default'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('language-zh')));
      await tester.pumpAndSettle();
      expect(find.text('添加第一个网页'), findsOneWidget);
      expect(find.byTooltip('语言'), findsOneWidget);
      expect(MaterialLocalizations.of(context()).copyButtonLabel, '复制');
      expect(c.store.load().language, 'zh');

      await tester.tap(find.byKey(const ValueKey('language-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('language-system')));
      await tester.pumpAndSettle();
      // flutter_test reports an English (US) system.
      expect(find.text('Add your first page'), findsOneWidget);
      expect(c.store.load().language, 'system');
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('switching language rewords warnings of pages already read', (
      tester,
    ) async {
      final page = writeQuiz(
        root,
        'quiz.html',
        quizHtml(image: '<img src="missing.png" alt="Diagram">'),
      );
      await show(tester);
      await tester.runAsync(() => c.addPaths([page.path]));
      await tester.pumpAndSettle();
      expect(
        find.text('1 image has no local copy; its description was kept.'),
        findsOneWidget,
      );

      await tester.runAsync(() async {
        c.setLanguage('zh');
        while (c.entries.single.parsing) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();
      expect(find.text('1 张图片没有可用的本地副本，已保留文字说明。'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
