import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:window_manager/window_manager.dart';

import '../domain/models.dart';
import 'app_controller.dart';
import 'window_close_handler.dart';

/// Exercises the same close handler without interacting with the desktop.
/// The supervising process only passes the check after this process exits.
Future<void> runCloseProbe(
  AppController controller,
  String report,
  String mode,
) async {
  final result = <String, dynamic>{'mode': mode, 'status': 'started'};
  final reportFile = File(report);
  reportFile.parent.createSync(recursive: true);
  void writeReport() => reportFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(result),
    flush: true,
  );
  final errors = <String>[];
  FlutterError.onError = (details) => errors.add(details.exceptionAsString());
  writeReport();
  var confirmations = 0;
  final handler = WindowCloseHandler(
    controller: controller,
    confirmClose: () async {
      confirmations++;
      return true;
    },
    closeWindow: () async {
      result.addAll({
        'status': result['status'] == 'failed' ? 'failed' : 'ready-to-close',
        'close_requested_at': DateTime.now().toUtc().toIso8601String(),
        'close_requested_ms': DateTime.now().millisecondsSinceEpoch,
        'confirmations': confirmations,
        'busy': controller.busy,
        'completed_inputs': controller.done,
        'exported_files': controller.results.length,
        'saved_settings': controller.store.file.existsSync(),
        'framework_errors': errors,
      });
      writeReport();
      await closeNativeWindow();
    },
  );
  windowManager.addListener(handler);
  try {
    if (mode == 'export' || mode == 'pdf') {
      final html = await rootBundle.loadString('assets/demo.html');
      final paths = [
        for (var i = 0; i < 2; i++)
          (File(
            p.join(reportFile.parent.path, 'quiz-$i.html'),
          )..writeAsStringSync(html)).path,
      ];
      await controller.addPaths(paths);
      controller.settings.formats = exportFormats.toSet();
      controller.settings.customOutput = true;
      controller.settings.outputPath = p.join(
        reportFile.parent.path,
        'exports',
      );
      controller.settings.openOnFinish = false;
      if (mode == 'export') {
        unawaited(controller.export());
        // Enter while export is definitely busy, before the small fixture can
        // finish. The handler still performs the real native window close.
        await handler.onWindowClose();
        return;
      } else {
        controller.setView(true);
        result['pdf_preview'] = await _waitForRenderedPdf();
      }
    }
    await windowManager.close();
  } on Object catch (error) {
    result.addAll({'status': 'failed', 'error': error.toString()});
    writeReport();
    await closeNativeWindow();
  }
}

Future<Map<String, int>> _waitForRenderedPdf() async {
  final waiting = Stopwatch()..start();
  while (waiting.elapsed < const Duration(seconds: 10)) {
    await WidgetsBinding.instance.endOfFrame;
    Map<String, int>? preview;
    void visit(Element element) {
      final widget = element.widget;
      if (widget is PdfPageView && widget.document != null) {
        void findPageImage(Element child) {
          final imageWidget = child.widget;
          if (imageWidget is RawImage && imageWidget.image != null) {
            final image = imageWidget.image!;
            if (image.width > 0 && image.height > 0) {
              preview = {
                'pages': widget.document!.pages.length,
                'pixel_width': image.width,
                'pixel_height': image.height,
              };
            }
          }
          child.visitChildElements(findPageImage);
        }

        // Check the actual page image in the mounted preview. Leave its
        // document and image alive so native close exercises their teardown.
        element.visitChildElements(findPageImage);
      }
      element.visitChildElements(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildElements(visit);
    if (preview != null) return preview!;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw StateError('PDF preview did not load and render before close.');
}
