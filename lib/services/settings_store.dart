import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/models.dart';

class SettingsStore {
  final File file;

  /// Settings saved under the app's former name, Canvas Exporter. They are
  /// read until settings are first saved to [file]. Custom locations (tests,
  /// self-tests) never pick up the user's settings.
  final File? legacy;

  SettingsStore({String? path, String? legacyPath})
    : file = File(path ?? _custom ?? _inAppData('CanvasQuizExporter')),
      legacy = legacyPath != null
          ? File(legacyPath)
          : path == null && _custom == null
          ? File(_inAppData('CanvasExporter'))
          : null;

  static String? get _custom =>
      Platform.environment['CANVAS_QUIZ_EXPORTER_CONFIG'];

  static String _inAppData(String folder) => p.join(
    Platform.environment['APPDATA'] ?? Directory.current.path,
    folder,
    'settings-v2.json',
  );

  AppSettings load() {
    final source = file.existsSync() ? file : legacy;
    if (source == null || !source.existsSync()) return AppSettings();
    try {
      return AppSettings.fromJson(
        jsonDecode(source.readAsStringSync()) as Map<String, dynamic>,
      );
    } on Object {
      return AppSettings();
    }
  }

  void save(AppSettings settings) {
    file.parent.createSync(recursive: true);
    final temporary = File('${file.path}.tmp');
    temporary.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(settings.toJson()),
      flush: true,
    );
    temporary.renameSync(file.path);
  }
}
