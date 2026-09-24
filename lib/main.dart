import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:path/path.dart' as p;

import 'domain/exporter.dart';
import 'l10n/localizations.dart';
import 'services/app_controller.dart';
import 'services/settings_store.dart';
import 'services/release_probe.dart';
import 'services/close_probe.dart';
import 'ui/app_theme.dart';
import 'ui/workspace.dart';

Future<void> main(List<String> args) async {
  final startup = Stopwatch()..start();
  WidgetsFlutterBinding.ensureInitialized();
  final probe = args.length >= 2 && args.first == '--self-test'
      ? p.absolute(args[1])
      : null;
  final closeProbe = args.length >= 3 && args.first == '--close-test'
      ? p.absolute(args[1])
      : null;
  final isolatedReport = probe ?? closeProbe;
  final fontData = await Future.wait(
    [
      'assets/fonts/pdf/noto-sans-sc-regular.ttf',
      'assets/fonts/pdf/noto-sans-sc-bold.ttf',
      'assets/fonts/pdf/roboto-flex-regular.ttf',
      'assets/fonts/pdf/roboto-flex-bold.ttf',
    ].map(rootBundle.load),
  );
  final controller = AppController(
    store: SettingsStore(
      path: isolatedReport == null
          ? null
          : p.join(p.dirname(isolatedReport), 'probe-settings.json'),
    ),
    fonts: PdfFonts(
      fontData[0].buffer.asUint8List(),
      fontData[1].buffer.asUint8List(),
      fontData[2].buffer.asUint8List(),
      fontData[3].buffer.asUint8List(),
    ),
  );
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    await windowManager.setMinimumSize(const Size(1080, 720));
    await windowManager.setPreventClose(true);
    await windowManager.setTitle('Canvas Quiz Exporter');
  }
  runApp(CanvasApp(controller: controller, nativeWindow: closeProbe == null));
  if (closeProbe != null) {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => runCloseProbe(controller, closeProbe, args[2]),
    );
  } else if (probe != null) {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => runReleaseProbe(
        controller,
        probe,
        inputs: args.skip(2).toList(),
        firstFrameMs: startup.elapsedMilliseconds,
      ),
    );
  } else if (args.isNotEmpty) {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => controller.addPaths(args),
    );
  }
}

class CanvasApp extends StatelessWidget {
  final AppController controller;
  final bool nativeWindow;
  const CanvasApp({
    super.key,
    required this.controller,
    this.nativeWindow = true,
  });

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Canvas Quiz Exporter',
      locale: Locale(controller.language),
      supportedLocales: supportedLocales,
      localizationsDelegates: localizationsDelegates,
      theme: appTheme(controller.settings.dark, controller.settings.scheme),
      themeAnimationDuration: Duration(
        milliseconds: controller.settings.reducedMotion ? 0 : 250,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations:
              controller.settings.reducedMotion ||
              MediaQuery.disableAnimationsOf(context),
        ),
        child: child!,
      ),
      home: Workspace(controller: controller, nativeWindow: nativeWindow),
    ),
  );
}
