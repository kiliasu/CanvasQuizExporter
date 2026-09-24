import 'package:flutter/services.dart';

class DesktopService {
  static const channel = MethodChannel('canvas_quiz_exporter/windows');
  Future<void> open(String path) =>
      channel.invokeMethod<void>('openPath', path);
  Future<void> drag(List<String> paths) =>
      channel.invokeMethod<void>('dragFiles', paths);
  Future<Map<Object?, Object?>> capabilities() async =>
      (await channel.invokeMapMethod<Object?, Object?>('capabilities')) ?? {};
}
