import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../l10n/strings.dart';
import 'models.dart';
import 'parser.dart';

class PdfFonts {
  final Uint8List regular, bold, fallbackRegular, fallbackBold;
  const PdfFonts(
    this.regular,
    this.bold,
    this.fallbackRegular,
    this.fallbackBold,
  );
}

String safeFilename(String value) {
  var name = value
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceAll(RegExp(r'[. ]+$'), '');
  if (name.isEmpty) name = 'Canvas Quiz';
  if (RegExp(
    r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)',
    caseSensitive: false,
  ).hasMatch(name)) {
    name = '_$name';
  }
  return String.fromCharCodes(name.runes.take(120));
}

String _baseName(QuizDocument doc, AppSettings cfg, int index) {
  final values = {
    'safe_quiz_title': safeFilename(doc.title),
    'quiz_title': doc.title,
    'date': DateTime.now().toIso8601String().substring(0, 10),
    'course': doc.course,
    'source_name': p.basenameWithoutExtension(doc.sourcePath),
    'index': '$index',
    'hash8': doc.sourceHash,
    'version': appVersion,
  };
  return safeFilename(
    cfg.nameTemplate.replaceAllMapped(
      RegExp(r'\{([^{}]+)\}'),
      (m) => values[m[1]]!,
    ),
  );
}

String _markdown(String text) =>
    text.replaceAllMapped(RegExp(r'[\\`*_{}\[\]<>#|]'), (m) => '\\${m[0]}');

String markdownExport(QuizDocument doc, String? assetsPrefix) {
  final out = StringBuffer('# ${_markdown(doc.title)}\n\n');
  if (doc.course.isNotEmpty) out.writeln('${_markdown(doc.course)}\n');
  out.writeln('${doc.questions.length} questions\n');
  void images(List<QuizImage> list) {
    for (final image in list) {
      if (image.available && assetsPrefix != null) {
        out.writeln(
          '![${_markdown(image.alt)}](<${Uri.encodeFull('$assetsPrefix/${image.key}')}>)\n',
        );
      } else {
        out.writeln(
          '[${image.available ? 'Image not included' : 'Missing image'}: ${_markdown(image.alt)}]\n',
        );
      }
    }
  }

  for (final q in doc.questions) {
    out.writeln('## ${q.number} · ${q.typeLabel}\n\n${_markdown(q.text)}\n');
    images(q.images);
    for (var i = 0; i < q.options.length; i++) {
      final o = q.options[i];
      out.writeln(
        '${optionLabel(i)}. ${_markdown(o.text)}${o.selected ? ' **[Selected]**' : ''}${o.correct ? ' **[Correct]**' : ''}\n',
      );
      images(o.images);
    }
    if (q.userAnswer != null) {
      out.writeln('Your answer: ${_markdown(q.userAnswer!)}\n');
    }
    if (q.correctAnswer != null) {
      out.writeln('Correct answer: ${_markdown(q.correctAnswer!)}\n');
    }
  }
  if (doc.warnings.isNotEmpty) {
    out.writeln(
      '## Export notes\n\n${doc.warnings.map(_markdown).join('\n\n')}\n',
    );
  }
  return out.toString();
}

