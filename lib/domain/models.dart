import 'dart:convert';
import 'dart:typed_data';

import '../l10n/strings.dart';

const appVersion = '2.1.0';
const exportFormats = ['txt', 'pdf', 'md', 'json', 'jsonl'];
const nameVariables = [
  'safe_quiz_title',
  'quiz_title',
  'date',
  'course',
  'index',
  'hash8',
  'version',
  'source_name',
];

class AppSettings {
  Set<String> formats = {'txt'};
  bool customOutput = false;
  String outputPath = '';
  bool copyAssets = true;
  String filters = '';
  String nameTemplate = '{safe_quiz_title}_{date}';
  String paper = 'letter';
  String fontPath = '';
  bool diagnostics = false;
  bool openOnFinish = false;
  bool reducedMotion = false;
  bool dark = false;
  String scheme = 'violet';
  bool queueCollapsed = false;
  bool settingsCollapsed = false;

  /// `system`, `zh` or `en`.
  String language = 'system';
  AppSettings();
  AppSettings.fromJson(Map<String, dynamic> m) {
    if (m['formats'] is List) {
      formats = (m['formats'] as List)
          .whereType<String>()
          .where(exportFormats.contains)
          .toSet();
    }
    customOutput = m['customOutput'] == true;
    outputPath = m['outputPath'] as String? ?? '';
    copyAssets = m['copyAssets'] != false;
    filters = m['filters'] as String? ?? '';
    nameTemplate = m['nameTemplate'] as String? ?? nameTemplate;
    paper = m['paper'] == 'a4' ? 'a4' : 'letter';
    fontPath = m['fontPath'] as String? ?? '';
    diagnostics = m['diagnostics'] == true;
    openOnFinish = m['openOnFinish'] == true;
    reducedMotion = m['reducedMotion'] == true;
    dark = m['dark'] == true;
    final color = m['scheme'] as String? ?? 'violet';
    scheme =
        ['violet', 'blue', 'teal', 'green', 'rose', 'amber'].contains(color)
        ? color
        : 'violet';
    queueCollapsed = m['queueCollapsed'] == true;
    settingsCollapsed = m['settingsCollapsed'] == true;
    // Settings saved before 2.1.0 come from the Chinese-only interface.
    final lang = m['language'] ?? 'zh';
    language = const ['system', 'zh', 'en'].contains(lang)
        ? lang as String
        : 'system';
  }
  Map<String, dynamic> toJson() => {
    'formats': formats.toList(),
    'customOutput': customOutput,
    'outputPath': outputPath,
    'copyAssets': copyAssets,
    'filters': filters,
    'nameTemplate': nameTemplate,
    'paper': paper,
    'fontPath': fontPath,
    'diagnostics': diagnostics,
    'openOnFinish': openOnFinish,
    'reducedMotion': reducedMotion,
    'dark': dark,
    'scheme': scheme,
    'queueCollapsed': queueCollapsed,
    'settingsCollapsed': settingsCollapsed,
    'language': language,
  };
  AppSettings snapshot() => AppSettings.fromJson(toJson());
  List<String> get filterLines =>
      filters
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList()
        ..sort((a, b) => b.length.compareTo(a.length));
  void validate([Strings strings = Strings.english]) {
    if (formats.isEmpty) throw FormatException(strings.formatRequired);
    if (customOutput && outputPath.trim().isEmpty) {
      throw FormatException(strings.outputFolderRequired);
    }
    if (nameTemplate.trim().isEmpty) {
      throw FormatException(strings.nameTemplateEmpty);
    }
    for (final match in RegExp(r'\{([^{}]*)\}').allMatches(nameTemplate)) {
      if (!nameVariables.contains(match[1])) {
        throw FormatException(strings.unknownNameVariable(match[0]!));
      }
    }
    if (nameTemplate
        .replaceAll(RegExp(r'\{[^{}]*\}'), '')
        .contains(RegExp(r'[{}]'))) {
      throw FormatException(strings.unbalancedBraces);
    }
  }
}

