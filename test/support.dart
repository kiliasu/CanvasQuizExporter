import 'dart:io';

import 'package:canvas_quiz_exporter/domain/exporter.dart';
import 'package:path/path.dart' as p;

PdfFonts testFonts() => PdfFonts(
  File('assets/fonts/pdf/noto-sans-sc-regular.ttf').readAsBytesSync(),
  File('assets/fonts/pdf/noto-sans-sc-bold.ttf').readAsBytesSync(),
  File('assets/fonts/pdf/roboto-flex-regular.ttf').readAsBytesSync(),
  File('assets/fonts/pdf/roboto-flex-bold.ttf').readAsBytesSync(),
);
String quizHtml({
  String text = 'Choose the even number.',
  String image = '',
  String type = 'multiple_choice_question',
  String? answers,
}) =>
    '''<!doctype html><html><title>Quiz: Synthetic practice</title><body>
<div class="question $type"><span class="question_name">Question 1</span><span class="question_type">$type</span>
<div class="question_text">$text$image</div><div class="answers">${answers ?? '<div class="answer selected_answer" title="Incorrect answer"><div class="answer_text">Three</div></div><div class="answer correct_answer"><div class="answer_text">Four</div></div>'}</div></div></body></html>''';
File writeQuiz(Directory root, String name, String content) =>
    File(p.join(root.path, name))..writeAsStringSync(content);
// A public, synthetic 4 x 4 PNG. Never read private quiz assets in unit tests.
const pixel =
    'iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAE0lEQVR4nGMUidrCAANMcBZeDgA5CAEqGfKE+AAAAABJRU5ErkJggg==';