/// The PDF tab and disk export call this same function with the same settings.
Future<Uint8List> buildPdf(
  QuizDocument doc,
  AppSettings cfg,
  PdfFonts fonts, {
  Strings strings = Strings.english,
}) async {
  final noto = pw.Font.ttf(ByteData.sublistView(fonts.regular));
  final notoBold = pw.Font.ttf(ByteData.sublistView(fonts.bold));
  final flex = pw.Font.ttf(ByteData.sublistView(fonts.fallbackRegular));
  final flexBold = pw.Font.ttf(ByteData.sublistView(fonts.fallbackBold));
  pw.Font regular = noto, bold = notoBold;
  final fallback = <pw.Font>[flex];
  final boldFallback = <pw.Font>[flexBold];
  if (cfg.fontPath.trim().isNotEmpty) {
    final file = File(cfg.fontPath.trim());
    if (!file.existsSync()) throw FormatException(strings.customFontMissing);
    if (file.lengthSync() > maxFileBytes) {
      throw FormatException(strings.fontTooLarge);
    }
    final bytes = file.readAsBytesSync();
    try {
      regular = pw.Font.ttf(ByteData.sublistView(bytes));
      bold = regular;
      fallback.insert(0, noto);
      boldFallback.insert(0, notoBold);
    } on Object {
      throw FormatException(strings.fontUnreadable);
    }
  }
  final pdf = pw.Document(
    title: doc.title,
    author: 'Canvas Quiz Exporter',
    creator: 'Canvas Quiz Exporter $appVersion',
  );
  final style = pw.TextStyle(
    font: regular,
    fontBold: bold,
    fontFallback: fallback,
    fontSize: 10.5,
    lineSpacing: 3,
    color: PdfColor.fromHex('#25242B'),
  );
  final boldStyle = style.copyWith(
    fontWeight: pw.FontWeight.bold,
    fontFallback: boldFallback,
  );
  final heading = boldStyle.copyWith(fontSize: 12);
  final content = <pw.Widget>[];
  void text(String value, {pw.TextStyle? custom}) {
    // Bounded paragraphs can flow even when an essay exceeds a whole page.
    for (final line in value.split('\n')) {
      var remaining = line;
      while (remaining.isNotEmpty) {
        var end = math.min(1200, remaining.length);
        if (end < remaining.length) {
          final space = remaining.lastIndexOf(' ', end);
          if (space > 600) end = space;
        }
        content.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 5),
            child: pw.Text(remaining.substring(0, end), style: custom ?? style),
          ),
        );
        remaining = remaining.substring(end).trimLeft();
      }
    }
  }

  void images(List<QuizImage> list) {
    for (final image in list) {
      if (image.available) {
        content.add(
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            child: pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Image(
                pw.MemoryImage(image.bytes!),
                width: math.min(480, image.width.toDouble()),
                height: math.min(230, image.height.toDouble()),
                fit: pw.BoxFit.contain,
              ),
            ),
          ),
        );
      } else {
        text(
          '[Missing local image: ${image.alt}]',
          custom: style.copyWith(color: PdfColors.grey600, fontSize: 9),
        );
      }
    }
  }

  text(doc.title, custom: heading.copyWith(fontSize: 22));
  text(
    [
      doc.course,
      '${doc.questions.length} questions',
      DateTime.now().toIso8601String().substring(0, 10),
    ].where((s) => s.isNotEmpty).join(' · '),
    custom: style.copyWith(fontSize: 9, color: PdfColors.grey600),
  );
  content.add(pw.SizedBox(height: 12));
  for (final q in doc.questions) {
    text('Question ${q.number} · ${q.typeLabel}', custom: heading);
    text(q.text);
    images(q.images);
    for (var i = 0; i < q.options.length; i++) {
      final o = q.options[i];
      final marks = [if (o.selected) 'Selected', if (o.correct) 'Correct'];
      text(
        '${optionLabel(i)}) ${o.text}${marks.isNotEmpty ? ' [${marks.join(' · ')}]' : ''}',
        custom: o.correct ? boldStyle : style,
      );
      images(o.images);
    }
    final selected = q.options
            .where((o) => o.selected)
            .map((o) => o.text)
            .join(', '),
        correct = q.options
            .where((o) => o.correct)
            .map((o) => o.text)
            .join(', ');
    if (q.userAnswer != null && q.userAnswer != selected) {
      text('Your answer: ${q.userAnswer}');
    }
    if (q.correctAnswer != null && q.correctAnswer != correct) {
      text('Correct answer: ${q.correctAnswer}', custom: boldStyle);
    }
    content.add(pw.SizedBox(height: 14));
  }
  final missing = doc.images.where((i) => !i.available).length;
  if (missing > 0) {
    text(
      'Export note: $missing image(s) had no readable local copy. Text was preserved.',
      custom: style.copyWith(fontSize: 9, color: PdfColors.grey600),
    );
  }
  pdf.addPage(
    pw.MultiPage(
      pageFormat: cfg.paper == 'a4' ? PdfPageFormat.a4 : PdfPageFormat.letter,
      margin: const pw.EdgeInsets.fromLTRB(42, 42, 42, 38),
      maxPages: 1000,
      theme: pw.ThemeData.withFont(
        base: regular,
        bold: bold,
        fontFallback: fallback,
      ),
      footer: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Canvas Quiz Exporter',
            style: style.copyWith(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            style: style.copyWith(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
      build: (_) => content,
    ),
  );
  return pdf.save();
}

Future<ExportResult> exportQuiz(
  String source,
  AppSettings cfg,
  PdfFonts fonts, {
  int index = 1,
  Strings strings = Strings.english,
}) async {
  cfg.validate(strings);
  final doc = parseQuiz(source, strings: strings).filtered(cfg);
  final directory = Directory(
    p.absolute(cfg.customOutput ? cfg.outputPath.trim() : p.dirname(source)),
  );
  directory.createSync(recursive: true);
  final originalBase = _baseName(doc, cfg, index);
  var base = originalBase;
  var suffix = 1;
  bool collision(String name) =>
      cfg.formats.any(
        (f) =>
            FileSystemEntity.typeSync(p.join(directory.path, '$name.$f')) !=
            FileSystemEntityType.notFound,
      ) ||
      FileSystemEntity.typeSync(p.join(directory.path, '${name}_assets')) !=
          FileSystemEntityType.notFound;
  while (collision(base)) {
    suffix++;
    base = '${originalBase}_$suffix';
  }
  final stage = directory.createTempSync('.canvas-export-');
  final output = <String>[], errors = <String>[];
  final assets = <String, QuizImage>{
    for (final i in doc.images.where((i) => i.available)) i.key: i,
  };
  final prefix = cfg.copyAssets && assets.isNotEmpty ? '${base}_assets' : null;
  try {
    if (prefix != null) {
      final resourceDir = Directory(p.join(stage.path, prefix))..createSync();
      for (final entry in assets.entries) {
        File(p.join(resourceDir.path, entry.key))
            .writeAsBytesSync(entry.value.bytes!, flush: true);
      }
    }
    final completed = <File>[];
    for (final format in exportFormats.where(cfg.formats.contains)) {
      final file = File(p.join(stage.path, '$base.$format'));
      try {
        switch (format) {
          case 'pdf':
            file.writeAsBytesSync(
              await buildPdf(doc, cfg, fonts, strings: strings),
              flush: true,
            );
          case 'txt':
            var text = doc.plainText();
            if (prefix != null) {
              text +=
                  '\n\nLocal images: $prefix/\n${assets.keys.map((k) => '$prefix/$k').join('\n')}';
            }
            file.writeAsStringSync('$text\n', flush: true);
          case 'md':
            file.writeAsStringSync(markdownExport(doc, prefix), flush: true);
          case 'json':
            file.writeAsStringSync(
              '${doc.toJsonText(assetsPrefix: prefix, includeDiagnostics: cfg.diagnostics)}\n',
              flush: true,
            );
          case 'jsonl':
            file.writeAsStringSync(
              '${doc.questions.map((q) => jsonEncode({
                'meta': {'schema_version': '2.0', 'title': doc.title, 'course': doc.course, if (cfg.diagnostics) 'diagnostics': doc.diagnostics},
                'question': q.toJson(prefix),
              })).join('\n')}\n',
              flush: true,
            );
        }
        completed.add(file);
      } on Object catch (e) {
        errors.add('${p.basename(source)} · ${format.toUpperCase()}: $e');
      }
    }
    if (completed.isNotEmpty) {
      if (prefix != null) {
        final target = p.join(directory.path, prefix);
        if (FileSystemEntity.typeSync(target) !=
            FileSystemEntityType.notFound) {
          throw FileSystemException(strings.assetsFolderAppeared);
        }
        Directory(p.join(stage.path, prefix)).renameSync(target);
        output.add(target);
      }
      for (final file in completed) {
        final target = File(p.join(directory.path, p.basename(file.path)));
        // Exclusive creation prevents concurrent exports from overwriting data.
        target.createSync(exclusive: true);
        try {
          target.writeAsBytesSync(file.readAsBytesSync(), flush: true);
        } on Object {
          target.deleteSync();
          rethrow;
        }
        output.add(target.path);
      }
    }
  } on Object catch (e) {
    errors.add(strings.saveFailed(p.basename(source), e));
  } finally {
    if (stage.existsSync()) stage.deleteSync(recursive: true);
  }
  return ExportResult(
    files: output,
    errors: errors,
    warnings: doc.warnings,
    questionCount: output.isEmpty ? 0 : doc.questions.length,
  );
}
