import 'dart:io';

import 'package:canvas_quiz_exporter/domain/models.dart';
import 'package:canvas_quiz_exporter/services/app_controller.dart';
import 'package:canvas_quiz_exporter/services/desktop_service.dart';
import 'package:canvas_quiz_exporter/services/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support.dart';

class RecordingDesktop extends DesktopService {
  final opened = <String>[];
  final dragged = <List<String>>[];
  @override
  Future<void> open(String path) async {
    opened.add(path);
  }

  @override
  Future<void> drag(List<String> paths) async {
    dragged.add(paths);
  }
}

void main() {
  late Directory root;
  late AppController c;
  late RecordingDesktop desktop;
  setUp(() {
    root = Directory.systemTemp.createTempSync('canvas-controller-');
    desktop = RecordingDesktop();
    c = AppController(
      store: SettingsStore(path: p.join(root.path, 'settings.json')),
      fonts: testFonts(),
      desktop: desktop,
    );
    c.settings.customOutput = true;
    c.settings.outputPath = p.join(root.path, 'out');
    c.settings.language = 'zh';
  });
  tearDown(() {
    c.dispose();
    root.deleteSync(recursive: true);
  });
  test(
    'queue deduplicates, selected export works, results route to OS service',
    () async {
      final a = writeQuiz(root, 'a.html', quizHtml());
      final b = writeQuiz(root, 'b.html', quizHtml(text: 'Another question.'));
      await c.addPaths([a.path, a.path, b.path]);
      expect(c.entries.length, 2);
      expect(c.current!.document!.questions.length, 1);
      c.select(c.entries.last);
      c.setQuery('another');
      expect(c.visibleQuestions.length, 1);
      await c.export(selectedOnly: true);
      expect(c.total, 1);
      expect(c.results.length, 1);
      expect(
        File(c.results.single).readAsStringSync(),
        contains('Another question.'),
      );
      c.toggleResult(c.results.single);
      await c.openOutputs();
      await c.openResult(c.results.single);
      await c.dragResults(c.results.single);
      expect(desktop.opened, [c.settings.outputPath, c.results.single]);
      expect(desktop.dragged.single, c.results);
    },
  );
  test(
    'bad pages are reported and a deleted source does not abort later inputs',
    () async {
      final a = writeQuiz(root, 'a.html', quizHtml());
      final b = writeQuiz(root, 'b.html', quizHtml());
      final bad = writeQuiz(root, 'bad.html', '<h1>No questions</h1>');
      await c.addPaths([a.path, b.path, bad.path]);
      a.deleteSync();
      await c.export();
      expect(c.results.length, 1);
      expect(c.status, contains('部分完成'));
      expect(c.logs.join('\n'), contains('跳过'));
    },
  );
  test(
    'cancel stops after the current input and preserves completed output',
    () async {
      await c.addPaths([
        for (var i = 0; i < 3; i++) writeQuiz(root, '$i.html', quizHtml()).path,
      ]);
      c.addListener(() {
        if (c.busy && c.done == 1 && !c.cancelling) c.cancel();
      });
      await c.export();
      expect(c.done, 1);
      expect(c.results.length, 1);
      expect(c.status, contains('已取消'));
      expect(c.busy, isFalse);
      expect(File(c.results.single).existsSync(), isTrue);
    },
  );
  test('removed in-flight parse cannot restore a stale selection', () async {
    final source = writeQuiz(root, 'quiz.html', quizHtml());
    var removed = false;
    c.addListener(() {
      if (!removed && c.current?.parsing == true) {
        removed = true;
        c.removeCurrent();
      }
    });
    await c.addPaths([source.path]);
    expect(removed, isTrue);
    expect(c.current, isNull);
    expect(c.entries, isEmpty);
  });
  test('settings persist and malformed settings safely return defaults', () {
    c.settings.dark = true;
    c.settings.scheme = 'teal';
    c.settings.filters = 'private';
    c.settings.reducedMotion = true;
    c.save();
    c.save();
    final loaded = c.store.load();
    expect(loaded.dark, isTrue);
    expect(loaded.scheme, 'teal');
    expect(loaded.filters, 'private');
    expect(loaded.reducedMotion, isTrue);
    c.store.file.writeAsStringSync('{broken');
    expect(c.store.load().formats, {'txt'});
  });
  test('settings saved as Canvas Exporter carry over until the first save', () {
    final legacy = p.join(root.path, 'CanvasExporter', 'settings-v2.json');
    SettingsStore(path: legacy).save(
      AppSettings()
        ..dark = true
        ..scheme = 'teal',
    );
    final store = SettingsStore(
      path: p.join(root.path, 'CanvasQuizExporter', 'settings-v2.json'),
      legacyPath: legacy,
    );
    expect(store.load().dark, isTrue);
    expect(store.load().scheme, 'teal');
    store.save(AppSettings());
    expect(store.load().dark, isFalse);
    expect(c.store.legacy, isNull, reason: 'custom paths stay isolated');
  });
}
