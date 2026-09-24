import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:canvas_quiz_exporter/domain/models.dart';
import 'package:canvas_quiz_exporter/domain/parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support.dart';

/// A junction on Windows (no privileges needed), a symbolic link elsewhere.
void link(String path, String target) {
  if (!Platform.isWindows) return Link(path).createSync(target);
  final result = Process.runSync('cmd', ['/c', 'mklink', '/J', path, target]);
  if (result.exitCode != 0) fail('mklink failed: ${result.stdout}');
}

void main() {
  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('canvas-parser-'));
  tearDown(() => root.deleteSync(recursive: true));

  test('saved selection and published correctness remain separate', () {
    final source = writeQuiz(root, 'quiz.html', quizHtml());
    final q = parseQuiz(source.path).questions.single;
    expect(q.text, 'Choose the even number.');
    expect(q.userAnswer, 'Three');
    expect(q.correctAnswer, 'Four');
    source.writeAsStringSync(
      quizHtml().replaceAll('answer correct_answer', 'answer'),
    );
    expect(parseQuiz(source.path).questions.single.correctAnswer, isNull);
  });
  test(
    'numeric, essay, blanks, and multiple dropdowns retain saved values only',
    () {
      for (final item in [
        ('numerical_question', '<input type="text" value="12.5">', '12.5'),
        (
          'essay_question',
          '<textarea>A complete circuit.</textarea>',
          'A complete circuit.',
        ),
        (
          'short_answer_question',
          '<input type="text" value="I agree">',
          'I agree',
        ),
        ('numerical_question', '<input type="text" value="">', null),
        (
          'essay_question',
          '<div hidden><textarea>Not submitted</textarea></div>',
          null,
        ),
      ]) {
        final file = writeQuiz(
          root,
          'quiz.html',
          quizHtml(type: item.$1, answers: item.$2),
        );
        final q = parseQuiz(file.path).questions.single;
        expect(q.userAnswer, item.$3);
        expect(q.correctAnswer, isNull);
      }
      final file = writeQuiz(
        root,
        'quiz.html',
        quizHtml(
          type: 'multiple_dropdowns_question',
          text: 'A: <select><option>none</option><option selected>Red</option></select> B: <input type="text" value="Blue">',
          answers: '',
        ),
      );
      expect(parseQuiz(file.path).questions.single.userAnswer, 'Red, Blue');
    },
  );
  test(
    'matching includes both sides and does not fabricate missing matches',
    () {
      final source = writeQuiz(
        root,
        'match.html',
        quizHtml(
          type: 'matching_question',
          answers: '''
<div class="answer selected_answer correct_answer"><span class="answer_match_left">France</span><span class="answer_match_right"><select><option>Rome</option><option selected>Paris</option></select></span></div>
<div class="answer"><span class="answer_match_left">Italy</span><span class="answer_match_right"><select><option>Rome</option></select></span></div>''',
        ),
      );
      final q = parseQuiz(source.path).questions.single;
      expect(q.options.first.text, 'France → Paris');
      expect(q.options.last.text, 'Italy → [No saved answer]');
      expect(q.correctAnswer, 'France → Paris');
    },
  );
  test(
    'hidden templates are excluded and tables contain no empty separators',
    () {
      final source = writeQuiz(
        root,
        'quiz.html',
        quizHtml(
          text: '<table><tr><td>Actual content</td><td><img src="missing.png"></td></tr></table>',
          answers: '<div hidden><div class="answer correct_answer"><div class="answer_text">Secret</div></div></div>',
        ),
      );
      final doc = parseQuiz(source.path);
      expect(doc.questions.single.text, 'Actual content');
      expect(doc.questions.single.correctAnswer, isNull);
      expect(doc.warnings, isNotEmpty);
    },
  );
  test('inline and data iframe traverse without running scripts', () {
    final contents = quizHtml();
    for (final frame in [
      '<iframe srcdoc="${const HtmlEscape().convert(contents)}"></iframe>',
      '<iframe src="data:text/html;base64,${base64Encode(utf8.encode(contents))}"></iframe>',
    ]) {
      final source = writeQuiz(root, 'wrapper.html', frame);
      expect(parseQuiz(source.path).questions.length, 1);
      expect(parseQuiz(source.path).diagnostics['iframe_depth'], 1);
    }
  });
  test(
    'renamed wrappers resolve original companion ZIP without extracting',
    () {
      final source = writeQuiz(
        root,
        'quiz_cp.html',
        '<iframe id="error-report" src="error.html"></iframe><iframe src="quiz_cp_files/saved_resource.html"></iframe>',
      );
      writeQuiz(root, 'error.html', quizHtml(text: 'Wrong page'));
      final archive = Archive()
        ..addFile(
          ArchiveFile.string('quiz_files/saved_resource.html', quizHtml()),
        );
      File(p.join(root.path, 'quiz_files.zip'))
          .writeAsBytesSync(ZipEncoder().encode(archive));
      final before = root.listSync(recursive: true).length;
      expect(
        parseQuiz(source.path).questions.single.text,
        'Choose the even number.',
      );
      expect(root.listSync(recursive: true).length, before);
    },
  );
  test('unsafe ZIP and unrelated iframes are rejected', () {
    final source = writeQuiz(
      root,
      'quiz.html',
      '<iframe src="missing.html"></iframe>',
    );
    writeQuiz(root, 'unrelated.html', quizHtml());
    expect(() => parseQuiz(source.path), throwsFormatException);
    source.writeAsStringSync(quizHtml());
    final archive = Archive()
      ..addFile(ArchiveFile.string('../outside.html', quizHtml()));
    File(p.join(root.path, 'quiz_files.zip'))
        .writeAsBytesSync(ZipEncoder().encode(archive));
    expect(() => parseQuiz(source.path), throwsFormatException);
  });
  test('pages opened through a junction still read their own images', () {
    // Windows CI keeps its temp folder under an 8.3 short name
    // (C:\Users\RUNNER~1), which resolves to a different path like this.
    final real = Directory(p.join(root.path, 'real'))..createSync();
    Directory(p.join(real.path, 'quiz_files')).createSync();
    File(p.join(real.path, 'quiz_files', 'pixel.png'))
        .writeAsBytesSync(base64Decode(pixel));
    writeQuiz(
      real,
      'quiz.html',
      quizHtml(image: '<img src="quiz_files/pixel.png" alt="Pixel">'),
    );
    final linked = p.join(root.path, 'linked');
    link(linked, real.path);
    final doc = parseQuiz(p.join(linked, 'quiz.html'));
    expect(doc.questions, hasLength(1));
    expect(doc.images.single.available, isTrue);
  });
  test('a junction out of the page folder does not expose files', () {
    final outside = Directory(p.join(root.path, 'outside'))..createSync();
    File(p.join(outside.path, 'pixel.png'))
        .writeAsBytesSync(base64Decode(pixel));
    final page = Directory(p.join(root.path, 'page'))..createSync();
    link(p.join(page.path, 'quiz_files'), outside.path);
    final source = writeQuiz(
      page,
      'quiz.html',
      quizHtml(image: '<img src="quiz_files/pixel.png" alt="Pixel">'),
    );
    expect(parseQuiz(source.path).images.single.available, isFalse);
  });
  test('folder expansion skips companion pages and deduplicates inputs', () {
    final source = writeQuiz(root, 'quiz.HTML', quizHtml());
    final resources = Directory(p.join(root.path, 'quiz_files'))..createSync();
    writeQuiz(resources, 'resource.html', '<html></html>');
    expect(expandInputs([root.path, source.path]), [source.path]);
  });
  test('images normalize locally; remote URLs and identities do not leak', () {
    final source = writeQuiz(
      root,
      'quiz.html',
      quizHtml(
        text: 'Li sees Light and Lithium. student@example.invalid <script>{"current_user":{"display_name":"Li"}}</script>',
        image:
            '<img src="data:image/png;base64,$pixel" alt="Pixel"><img src="https://example.invalid/private.png?token=secret" alt="Remote">',
      ),
    );
    final doc = parseQuiz(source.path);
    expect(doc.images.first.available, isTrue);
    expect(doc.images.last.available, isFalse);
    final json = doc.toJsonText();
    expect(json, contains('Light and Lithium.'));
    expect(json, contains('[REDACTED] sees'));
    for (final text in [
      'student@example.invalid',
      'token=secret',
      'data:image',
      root.path,
    ]) {
      expect(json, isNot(contains(text)));
    }
  });
  test('filters are literal, case insensitive, and repeat counts use distinct questions', () {
    final source = writeQuiz(
      root,
      'quiz.html',
      quizHtml(text: 'Repeat this sentence. [A+B] and [a+b].'),
    );
    final doc = parseQuiz(source.path);
    final filtered = doc.filtered(
      AppSettings()..filters = '[a+b]\nREPEAT THIS SENTENCE.',
    );
    expect(filtered.questions.single.text, 'and .');
    final repeated = QuizDocument(
      title: 'Demo',
      sourcePath: '',
      sourceHash: '',
      questions: [doc.questions.single, doc.questions.single],
    );
    expect(repeatedSentences(repeated).first.count, 2);
  });
}
