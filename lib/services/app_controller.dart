import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../domain/models.dart';
import '../domain/parser.dart';
import '../domain/exporter.dart';
import '../l10n/strings.dart';
import 'settings_store.dart';
import 'desktop_service.dart';

class QueueEntry {
  final String path;
  QuizDocument? document;
  String? error;
  bool parsing = false;
  int request = 0;
  QueueEntry(this.path);
  String get name => p.basenameWithoutExtension(path);
}

class AppController extends ChangeNotifier {
  final SettingsStore store;
  final PdfFonts fonts;
  final DesktopService desktop;
  late AppSettings settings;
  final entries = <QueueEntry>[];
  QueueEntry? current;
  String query = '';
  bool busy = false, cancelling = false, resultsOpen = false, pdfMode = false;
  int done = 0, total = 0, revision = 0;
  String status = '', notification = '';
  bool notificationError = false;
  final results = <String>[];
  final selectedResults = <String>{};
  final logs = <String>[];
  bool _disposed = false;
  Timer? _saveTimer;
  Future<void>? exportFuture;
  AppController({
    required this.store,
    required this.fonts,
    DesktopService? desktop,
  }) : desktop = desktop ?? DesktopService() {
    settings = store.load();
  }
  void changed() {
    if (!_disposed) notifyListeners();
  }

  /// The interface language, `zh` or `en`.
  String get language => Strings.resolve(
    settings.language,
    PlatformDispatcher.instance.locale.languageCode,
  );
  Strings get strings => Strings.forLanguage(language);

  QuizDocument? get raw => current?.document;
  QuizDocument? get document => raw?.filtered(settings);
  int get validCount => entries.where((e) => e.error == null).length;
  bool get canExport => !busy && validCount > 0 && settings.formats.isNotEmpty;
  List<QuizQuestion> get visibleQuestions =>
      document?.questions
          .where((q) => q.searchText.contains(query.trim().toLowerCase()))
          .toList() ??
      [];
  int get removedCount =>
      raw == null ? 0 : filterCount(raw!, settings.filterLines);
  List<({String text, int count})> get suggestions =>
      raw == null ? [] : repeatedSentences(raw!);
  void tell(String message, {bool error = false}) {
    notification = message;
    notificationError = error;
    changed();
  }

  void setLanguage(String value) {
    settings.language = value;
    layoutChanged();
    // Reading errors and warnings are worded when a page is read.
    if (busy) return;
    for (final entry in entries) {
      if (entry.error != null || entry.document?.warnings.isNotEmpty == true) {
        _parse(entry);
      }
    }
  }

  void settingsChanged() {
    revision++;
    layoutChanged();
  }

