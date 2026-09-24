import 'dart:convert';

import 'package:canvas_quiz_exporter/domain/models.dart';
import 'package:canvas_quiz_exporter/l10n/localizations.dart';
import 'package:canvas_quiz_exporter/ui/app_theme.dart';
import 'package:canvas_quiz_exporter/ui/question_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  String? copied;
  setUp(() {
    copied = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          if (call.method == 'Clipboard.getData') return {'text': copied};
          return null;
        });
  });

  Future<void> show(WidgetTester tester, QuizQuestion question) =>
      tester.pumpWidget(
        MaterialApp(
          theme: appTheme(false, 'violet'),
          locale: const Locale('zh'),
          supportedLocales: supportedLocales,
          localizationsDelegates: localizationsDelegates,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 344,
                child: QuestionCard(
                  question: question,
                  reducedMotion: false,
                  notify: (_, {error = false}) {},
                ),
              ),
            ),
          ),
        ),
      );

  testWidgets('question text stays selectable while card whitespace copies', (
    tester,
  ) async {
    final question = QuizQuestion(
      number: 1,
      type: 'multiple_choice_question',
      text: 'Which statement is correct?',
      options: [
        QuizOption('The first statement.', selected: true, correct: true),
      ],
    );
    await show(tester, question);
    await tester.pumpAndSettle();
    await tester.tap(find.text(question.text));
    await tester.pump();
    expect(copied, isNull);
    await tester.tapAt(
      tester.getTopLeft(find.byType(QuestionCard)) + const Offset(10, 50),
    );
    await tester.pumpAndSettle();
    expect(copied, question.plainText());
    expect(find.text('已复制'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'option backgrounds distinguish selected, correct, both and neutral states',
    (tester) async {
      final cs = appTheme(false, 'violet').colorScheme;
      final options = [
        QuizOption('Selected answer', selected: true),
        QuizOption('Correct answer', correct: true),
        QuizOption('Both markers', selected: true, correct: true),
        QuizOption('Unmarked answer'),
      ];
      await show(
        tester,
        QuizQuestion(
          number: 3,
          type: 'multiple_answers_question',
          text: 'Choose the answers.',
          options: options,
        ),
      );
      await tester.pumpAndSettle();
      final backgrounds = [
        cs.secondaryContainer,
        cs.primaryContainer,
        cs.primaryContainer,
        cs.surfaceContainerHighest,
      ];
      final foregrounds = [
        cs.onSecondaryContainer,
        cs.onPrimaryContainer,
        cs.onPrimaryContainer,
        cs.onSurface,
      ];
      for (var i = 0; i < options.length; i++) {
        final text = find.text(options[i].text);
        final container = tester.widget<Container>(
          find
              .ancestor(
                of: text,
                matching: find.byWidgetPredicate(
                  (w) => w is Container && w.decoration is BoxDecoration,
                ),
              )
              .first,
        );
        expect((container.decoration! as BoxDecoration).color, backgrounds[i]);
        expect(tester.widget<EditableText>(text).style.color, foregrounds[i]);
      }
      expect(find.text('已选'), findsOneWidget);
      expect(find.text('正确'), findsOneWidget);
      expect(find.text('已选 · 正确'), findsOneWidget);
      expect(find.text('多选题'), findsOneWidget);
    },
  );

  testWidgets('images open in a viewer that fits short windows', (
    tester,
  ) async {
    await show(
      tester,
      QuizQuestion(
        number: 4,
        type: 'essay_question',
        text: 'Describe the figures.',
        images: [
          QuizImage(
            alt: 'Figure 1',
            key: 'figure.png',
            bytes: base64Decode(pixel),
            width: 4,
            height: 4,
          ),
          const QuizImage(alt: 'Remote figure'),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Figure 1 · 本地资源'), findsOneWidget);
    expect(find.text('Remote figure'), findsOneWidget);
    expect(find.text('网络图片 · 无本地副本'), findsOneWidget);
    await tester.tap(find.byTooltip('查看完整图片'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.textContaining('4 × 4 · 滚轮或手势缩放'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
  });

  testWidgets('matching written answer is shown once using the correct state', (
    tester,
  ) async {
    await show(
      tester,
      QuizQuestion(
        number: 2,
        type: 'numerical_question',
        text: 'The current is ___ A.',
        userAnswer: '2',
        correctAnswer: '2',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('作答 · 正确'), findsOneWidget);
    expect(find.text('正确答案'), findsNothing);
    expect(find.text('2'), findsOneWidget);
    final primaryContainer = appTheme(
      false,
      'violet',
    ).colorScheme.primaryContainer;
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).color == primaryContainer,
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
