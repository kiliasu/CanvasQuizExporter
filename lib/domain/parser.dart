import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;
import 'package:image/image.dart' as imaging;
import 'package:path/path.dart' as p;

import '../l10n/strings.dart';
import 'models.dart';

const maxFileBytes = 64 * 1024 * 1024;
const maxZipBytes = 512 * 1024 * 1024;

Iterable<dom.Element> _ancestors(dom.Element element) sync* {
  for (var parent = element.parent; parent != null; parent = parent.parent) {
    yield parent;
  }
}

bool _hidden(dom.Element element) => [element, ..._ancestors(element)].any(
  (e) =>
      e.attributes.containsKey('hidden') ||
      e.attributes['aria-hidden'] == 'true' ||
      e.classes.contains('hidden') ||
      e.classes.contains('answer_template') ||
      RegExp(
        r'display\s*:\s*none|visibility\s*:\s*hidden',
        caseSensitive: false,
      ).hasMatch(e.attributes['style'] ?? ''),
);

List<String> expandInputs(List<String> inputs) {
  final files = <String, String>{};
  void add(String path) {
    if (!['.html', '.htm'].contains(p.extension(path).toLowerCase())) return;
    final normalized = p.normalize(p.absolute(path));
    files.putIfAbsent(
      Platform.isWindows ? normalized.toLowerCase() : normalized,
      () => normalized,
    );
  }

  void visit(Directory directory) {
    final entries = directory.listSync(followLinks: false)
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final entry in entries) {
      if (entry is File) {
        add(entry.path);
      } else if (entry is Directory &&
          !RegExp(
            r'(_files|\.files|_assets)$',
            caseSensitive: false,
          ).hasMatch(p.basename(entry.path)) &&
          !p.basename(entry.path).startsWith('.')) {
        visit(entry);
      }
    }
  }

  for (final input in inputs) {
    if (Directory(input).existsSync()) {
      visit(Directory(input));
    } else {
      add(input);
    }
  }
  return files.values.toList();
}

