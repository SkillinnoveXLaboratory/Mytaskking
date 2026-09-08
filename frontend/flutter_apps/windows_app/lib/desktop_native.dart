import 'dart:io';

import 'package:flutter/services.dart';

class DesktopNative {
  static const MethodChannel _channel = MethodChannel('mytaskking/desktop');

  static bool get isSupported => Platform.isWindows;

  static Future<String?> showWorkActivityPrompt({
    required int seconds,
  }) async {
    if (!isSupported) return null;
    return _channel.invokeMethod<String>('showWorkActivityPrompt', {
      'seconds': seconds,
    });
  }

  /// Seconds since last keyboard or mouse input anywhere on the system.
  /// Windows only; returns 0 on other platforms.
  static Future<int> getIdleSeconds() async {
    if (!isSupported) return 0;
    final value = await _channel.invokeMethod<int>('getIdleSeconds');
    return value ?? 0;
  }

  static Future<List<File>> captureFrames({
    required int frameCount,
    required int delayMs,
    int maxWidth = 1280,
  }) async {
    if (!isSupported) {
      throw UnsupportedError('Native desktop capture is Windows-only.');
    }
    final paths = await _channel.invokeListMethod<String>('captureFrames', {
      'frameCount': frameCount,
      'delayMs': delayMs,
      'maxWidth': maxWidth,
    });
    final files = (paths ?? const <String>[]).map(File.new).toList();
    if (files.isEmpty) {
      throw StateError('Native desktop capture produced no files.');
    }
    return files;
  }

  /// Injects one approved remote mouse action. Coordinates are normalized
  /// screen coordinates (0..1) so the controller is resolution-independent.
  static Future<void> injectRemoteMouse({
    required double x,
    required double y,
    required String action,
    int button = 0,
    int delta = 0,
  }) async {
    if (!isSupported) throw UnsupportedError('Remote mouse is Windows-only.');
    await _channel.invokeMethod<void>('injectRemoteMouse', {
      'x': x.clamp(0, 1),
      'y': y.clamp(0, 1),
      'action': action,
      'button': button,
      'delta': delta,
    });
  }
}
