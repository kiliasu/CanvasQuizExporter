import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:canvas_quiz_exporter/main.dart';
import 'package:canvas_quiz_exporter/domain/exporter.dart';
import 'package:canvas_quiz_exporter/domain/parser.dart';
import 'package:canvas_quiz_exporter/services/app_controller.dart';
import 'package:canvas_quiz_exporter/services/settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Documentation images rendered by Flutter itself from the public fixture.
/// Release builds pass PREVIEW_ASSETS so this loads the fonts actually shipped.
/// This does not capture or operate a desktop window.
void main() {
  testWidgets('render public light and dark documentation previews', (
    tester,
  ) async {
    await tester.runAsync(() async {
      const previewAssets = String.fromEnvironment('PREVIEW_ASSETS');
      final manifest = jsonDecode(
        previewAssets.isEmpty
            ? await rootBundle.loadString('FontManifest.json')
            : await File('$previewAssets/FontManifest.json').readAsString(),
      ) as List;
      for (final family in manifest) {
        final loader = FontLoader(family['family'] as String);
        for (final font in family['fonts'] as List) {
          final asset = font['asset'] as String;
          loader.addFont(
            previewAssets.isEmpty
                ? rootBundle.load(asset)
                : File('$previewAssets/$asset')
                      .readAsBytes()
                      .then(ByteData.sublistView),
          );
        }
        await loader.load();
      }
    });
    final previousShadows = debugDisableShadows;
    debugDisableShadows = false;
    try {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 920);
      final temp = Directory.systemTemp.createTempSync('canvas-preview-');
      final controller = AppController(
        store: SettingsStore(path: '${temp.path}/settings.json'),
        fonts: PdfFonts(
          File('assets/fonts/pdf/noto-sans-sc-regular.ttf').readAsBytesSync(),
          File('assets/fonts/pdf/noto-sans-sc-bold.ttf').readAsBytesSync(),
          File('assets/fonts/pdf/roboto-flex-regular.ttf').readAsBytesSync(),
          File('assets/fonts/pdf/roboto-flex-bold.ttf').readAsBytesSync(),
        ),
      );
      final entry = QueueEntry(File('assets/demo.html').absolute.path)
        ..document = parseQuiz('assets/demo.html');
      controller.settings.reducedMotion = true;
      final boundary = GlobalKey();
      Future<void> capture(String path) => tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File(path)..parent.createSync(recursive: true);
        file.writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
      // Chinese images keep their names; English ones end in -en.
      for (final language in ['zh', 'en']) {
        final suffix = language == 'zh' ? '' : '-en';
        controller.settings.language = language;
        controller.entries.add(entry);
        controller.current = entry;
        for (final dark in [false, true]) {
          final theme = dark ? 'dark' : 'light';
          tester.view.physicalSize = const Size(1440, 920);
          controller.settings.dark = dark;
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: CanvasApp(controller: controller, nativeWindow: false),
            ),
          );
          controller.changed();
          await tester.pumpAndSettle();
          await capture('docs/images/flutter-$theme$suffix.png');
          expect(tester.takeException(), isNull);
          controller.tell(
            controller.strings.copiedAllQuestions(
              entry.document!.questions.length,
            ),
          );
          await tester.pumpAndSettle();
          await capture('build/previews/flutter-toast-$theme$suffix.png');
          await tester.tap(find.byKey(const ValueKey('reference-toast')));
          await tester.pumpAndSettle();
          tester.view.physicalSize = const Size(1080, 720);
          await tester.pumpAndSettle();
          if (!dark) await capture('build/previews/flutter-minimum$suffix.png');
          expect(tester.takeException(), isNull);
        }
        tester.view.physicalSize = const Size(1440, 920);
        controller.settings.dark = false;
        controller.clear();
        await tester.pumpAndSettle();
        await capture('build/previews/flutter-empty$suffix.png');
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      temp.deleteSync(recursive: true);
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    } finally {
      debugDisableShadows = previousShadows;
    }
  });
}