class QuizImage {
  final String alt, key;
  final Uint8List? bytes;
  final int width, height;
  const QuizImage({
    required this.alt,
    this.key = '',
    this.bytes,
    this.width = 0,
    this.height = 0,
  });
  bool get available => bytes != null;
  QuizImage mapText(String Function(String) f) => QuizImage(
    alt: f(alt),
    key: key,
    bytes: bytes,
    width: width,
    height: height,
  );
  Map<String, dynamic> toJson(String? prefix) => {
    'alt': alt,
    'available': available,
    'path': available && prefix != null ? '$prefix/$key' : null,
  };
}

class QuizOption {
  final String text;
  final bool selected, correct;
  final List<QuizImage> images;
  const QuizOption(
    this.text, {
    this.selected = false,
    this.correct = false,
    this.images = const [],
  });
  QuizOption mapText(String Function(String) f) => QuizOption(
    f(text),
    selected: selected,
    correct: correct,
    images: images.map((i) => i.mapText(f)).toList(),
  );
  Map<String, dynamic> toJson(String? prefix) => {
    'text': text,
    'is_selected': selected,
    'is_correct': correct,
    'images': images.map((i) => i.toJson(prefix)).toList(),
  };
}

class QuizQuestion {
  final int number;
  final String type, text;
  final List<QuizOption> options;
  final List<QuizImage> images;
  final String? userAnswer, correctAnswer;
  const QuizQuestion({
    required this.number,
    required this.type,
    required this.text,
    this.options = const [],
    this.images = const [],
    this.userAnswer,
    this.correctAnswer,
  });

  /// English type label; exported files always use English labels.
  String get typeLabel => Strings.english.questionType(type);
  String get searchText => [
    text,
    ...options.map((o) => o.text),
    userAnswer ?? '',
    correctAnswer ?? '',
  ].join(' ').toLowerCase();
  Iterable<QuizImage> get allImages sync* {
    yield* images;
    for (final o in options) {
      yield* o.images;
    }
  }

  QuizQuestion mapText(String Function(String) f) => QuizQuestion(
    number: number,
    type: type,
    text: f(text),
    options: options.map((o) => o.mapText(f)).toList(),
    images: images.map((i) => i.mapText(f)).toList(),
    userAnswer: userAnswer == null ? null : f(userAnswer!),
    correctAnswer: correctAnswer == null ? null : f(correctAnswer!),
  );
  String plainText() {
    final lines = ['$number · $typeLabel', text];
    void addImages(List<QuizImage> images) {
      for (final im in images) {
        lines.add('[${im.available ? 'Image' : 'Missing image'}: ${im.alt}]');
      }
    }

    addImages(images);
    for (var i = 0; i < options.length; i++) {
      final o = options[i];
      final marks = [if (o.selected) 'Selected', if (o.correct) 'Correct'];
      lines.add(
        '${optionLabel(i)}) ${o.text}${marks.isEmpty ? '' : ' [${marks.join(' · ')}]'}',
      );
      addImages(o.images);
    }
    final selected = options
        .where((o) => o.selected)
        .map((o) => o.text)
        .join(', ');
    final correct = options
        .where((o) => o.correct)
        .map((o) => o.text)
        .join(', ');
    if (userAnswer != null &&
        userAnswer!.isNotEmpty &&
        userAnswer != selected) {
      lines.add('Your answer: $userAnswer');
    }
    if (correctAnswer != null &&
        correctAnswer!.isNotEmpty &&
        correctAnswer != correct) {
      lines.add('Correct answer: $correctAnswer');
    }
    return lines.join('\n');
  }

  Map<String, dynamic> toJson(String? prefix) => {
    'number': number,
    'type': type,
    'question': text,
    'options': options.map((o) => o.toJson(prefix)).toList(),
    'question_images': images.map((i) => i.toJson(prefix)).toList(),
    'user_answer': userAnswer,
    'correct_answer': correctAnswer,
  };
}

String optionLabel(int i) => i < 26 ? String.fromCharCode(65 + i) : '${i + 1}';