  /// Persists view-only preferences without invalidating the previews.
  void layoutChanged() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), save);
    changed();
  }

  void save() {
    try {
      store.save(settings);
    } on Object catch (e) {
      logs.add(strings.settingsSaveFailed(e));
      tell(strings.settingsNotSaved, error: true);
    }
  }

  Future<void> addPaths(List<String> paths) async {
    if (busy) return;
    try {
      final expanded = await Isolate.run(() => expandInputs(paths));
      if (_disposed || busy) return;
      final known = entries.map((e) => e.path.toLowerCase()).toSet();
      final added = <QueueEntry>[];
      for (final path in expanded) {
        if (known.add(path.toLowerCase())) {
          final entry = QueueEntry(path);
          entries.add(entry);
          added.add(entry);
        }
      }
      if (added.isEmpty) {
        tell(strings.noNewPages, error: true);
        return;
      }
      current ??= added.first;
      status = '';
      changed();
      for (final entry in added) {
        if (_disposed) break;
        await _parse(entry);
      }
    } on Object catch (e) {
      tell(strings.cannotAddPages(e), error: true);
    }
  }

  Future<void> _parse(QueueEntry entry) async {
    if (!entries.contains(entry)) return;
    final request = ++entry.request;
    entry.parsing = true;
    entry.error = null;
    changed();
    final path = entry.path, s = strings;
    try {
      final parsed = await Isolate.run(() => parseQuiz(path, strings: s));
      if (!_disposed && entries.contains(entry) && request == entry.request) {
        entry.document = parsed;
      }
    } on Object catch (e) {
      if (!_disposed && entries.contains(entry) && request == entry.request) {
        entry.document = null;
        entry.error = e.toString().replaceFirst('FormatException: ', '');
      }
    } finally {
      if (request == entry.request) {
        entry.parsing = false;
        revision++;
        changed();
      }
    }
  }

  void select(QueueEntry entry) {
    if (current == entry) return;
    current = entry;
    query = '';
    revision++;
    changed();
  }

  Future<void> refresh() async {
    if (current != null && !busy) await _parse(current!);
  }

  void removeCurrent() {
    if (busy || current == null) return;
    final at = entries.indexOf(current!);
    current!.request++;
    entries.removeAt(at);
    current = entries.isEmpty ? null : entries[at.clamp(0, entries.length - 1)];
    query = '';
    revision++;
    changed();
  }

  void clear() {
    if (busy) return;
    for (final e in entries) {
      e.request++;
    }
    entries.clear();
    current = null;
    query = '';
    status = '';
    revision++;
    changed();
  }

  void setQuery(String value) {
    query = value;
    changed();
  }

  void setView(bool pdf) {
    pdfMode = pdf;
    changed();
  }

  void toggleSuggestion(String text) {
    final lines = settings.filterLines;
    final at = lines.indexWhere((s) => s.toLowerCase() == text.toLowerCase());
    if (at < 0) {
      lines.add(text);
    } else {
      lines.removeAt(at);
    }
    settings.filters = lines.join('\n');
    settingsChanged();
  }

  Future<Uint8List> previewPdf() async {
    final doc = document;
    if (doc == null) throw StateError('No quiz selected');
    final cfg = settings.snapshot();
    final bundle = fonts, s = strings;
    return Isolate.run(() => buildPdf(doc, cfg, bundle, strings: s));
  }

  Future<void> export({bool selectedOnly = false}) {
    if (!canExport) return Future.value();
    final task = _export(selectedOnly);
    exportFuture = task;
    return task;
  }

  Future<void> _export(bool selectedOnly) async {
    final cfg = settings.snapshot(), s = strings;
    try {
      cfg.validate(s);
    } on Object catch (e) {
      tell(e.toString().replaceFirst('FormatException: ', ''), error: true);
      return;
    }
    final requested = (selectedOnly ? [?current] : entries).toList();
    final targets = requested
        .where((e) => e.error == null)
        .map((e) => e.path)
        .toList();
    if (targets.isEmpty) {
      tell(s.nothingToExport, error: true);
      return;
    }
    busy = true;
    cancelling = false;
    done = 0;
    total = targets.length;
    results.clear();
    selectedResults.clear();
    logs.clear();
    resultsOpen = false;
    save();
    final stopwatch = Stopwatch()..start();
    var failures = requested.where((e) => e.error != null).length;
    logs.add(s.exportStarting(total, cfg.formats.join(', ')));
    logs.addAll(
      requested
          .where((e) => e.error != null)
          .map((e) => s.skipped(e.name, e.error!)),
    );
    changed();
    try {
      for (var index = 0; index < targets.length; index++) {
        if (cancelling) break;
        final path = targets[index];
        status = s.exporting(index + 1, total, p.basename(path));
        changed();
        try {
          final fonts = this.fonts;
          final ordinal = index + 1;
          final result = await Isolate.run(
            () => exportQuiz(path, cfg, fonts, index: ordinal, strings: s),
          );
          results.addAll(result.files);
          logs.addAll(result.files.map(s.wrote));
          logs.addAll(result.errors);
          logs.addAll(result.warnings);
          failures += result.errors.length;
        } on Object catch (e) {
          failures++;
          logs.add(s.exportFailedFor(p.basename(path), e));
        }
        done = index + 1;
        changed();
      }
      final cancelled = cancelling && done < total;
      status = s.exportSummary(
        outcome: cancelled
            ? s.exportCancelled
            : failures > 0
            ? (results.isEmpty ? s.exportFailed : s.exportPartial)
            : s.exportDone,
        itemCount: results.length,
        seconds: (stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1),
        failures: failures,
        done: done,
        total: total,
        cancelled: cancelled,
      );
      logs.add(status);
      resultsOpen = true;
      if (cfg.openOnFinish && results.isNotEmpty && !cancelling) {
        await openOutputs();
      }
    } finally {
      busy = false;
      cancelling = false;
      changed();
    }
  }

  void cancel() {
    if (busy) {
      cancelling = true;
      status = strings.stoppingAfterCurrent;
      changed();
    }
  }

  void toggleResult(String path) {
    selectedResults.contains(path)
        ? selectedResults.remove(path)
        : selectedResults.add(path);
    changed();
  }

  List<String> get chosenResults => selectedResults.isEmpty
      ? results
      : results.where(selectedResults.contains).toList();
  Future<void> openOutputs() async {
    for (final directory in results.map(p.dirname).toSet()) {
      try {
        await desktop.open(directory);
      } on Object catch (e) {
        tell(strings.cannotOpenFolder(e), error: true);
      }
    }
  }

  Future<void> openResult(String path) async {
    try {
      await desktop.open(path);
    } on Object catch (e) {
      tell(strings.cannotOpenFile(e), error: true);
    }
  }

  Future<void> dragResults(String path) async {
    try {
      await desktop.drag(
        selectedResults.contains(path) ? chosenResults : [path],
      );
    } on Object catch (e) {
      tell(strings.cannotDragFiles(e), error: true);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _saveTimer?.cancel();
    super.dispose();
  }
}