String htmlText(dom.Node? node, {bool blanks = true}) {
  if (node == null) return '';
  String walk(dom.Node n) {
    if (n is dom.Text) return n.data;
    if (n is! dom.Element) return n.nodes.map(walk).join();
    final tag = n.localName;
    if (['script', 'style', 'noscript', 'template', 'button'].contains(tag)) {
      return '';
    }
    if (n.attributes.containsKey('hidden') ||
        n.classes.contains('screenreader-only') ||
        n.classes.contains('hidden') ||
        RegExp(
          r'display\s*:\s*none',
          caseSensitive: false,
        ).hasMatch(n.attributes['style'] ?? '')) {
      return '';
    }
    if (tag == 'br') return '\n';
    if (tag == 'img') {
      return n.classes.contains('equation_image')
          ? (n.attributes['alt'] ?? '')
          : '';
    }
    if (tag == 'input') {
      return ['text', 'number', null].contains(n.attributes['type'])
          ? ((n.attributes['value'] ?? '').isNotEmpty
                ? n.attributes['value']!
                : (blanks ? '_____' : ''))
          : '';
    }
    if (tag == 'textarea') {
      return n.text.isNotEmpty ? n.text : (blanks ? '_____' : '');
    }
    if (tag == 'select') {
      return n.querySelector('option[selected]')?.text.trim() ??
          (blanks ? '_____' : '');
    }
    final text = n.nodes.map(walk).join();
    if (tag == 'sup') return '^${text.trim()}';
    if (tag == 'sub') return '_${text.trim()}';
    if (tag == 'tr') {
      return '\n${n.children.map(walk).map((s) => s.trim()).where((s) => s.isNotEmpty).join(' | ')}\n';
    }
    return [
          'p',
          'div',
          'li',
          'tr',
          'h1',
          'h2',
          'h3',
          'h4',
          'blockquote',
          'pre',
          'section',
        ].contains(tag)
        ? '\n$text\n'
        : text;
  }

  return walk(node)
      .replaceAll('\u00a0', ' ')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r' *\n *'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

class _Resources {
  final String root;
  final Strings strings;
  final folders = <String>[];
  final members = <String, ArchiveFile>{};
  final warnings = <String>[];
  _Resources(String source, this.strings)
    : root = p.dirname(p.normalize(p.absolute(source))) {
    final stem = p.basenameWithoutExtension(source);
    final stems = {
      stem,
      stem.replaceFirst(RegExp(r'_cp$', caseSensitive: false), ''),
      stem.replaceFirst(RegExp(r'^Quiz[_ ]*', caseSensitive: false), ''),
    };
    for (final s in List<String>.of(stems)) {
      stems.add(s.replaceFirst(RegExp(r'_cp$', caseSensitive: false), ''));
    }
    for (final name in stems) {
      for (final suffix in ['_files', '.files']) {
        final directory = p.join(root, '$name$suffix');
        if (Directory(directory).existsSync()) folders.add(directory);
        final file = File('$directory.zip');
        if (!file.existsSync()) continue;
        if (file.lengthSync() > maxZipBytes) {
          throw FormatException(strings.zipTooLarge);
        }
        final archive = ZipDecoder().decodeBytes(
          file.readAsBytesSync(),
          verify: true,
        );
        if (archive.length > 5000 ||
            archive.fold<int>(0, (n, f) => n + f.size) > maxZipBytes) {
          throw FormatException(strings.zipOverLimit);
        }
        for (final entry in archive) {
          final relative = entry.name.replaceAll('\\', '/');
          if (p.posix.isAbsolute(relative) ||
              relative.split('/').contains('..') ||
              relative.contains(':') ||
              entry.isSymbolicLink ||
              entry.size > maxFileBytes) {
            throw FormatException(strings.zipUnsafe);
          }
          if (!entry.isFile) continue;
          members.putIfAbsent(p.normalize(p.join(root, relative)), () => entry);
          members.putIfAbsent(
            p.normalize(p.join(directory, relative)),
            () => entry,
          );
        }
      }
    }
  }

  /// [root] as the file system resolves it: without junctions, symbolic links
  /// or 8.3 short names such as `C:\Users\RUNNER~1`.
  late final String _realRoot = () {
    try {
      return Directory(root).resolveSymbolicLinksSync();
    } on FileSystemException {
      return root;
    }
  }();

  bool allowed(String path) => p.equals(root, path) || p.isWithin(root, path);
  bool exists(String path) {
    if (!allowed(path)) return false;
    if (members.containsKey(path)) return true;
    final f = File(path);
    if (!f.existsSync()) return false;
    try {
      // A resolved path must stay inside the resolved root, so links out of
      // the page folder are refused while a folder reached through a
      // junction or short name still counts.
      final real = f.resolveSymbolicLinksSync();
      return p.equals(_realRoot, real) || p.isWithin(_realRoot, real);
    } on FileSystemException {
      return false;
    }
  }

  Uint8List read(String path) {
    if (!exists(path)) throw FileSystemException(strings.resourceMissing, path);
    final f = File(path);
    if (f.existsSync()) {
      if (f.lengthSync() > maxFileBytes) {
        throw FormatException(strings.resourceTooLarge);
      }
      return f.readAsBytesSync();
    }
    return Uint8List.fromList(members[path]!.content);
  }

  String? resolve(String src, String current) {
    if (src.isEmpty || src.startsWith('\\\\') || src.startsWith('//')) {
      return null;
    }
    try {
      if (RegExp(
        r'^(data|javascript|about|blob):',
        caseSensitive: false,
      ).hasMatch(src)) {
        return null;
      }
      final windows = RegExp(r'^[A-Za-z]:[\\/]').hasMatch(src);
      final uri = windows ? null : Uri.tryParse(src);
      if (uri != null &&
          uri.hasScheme &&
          !['http', 'https', 'file'].contains(uri.scheme)) {
        return null;
      }
      if (uri?.scheme == 'file' &&
          uri!.host.isNotEmpty &&
          uri.host != 'localhost') {
        return null;
      }
      final remote = uri?.scheme == 'http' || uri?.scheme == 'https';
      var raw = Uri.decodeComponent(
        windows ? src.split(RegExp('[?#]')).first : (uri?.path ?? src),
      ).replaceAll('\\', '/');
      if (RegExp(r'^/[A-Za-z]:/').hasMatch(raw)) raw = raw.substring(1);
      if (!remote) {
        final candidate = p.normalize(
          p.isAbsolute(raw) ? raw : p.join(p.dirname(current), raw),
        );
        if (exists(candidate)) return candidate;
      }
      final name = p.posix.basename(raw).toLowerCase();
      if (name.isEmpty) return null;
      for (final folder in [p.dirname(current), ...folders]) {
        final candidate = p.normalize(p.join(folder, p.posix.basename(raw)));
        if (exists(candidate)) return candidate;
      }
      for (final member in members.keys) {
        if (p.basename(member).toLowerCase() == name) return member;
      }
      for (final folder in folders) {
        for (final entry in Directory(
          folder,
        ).listSync(recursive: true, followLinks: false)) {
          if (entry is File &&
              p.basename(entry.path).toLowerCase() == name &&
              exists(entry.path)) {
            return entry.path;
          }
        }
      }
    } on FormatException {
      return null;
    } on FileSystemException {
      return null;
    }
    return null;
  }
}

class _Redactor {
  final tokens = <String>{};
  int count = 0;
  _Redactor(String raw) {
    final names = RegExp(
      r'"(?:display_name|short_name|sortable_name|full_name|user_name|user_email|email|login_id)"\s*:\s*("(?:[^"\\]|\\.)*")',
    );
    for (final m in names.allMatches(raw)) {
      try {
        final value = jsonDecode(m[1]!);
        if (value is String && value.trim().length >= 2) {
          tokens.add(value.trim());
        }
      } on FormatException {
        continue;
      }
    }
    for (final m in RegExp(
      r'"current_user"\s*:\s*(\{[^{}]{0,8192}\})',
    ).allMatches(raw)) {
      try {
        final value = jsonDecode(m[1]!) as Map;
        for (final key in [
          'name',
          'display_name',
          'short_name',
          'sortable_name',
          'email',
          'login_id',
        ]) {
          final text = value[key];
          if (text is String && text.trim().length >= 2) {
            tokens.add(text.trim());
          }
        }
      } on FormatException {
        continue;
      }
    }
  }
  String call(String text) {
    String replace(RegExp pattern, String replacement) =>
        text.replaceAllMapped(pattern, (m) {
          count++;
          return replacement;
        });
    final sorted = tokens.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final token in sorted) {
      text = replace(
        RegExp('(?<![A-Za-z0-9_])${RegExp.escape(token)}(?![A-Za-z0-9_])'),
        '[REDACTED]',
      );
    }
    text = replace(
      RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'),
      '[REDACTED_EMAIL]',
    );
    text = replace(
      RegExp(
        r'\b(?:access_token|auth_token|csrf_token|api_key|token)\s*[=:]\s*[^\s,;<>]+',
        caseSensitive: false,
      ),
      '[REDACTED_TOKEN]',
    );
    text = replace(
      RegExp(r'''(?:[A-Za-z]:[\\/]|file://|/(?:Users|home)/)[^\s<>"|]+'''),
      '[REDACTED_PATH]',
    );
    text = text.replaceAllMapped(RegExp(r'(https?://[^\s<>?]+)\?[^\s<>]+'), (
      m,
    ) {
      count++;
      return '${m[1]}?[REDACTED_QUERY]';
    });
    return text;
  }
}