class QuizDocument {
  final String title, course, sourcePath, sourceHash;
  final List<QuizQuestion> questions;
  final List<String> warnings;
  final Map<String, int> diagnostics;
  const QuizDocument({
    required this.title,
    this.course = '',
    required this.sourcePath,
    required this.sourceHash,
    required this.questions,
    this.warnings = const [],
    this.diagnostics = const {},
  });
  Iterable<QuizImage> get images => questions.expand((q) => q.allImages);
  QuizDocument mapText(String Function(String) f) => QuizDocument(
    title: f(title),
    course: f(course),
    sourcePath: sourcePath,
    sourceHash: sourceHash,
    questions: questions.map((q) => q.mapText(f)).toList(),
    warnings: warnings.map(f).toList(),
    diagnostics: diagnostics,
  );
  QuizDocument filtered(AppSettings settings) =>
      mapText((s) => filterText(s, settings.filterLines));
  String plainText() => [
    '$title\n${[course, '${questions.length} questions'].where((s) => s.isNotEmpty).join(' · ')}',
    ...questions.map((q) => q.plainText()),
    if (warnings.isNotEmpty) 'Export notes\n${warnings.join('\n')}',
  ].join('\n\n');
  Map<String, dynamic> toJson({
    String? assetsPrefix,
    bool includeDiagnostics = false,
  }) => {
    'schema_version': '2.0',
    'title': title,
    'course': course,
    'questions': questions.map((q) => q.toJson(assetsPrefix)).toList(),
    'warnings': warnings,
    if (includeDiagnostics) 'diagnostics': diagnostics,
  };
  String toJsonText({String? assetsPrefix, bool includeDiagnostics = false}) =>
      const JsonEncoder.withIndent('  ').convert(
        toJson(
          assetsPrefix: assetsPrefix,
          includeDiagnostics: includeDiagnostics,
        ),
      );
}

String filterText(String text, List<String> filters) {
  for (final term in filters) {
    text = text.replaceAll(
      RegExp(RegExp.escape(term), caseSensitive: false),
      '',
    );
  }
  return text
      .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
      .replaceAll(RegExp(r' *\n *'), '\n')
      .trim();
}

int filterCount(QuizDocument doc, List<String> filters) {
  var total = 0;
  for (final q in doc.questions) {
    for (final text in [
      q.text,
      ...q.options.map((o) => o.text),
      q.userAnswer ?? '',
      q.correctAnswer ?? '',
    ]) {
      var remaining = text;
      for (final term in filters) {
        final pattern = RegExp(RegExp.escape(term), caseSensitive: false);
        total += pattern.allMatches(remaining).length;
        remaining = remaining.replaceAll(pattern, '');
      }
    }
  }
  return total;
}

List<({String text, int count})> repeatedSentences(QuizDocument doc) {
  final counts = <String, int>{};
  final originals = <String, String>{};
  for (final q in doc.questions) {
    final seen = <String>{};
    for (final text in [q.text, ...q.options.map((o) => o.text)]) {
      for (final m in RegExp(r'[^.!?。！？\n]+[.!?。！？]?').allMatches(text)) {
        final sentence = m[0]!.trim();
        if (sentence.length >= 12) {
          final key = sentence.toLowerCase();
          seen.add(key);
          originals[key] = sentence;
        }
      }
    }
    for (final s in seen) {
      counts[s] = (counts[s] ?? 0) + 1;
    }
  }
  final rows = counts.entries.where((e) => e.value >= 2).toList()
    ..sort(
      (a, b) => b.value.compareTo(a.value) != 0
          ? b.value.compareTo(a.value)
          : b.key.length.compareTo(a.key.length),
    );
  return rows
      .take(3)
      .map((e) => (text: originals[e.key]!, count: e.value))
      .toList();
}

class ExportResult {
  final List<String> files, errors, warnings;
  final int questionCount;
  const ExportResult({
    this.files = const [],
    this.errors = const [],
    this.warnings = const [],
    this.questionCount = 0,
  });
}
