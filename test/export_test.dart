import 'dart:convert';
import 'dart:io';

import 'package:canvas_quiz_exporter/domain/exporter.dart';
import 'package:canvas_quiz_exporter/domain/models.dart';
import 'package:canvas_quiz_exporter/domain/parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Pdfrx.cacheDirectoryPath = Directory.systemTemp.path;
  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('canvas-export-'));
  tearDown(() => root.deleteSync(recursive: true));
  AppSettings settings() => AppSettings()
    ..formats = exportFormats.toSet()
    ..customOutput = true
    ..outputPath = p.join(root.path, 'out')
    ..nameTemplate = 'practice';

  test('all formats share filters and preserve Unicode, PDF text and embedded images', () async {
    await pdfrxFlutterInitialize();
    final source = writeQuiz(
      root,
      'quiz.html',
      quizHtml(
        text: 'REMOVE_THIS Calculate 12 V / 6 Ω = _____ A.',
        image: '<img src="data:image/png;base64,$pixel" alt="Diagram">',
      ),
    );
    final cfg = settings()..filters = 'remove_this';
    final result = await exportQuiz(source.path, cfg, testFonts());
    expect(result.errors, isEmpty);
    expect(result.files.length, 6);
    for (final path in result.files.where(
      (f) => ['.txt', '.md', '.json', '.jsonl'].contains(p.extension(f)),
    )) {
      final text = File(path).readAsStringSync();
      expect(text, isNot(contains('REMOVE_THIS')));
      expect(text, contains('6 Ω'));
    }
    final json = jsonDecode(
      File(p.join(cfg.outputPath, 'practice.json')).readAsStringSync(),
    ) as Map;
    expect((json['questions'] as List).length, 1);
    expect(json.containsKey('diagnostics'), isFalse);
    final im = json['questions'][0]['question_images'][0]['path'] as String;
    expect(File(p.join(cfg.outputPath, im)).existsSync(), isTrue);
    final pdf = await PdfDocument.openFile(
      p.join(cfg.outputPath, 'practice.pdf'),
    );
    try {
      expect(pdf.pages.first.width, closeTo(612, .1));
      final text = (await pdf.pages.first.loadText())!.fullText;
      expect(text, contains('12 V'));
      expect(text, contains('6 Ω'));
      expect(text, isNot(contains('REMOVE_THIS')));
      final image = await pdf.pages.first.render(
        fullWidth: 306,
        fullHeight: 396,
      );
      expect(image, isNotNull);
      image!.dispose();
    } finally {
      await pdf.dispose();
    }
  });
  test(
    'PDF embeds Chinese primary and Roboto Flex fallback in both weights',
    () async {
      await pdfrxFlutterInitialize();
      const mixed = '中文题目 English Ą ć';
      final doc = QuizDocument(
        title: mixed,
        sourcePath: 'synthetic.html',
        sourceHash: '',
        questions: [
          QuizQuestion(number: 1, type: 'essay_question', text: mixed),
        ],
      );
      final bytes = await buildPdf(doc, AppSettings(), testFonts());
      final source = latin1.decode(bytes);
      expect(
        source.contains('/NotoSansSC-Regular'),
        isTrue,
        reason: 'NotoSansSC-Regular must be embedded',
      );
      expect(
        source.contains('/NotoSansSC-Bold'),
        isTrue,
        reason: 'NotoSansSC-Bold must be embedded',
      );
      expect(
        source.contains('/RobotoFlex-Regular'),
        isTrue,
        reason: 'RobotoFlex-Regular must be embedded',
      );
      expect(
        source.contains('/RobotoFlex-Bold'),
        isTrue,
        reason: 'RobotoFlex-Bold must be embedded',
      );
      final pdf = await PdfDocument.openData(bytes);
      try {
        final text = (await pdf.pages.first.loadText())!.fullText;
        expect(text, contains(mixed));
        final image = await pdf.pages.first.render(
          fullWidth: 612,
          fullHeight: 792,
        );
        expect(image, isNotNull);
        image!.dispose();
      } finally {
        await pdf.dispose();
      }
    },
  );

  test('collisions preserve existing content and keep assets linked to the new name', () async {
    final source = writeQuiz(
      root,
      'quiz.html',
      quizHtml(image: '<img src="data:image/png;base64,$pixel" alt="Pixel">'),
    );
    final cfg = settings();
    Directory(cfg.outputPath).createSync();
    final existing = File(p.join(cfg.outputPath, 'practice.json'))
      ..writeAsStringSync('keep');
    final result = await exportQuiz(source.path, cfg, testFonts());
    expect(result.errors, isEmpty);
    expect(existing.readAsStringSync(), 'keep');
    expect(
      result.files.every((f) => p.basename(f).startsWith('practice_2')),
      isTrue,
    );
    expect(
      File(p.join(cfg.outputPath, 'practice_2.md')).readAsStringSync(),
      contains('practice_2_assets/'),
    );
    expect(
      Directory(cfg.outputPath)
          .listSync()
          .where((f) => p.basename(f.path).startsWith('.canvas-export-')),
      isEmpty,
    );
  });
  test('one bad PDF font does not prevent the other formats', () async {
    final source = writeQuiz(root, 'quiz.html', quizHtml());
    final result = await exportQuiz(
      source.path,
      settings()..fontPath = 'not-a-font.ttf',
      testFonts(),
    );
    expect(result.files.length, 4);
    expect(result.errors.length, 1);
    expect(result.errors.single, contains('PDF'));
  });
  test('A4 and custom TTF work, long essays paginate, assets can be omitted', () async {
    await pdfrxFlutterInitialize();
    final source = writeQuiz(
      root,
      'long.html',
      quizHtml(
        type: 'essay_question',
        text: 'Describe the circuit.',
        answers:
            '<textarea>${List.filled(180, 'A long answer must continue onto another page.').join(' ')}</textarea>',
      ),
    );
    final cfg = settings()
      ..paper = 'a4'
      ..fontPath = p.absolute('assets/fonts/roboto-regular.ttf')
      ..copyAssets = false
      ..diagnostics = true;
    final result = await exportQuiz(source.path, cfg, testFonts());
    expect(result.errors, isEmpty);
    final pdf = await PdfDocument.openFile(
      p.join(cfg.outputPath, 'practice.pdf'),
    );
    try {
      expect(pdf.pages.length, greaterThan(1));
      expect(pdf.pages.first.width, closeTo(595.28, .1));
      expect(
        (await pdf.pages.last.loadText())!.fullText,
        contains('another page.'),
      );
    } finally {
      await pdf.dispose();
    }
    expect(
      jsonDecode(
        File(p.join(cfg.outputPath, 'practice.json')).readAsStringSync(),
      )['diagnostics'],
      isNotNull,
    );
    expect(result.files.any((f) => f.endsWith('_assets')), isFalse);
  });
  test('filename variables and invalid settings are explicit', () async {
    expect(safeFilename('CON.txt'), '_CON.txt');
    expect(safeFilename('a/b:c?'), 'a_b_c_');
    expect(
      () => (AppSettings()..nameTemplate = '{unknown}').validate(),
      throwsFormatException,
    );
    expect(
      () => (AppSettings()..formats.clear()).validate(),
      throwsFormatException,
    );
    final source = writeQuiz(root, 'quiz.html', quizHtml());
    final cfg = settings()
      ..formats = {'txt'}
      ..nameTemplate = '{source_name}_{index}_{hash8}_{version}';
    final result = await exportQuiz(source.path, cfg, testFonts(), index: 3);
    expect(
      p.basename(result.files.single),
      'quiz_3_${parseQuiz(source.path).sourceHash}_$appVersion.txt',
    );
  });
}