QuizDocument parseQuiz(String source, {Strings strings = Strings.english}) {
  source = p.normalize(p.absolute(source));
  final resources = _Resources(source, strings);
  final original = resources.read(source);
  final queue = <({String path, String raw, int depth})>[
    (path: source, raw: utf8.decode(original, allowMalformed: true), depth: 0),
  ];
  final seen = <String>{source};
  dom.Document? best;
  var bestPath = source, bestScore = -1, bestDepth = 0;
  final identity = StringBuffer();
  for (var i = 0; i < queue.length && i < 64; i++) {
    final item = queue[i];
    identity.writeln(item.raw);
    final document = html.parse(item.raw);
    final count = document
        .querySelectorAll('.question')
        .where((e) => !_hidden(e) && e.querySelector('.question_text') != null)
        .length;
    if (count > bestScore) {
      best = document;
      bestPath = item.path;
      bestScore = count;
      bestDepth = item.depth;
    }
    if (item.depth >= 4) continue;
    for (final frame in document.querySelectorAll('iframe')) {
      if (queue.length >= 64) break;
      if ('${frame.id} ${frame.attributes['title'] ?? ''}'
          .toLowerCase()
          .contains('error')) {
        continue;
      }
      var inline = frame.attributes['srcdoc'];
      final src = frame.attributes['src'] ?? '';
      try {
        if (inline == null && src.startsWith('data:text/html')) {
          if (src.length > maxFileBytes * 2) continue;
          inline = Uri.parse(src).data?.contentAsString();
        }
        if (inline != null) {
          final key = sha256.convert(utf8.encode(inline)).toString();
          if (seen.add(key)) {
            queue.add((path: item.path, raw: inline, depth: item.depth + 1));
          }
          continue;
        }
        final next = resources.resolve(src, item.path);
        if (next != null && seen.add(next)) {
          queue.add((
            path: next,
            raw: utf8.decode(resources.read(next), allowMalformed: true),
            depth: item.depth + 1,
          ));
        }
      } on Object {
        resources.warnings.add(strings.embeddedPageUnreadable);
      }
    }
  }
  final document = best!;
  final redactor = _Redactor(identity.toString());
  final tags = document
      .querySelectorAll('.question')
      .where((e) => !_hidden(e) && e.querySelector('.question_text') != null)
      .toList();
  if (tags.isEmpty) throw FormatException(strings.noQuestionsFound);
  final imageCache = <String, QuizImage>{};
  List<QuizImage> images(dom.Element? container) {
    if (container == null) return [];
    return container
        .querySelectorAll('img')
        .where((e) => !_hidden(e) && !e.classes.contains('equation_image'))
        .map((e) {
          final src = e.attributes['src'] ?? e.attributes['data-src'] ?? '';
          final alt = redactor(e.attributes['alt'] ?? 'Image');
          final cached = imageCache[src];
          if (cached != null) {
            return QuizImage(
              alt: alt,
              key: cached.key,
              bytes: cached.bytes,
              width: cached.width,
              height: cached.height,
            );
          }
          QuizImage result = QuizImage(alt: alt);
          try {
            Uint8List? bytes;
            if (src.startsWith('data:image/') &&
                src.length < maxFileBytes * 2) {
              bytes = Uri.parse(src).data?.contentAsBytes();
            } else {
              final path = resources.resolve(src, bestPath);
              if (path != null) bytes = resources.read(path);
            }
            if (bytes != null && bytes.length <= maxFileBytes) {
              final decoder = imaging.findDecoderForData(bytes);
              final info = decoder?.startDecode(bytes);
              if (info != null && info.width * info.height <= 40000000) {
                final decoded = decoder!.decodeFrame(0);
                if (decoded != null) {
                  final png = imaging.encodePng(decoded);
                  final key =
                      'image_${sha256.convert(png).toString().substring(0, 16)}.png';
                  result = QuizImage(
                    alt: alt,
                    key: key,
                    bytes: png,
                    width: decoded.width,
                    height: decoded.height,
                  );
                }
              }
            }
          } on Object {
            /* A missing/corrupt picture remains a visible warning. */
          }
          imageCache[src] = result;
          return result;
        })
        .toList();
  }

  final questions = <QuizQuestion>[];
  for (var i = 0; i < tags.length; i++) {
    final tag = tags[i], textNode = tags[i].querySelector('.question_text');
    final type =
        tag.querySelector('.question_type')?.text.trim() ??
        tag.classes.firstWhere(
          (x) => x.endsWith('_question') && x != 'display_question',
          orElse: () => 'unknown',
        );
    final number =
        int.tryParse(
          RegExp(r'\d+').firstMatch(
                tag.querySelector('.question_name')?.text ?? '',
              )?[0] ??
              '',
        ) ??
        i + 1;
    final options = <QuizOption>[];
    for (final answer in tag.querySelectorAll(
      '.answers_wrapper .answer, .answers .answer, li.answer',
    )) {
      if (_hidden(answer) ||
          _ancestors(answer).any((e) => e.classes.contains('answer'))) {
        continue;
      }
      if (answer.classes.contains('no_answer')) continue;
      var text = '';
      if (type == 'matching_question') {
        final left = htmlText(answer.querySelector('.answer_match_left_html'));
        final key = left.isNotEmpty
            ? left
            : htmlText(answer.querySelector('.answer_match_left'));
        final right = htmlText(
          answer.querySelector('.answer_match_right'),
          blanks: false,
        );
        text = '$key → ${right.isEmpty ? '[No saved answer]' : right}';
      } else {
        final rich = answer.querySelector('.answer_html');
        text = htmlText(rich, blanks: false);
        if (text.isEmpty) {
          text = htmlText(
            answer.querySelector(
              '.answer_text, .numerical_answer, .text_answer, .answer_exact',
            ),
            blanks: false,
          );
        }
        if (text.isEmpty) {
          text =
              answer
                  .querySelector(
                    'input[type="text"][value], input[type="number"][value]',
                  )
                  ?.attributes['value'] ??
              '';
        }
      }
      final pictures = images(
        answer.querySelector('.answer_html') ??
            answer.querySelector('.answer_text'),
      );
      if (text.trim().isEmpty && pictures.isEmpty) continue;
      final title = (answer.attributes['title'] ?? '').toLowerCase();
      final selected =
          answer.classes.contains('selected_answer') ||
          answer.querySelector('input[checked], [aria-checked="true"]') != null;
      final correct =
          answer.classes.contains('correct_answer') ||
          (!title.contains('incorrect') &&
              (title.contains('this was the correct answer') ||
                  title == 'correct answer'));
      options.add(
        QuizOption(
          redactor(text),
          selected: selected,
          correct: correct,
          images: pictures,
        ),
      );
    }
    String? user = options
        .where((o) => o.selected)
        .map((o) => o.text)
        .join(', ');
    String? correct = options
        .where((o) => o.correct)
        .map((o) => o.text)
        .join(', ');
    if (user.isEmpty) {
      user = null;
      final candidate = tag.querySelector(
        '.user_answer, .submitted_answer, .essay_answer',
      );
      if (candidate != null && !_hidden(candidate)) {
        user = redactor(htmlText(candidate, blanks: false));
      }
      if ((user == null || user.isEmpty) &&
          [
            'numerical_question',
            'short_answer_question',
            'essay_question',
            'fill_in_multiple_blanks_question',
            'multiple_dropdowns_question',
          ].contains(type)) {
        final values = <String>[];
        for (final control in tag.querySelectorAll(
          '.answers input[type="text"], .answers input[type="number"], .answers textarea, .question_text input[type="text"], .question_text select',
        )) {
          if (_hidden(control)) {
            continue;
          }
          final value = control.localName == 'input'
              ? (control.attributes['value'] ?? '')
              : htmlText(control, blanks: false);
          if (value.trim().isNotEmpty) values.add(redactor(value.trim()));
        }
        user = values.isEmpty ? null : values.join(', ');
      }
    }
    if (correct.isEmpty) correct = null;
    final savedCorrect = tag.querySelector('.correct_answer_text');
    if (correct == null && savedCorrect != null && !_hidden(savedCorrect)) {
      correct = redactor(htmlText(savedCorrect, blanks: false));
    }
    questions.add(
      QuizQuestion(
        number: number,
        type: type,
        text: redactor(htmlText(textNode)),
        options: options,
        images: images(textNode),
        userAnswer: user?.isEmpty == true ? null : user,
        correctAnswer: correct?.isEmpty == true ? null : correct,
      ),
    );
  }
  var title =
      document
          .querySelector('#quiz_title, .quiz_title, h1.quiz-title')
          ?.text
          .trim() ??
      document.querySelector('title')?.text.trim() ??
      'Canvas Quiz';
  var course =
      document
          .querySelector('#breadcrumbs a[href*="/courses/"]')
          ?.text
          .trim() ??
      '';
  final full = document.querySelector('title')?.text ?? '';
  if (full.contains(':') && course.isEmpty) {
    final parts = full.split(':');
    if (parts.first.toLowerCase().trim() == 'quiz') {
      if (title == full) title = parts.skip(1).join(':').trim();
    } else if (parts.first.toLowerCase().contains('quiz')) {
      course = parts.skip(1).join(':').trim();
      if (title == full) title = parts.first.trim();
    }
  }
  final missing = questions
      .expand((q) => q.allImages)
      .where((im) => !im.available)
      .length;
  return QuizDocument(
    title: redactor(title),
    course: redactor(course),
    sourcePath: source,
    sourceHash: sha256.convert(original).toString().substring(0, 8),
    questions: questions,
    warnings: [
      ...resources.warnings,
      if (missing > 0) strings.imagesWithoutCopy(missing),
    ],
    diagnostics: {
      'questions': questions.length,
      'iframe_depth': bestDepth,
      'redactions': redactor.count,
      'missing_images': missing,
    },
  );
}
