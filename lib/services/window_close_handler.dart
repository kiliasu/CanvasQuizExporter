import 'package:window_manager/window_manager.dart';

import 'app_controller.dart';

/// Serializes close requests and lets the current export finish safely.
class WindowCloseHandler with WindowListener {
  final AppController controller;
  final Future<bool> Function() confirmClose;
  final Future<void> Function() closeWindow;
  bool _closing = false;

  WindowCloseHandler({
    required this.controller,
    required this.confirmClose,
    this.closeWindow = closeNativeWindow,
  });

  @override
  Future<void> onWindowClose() async {
    if (_closing) return;
    _closing = true;
    try {
      if (controller.busy) {
        if (!await confirmClose()) {
          _closing = false;
          return;
        }
        controller.cancel();
        await controller.exportFuture;
      }
      controller.save();
      await closeWindow();
    } on Object catch (error) {
      _closing = false;
      controller.tell(controller.strings.cannotCloseWindow(error), error: true);
    }
  }
}

Future<void> closeNativeWindow() async {
  // destroy() only posts WM_QUIT on Windows, skipping normal window teardown.
  // Let WM_CLOSE destroy the window while its message loop and COM are alive.
  await windowManager.setPreventClose(false);
  await windowManager.close();
}
