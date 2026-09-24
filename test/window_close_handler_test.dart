import 'dart:async';
import 'dart:io';

import 'package:canvas_quiz_exporter/services/app_controller.dart';
import 'package:canvas_quiz_exporter/services/desktop_service.dart';
import 'package:canvas_quiz_exporter/services/settings_store.dart';
import 'package:canvas_quiz_exporter/services/window_close_handler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support.dart';

class _CloseTestDesktop extends DesktopService {
  final opened = <String>[];
  @override
  Future<void> open(String path) async => opened.add(path);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late AppController controller;
  late _CloseTestDesktop desktop;
  setUp(() {
    root = Directory.systemTemp.createTempSync('canvas-close-');
    desktop = _CloseTestDesktop();
    controller = AppController(
      store: SettingsStore(path: p.join(root.path, 'settings.json')),
      fonts: testFonts(),
      desktop: desktop,
    );
    controller.settings.customOutput = true;
    controller.settings.outputPath = p.join(root.path, 'out');
    controller.settings.openOnFinish = false;
    controller.settings.language = 'zh';
  });
  tearDown(() {
    controller.dispose();
    root.deleteSync(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('window_manager'), null);
  });

  test(
    'idle close saves settings and uses normal native window teardown',
    () async {
      final methods = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('window_manager'), (
            call,
          ) async {
            methods.add(call);
            return null;
          });
      controller.settings.dark = true;
      final handler = WindowCloseHandler(
        controller: controller,
        confirmClose: () =>
            throw StateError('idle window needs no confirmation'),
      );
      await handler.onWindowClose();
      expect(controller.store.load().dark, isTrue);
      expect(methods.map((call) => call.method), ['setPreventClose', 'close']);
      expect(methods.first.arguments, {'isPreventClose': false});
    },
  );

  test(
    'repeated close requests wait for one confirmation and active export',
    () async {
      await controller.addPaths([
        writeQuiz(root, 'first.html', quizHtml()).path,
        writeQuiz(root, 'second.html', quizHtml()).path,
      ]);
      var closeCount = 0, confirmationCount = 0;
      final confirmed = Completer<bool>();
      final handler = WindowCloseHandler(
        controller: controller,
        confirmClose: () {
          confirmationCount++;
          return confirmed.future;
        },
        closeWindow: () async {
          expect(controller.busy, isFalse);
          expect(controller.done, 1);
          expect(File(controller.results.single).existsSync(), isTrue);
          closeCount++;
        },
      );
      unawaited(controller.export());
      final closing = handler.onWindowClose();
      await handler.onWindowClose();
      expect(confirmationCount, 1);
      expect(closeCount, 0);
      confirmed.complete(true);
      await closing;
      expect(closeCount, 1);
      expect(controller.status, contains('已取消'));
    },
  );

  test(
    'declining busy close keeps export running and permits a later close',
    () async {
      await controller.addPaths([
        writeQuiz(root, 'quiz.html', quizHtml()).path,
      ]);
      var closeCount = 0;
      final handler = WindowCloseHandler(
        controller: controller,
        confirmClose: () async => false,
        closeWindow: () async => closeCount++,
      );
      final exporting = controller.export();
      await handler.onWindowClose();
      expect(closeCount, 0);
      expect(controller.cancelling, isFalse);
      await exporting;
      await handler.onWindowClose();
      expect(closeCount, 1);
      expect(controller.results, hasLength(1));
    },
  );

  test(
    'closing during the last input does not open an output folder',
    () async {
      await controller.addPaths([
        writeQuiz(root, 'quiz.html', quizHtml()).path,
      ]);
      controller.settings.openOnFinish = true;
      var closed = false;
      final handler = WindowCloseHandler(
        controller: controller,
        confirmClose: () async => true,
        closeWindow: () async => closed = true,
      );
      unawaited(controller.export());
      await handler.onWindowClose();
      expect(closed, isTrue);
      expect(controller.results, hasLength(1));
      expect(File(controller.results.single).existsSync(), isTrue);
      expect(desktop.opened, isEmpty);
    },
  );
}
