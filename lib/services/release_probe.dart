import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:window_manager/window_manager.dart';

import '../domain/models.dart';
import 'app_controller.dart';
import 'desktop_service.dart';

/// Runs inside the packaged Windows application without driving desktop UI.
/// An explicit report path keeps the user's settings and input files untouched.
Future<void> runReleaseProbe(
  AppController controller,
  String report, {
  required int firstFrameMs,
  List<String> inputs = const [],
}) async {
  final watch = Stopwatch()..start();
  final errors = <String>[];
  final previousError = FlutterError.onError;
  FlutterError.onError = (details) => errors.add(details.exceptionAsString());
  final result = <String, dynamic>{
    'version': appVersion,
    'first_frame_ms': firstFrameMs,
  };
  try {
    result['process_first_frame_ms'] = await DesktopService.channel
        .invokeMethod<int>('processAgeMs');
    final root = Directory(p.dirname(report))..createSync(recursive: true);
    if (inputs.isEmpty) {
      final example = File(p.join(root.path, 'demo.html'))
        ..writeAsStringSync(await rootBundle.loadString('assets/demo.html'));
      inputs = [example.path];
    }
    controller.settings.formats = exportFormats.toSet();
    controller.settings.customOutput = true;
    controller.settings.outputPath = p.join(root.path, 'exports');
    controller.settings.openOnFinish = false;
    controller.settings.reducedMotion = true;
    await controller.addPaths(inputs);
    if (controller.entries.isEmpty ||
        controller.entries.any((e) => e.error != null)) {
      throw StateError(
        'Sample parse failed: ${controller.entries.map((e) => e.error).whereType<String>().join('; ')}',
      );
    }
    result['quizzes'] = controller.entries
        .map(
          (e) => {
            'questions': e.document!.questions.length,
            'images': e.document!.images.where((i) => i.available).length,
            'missing_images': e.document!.images
                .where((i) => !i.available)
                .length,
          },
        )
        .toList();
    await controller.export();
    final files = controller.results
        .where((f) => File(f).existsSync())
        .toList();
    if (files.length != controller.entries.length * exportFormats.length) {
      throw StateError(
        'Not all formats were exported: ${controller.logs.join('\n')}',
      );
    }
    result['exported_files'] = files.length;
    result['native_capabilities'] = (await controller.desktop.capabilities())
        .map((k, v) => MapEntry(k.toString(), v));
    result['drag_payload_files'] = await DesktopService.channel
        .invokeMethod<int>('verifyDragPayload', files.take(2).toList());
    if (result['drag_payload_files'] != 2) {
      throw StateError('Native file drag payload failed');
    }
    var rejected = false;
    try {
      await controller.desktop.open(p.join(root.path, 'missing-file.txt'));
    } on PlatformException {
      rejected = true;
    }
    if (!rejected) throw StateError('Native open accepted a missing file');
    await pdfrxFlutterInitialize();
    final pdfs = <Map<String, dynamic>>[];
    for (final file in files.where((f) => p.extension(f) == '.pdf')) {
      final doc = await PdfDocument.openFile(file);
      try {
        final text = StringBuffer();
        for (final page in doc.pages) {
          text.write((await page.loadText())?.fullText ?? '');
        }
        if (!text.toString().contains('Question 1')) {
          throw StateError('PDF text missing');
        }
        final image = await doc.pages.first.render(
          fullWidth: 306,
          fullHeight: 396,
        );
        if (image == null || image.pixels.isEmpty) {
          throw StateError('PDF rendering failed');
        }
        image.dispose();
        pdfs.add({
          'pages': doc.pages.length,
          'text_characters': text.length,
          'rendered': true,
        });
      } finally {
        await doc.dispose();
      }
    }
    result['pdfs'] = pdfs;
    controller.setView(true);
    await Future<void>.delayed(const Duration(seconds: 2));
    await WidgetsBinding.instance.endOfFrame;
    controller.setView(false);
    await WidgetsBinding.instance.endOfFrame;
    if (errors.isNotEmpty) throw StateError(errors.join('\n'));
    result['status'] = 'passed';
  } on Object catch (error, stack) {
    result['status'] = 'failed';
    result['error'] = error.toString();
    result['stack'] = stack.toString();
  } finally {
    result['duration_ms'] = watch.elapsedMilliseconds;
    result['framework_errors'] = errors;
    final file = File(report);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(result),
      flush: true,
    );
    FlutterError.onError = previousError;
    // Follow the same close request as the title bar; do not mask teardown
    // failures with dart:io exit(). The smoke runner verifies actual exit.
    await windowManager.close();
  }
}
