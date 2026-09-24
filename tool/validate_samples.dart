import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:canvas_quiz_exporter/domain/parser.dart';
import 'package:canvas_quiz_exporter/domain/models.dart';
import 'package:canvas_quiz_exporter/domain/exporter.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('Usage: dart run tool/validate_samples.dart INPUT OUTPUT');
    exitCode = 2;
    return;
  }
  final out = Directory(args[1])..createSync(recursive: true);
  final fonts = PdfFonts(
    File('assets/fonts/pdf/noto-sans-sc-regular.ttf').readAsBytesSync(),
    File('assets/fonts/pdf/noto-sans-sc-bold.ttf').readAsBytesSync(),
    File('assets/fonts/pdf/roboto-flex-regular.ttf').readAsBytesSync(),
    File('assets/fonts/pdf/roboto-flex-bold.ttf').readAsBytesSync(),
  );
  final rows = <Map<String, dynamic>>[];
  for (final path in expandInputs([args[0]])) {
    try {
      final doc = parseQuiz(path);
      final cfg = AppSettings()
        ..formats = exportFormats.toSet()
        ..customOutput = true
        ..outputPath = out.path;
      final result = await exportQuiz(path, cfg, fonts);
      final row = <String, dynamic>{
        'file': p.basename(path),
        'questions': doc.questions.length,
        'options': doc.questions.fold<int>(0, (n, q) => n + q.options.length),
        'selected': doc.questions.where((q) => q.userAnswer != null).length,
        'correct': doc.questions.where((q) => q.correctAnswer != null).length,
        'local_images': doc.images.where((i) => i.available).length,
        'missing_images': doc.images.where((i) => !i.available).length,
        'outputs': result.files.map(p.basename).toList(),
        'errors': result.errors,
      };
      rows.add(row);
      stdout.writeln(jsonEncode(row));
      if (result.errors.isNotEmpty) exitCode = 1;
    } on Object catch (e, st) {
      rows.add({'file': p.basename(path), 'error': e.toString()});
      stderr.writeln('$e\n$st');
      exitCode = 1;
    }
  }
  File(p.join(out.path, 'validation.json'))
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(rows));
}
