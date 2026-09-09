import 'dart:io';

import 'package:flutter/services.dart';

class DesktopNative {
  static const MethodChannel _channel = MethodChannel('mytaskking/desktop');

  static bool get isSupported => Platform.isMacOS;

  static Future<String?> showWorkActivityPrompt({
    required int seconds,
  }) async {
    if (!isSupported) return null;
    return _channel.invokeMethod<String>('showWorkActivityPrompt', {
      'seconds': seconds,
    });
  }

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
      throw UnsupportedError('Native desktop capture is macOS-only here.');
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

  /// Injects one approved mouse action. macOS requires the user to grant this
  /// app Accessibility permission before it can post system input events.
  static Future<void> injectRemoteMouse({
    required double x,
    required double y,
    required String action,
    int button = 0,
    int delta = 0,
  }) async {
    if (!isSupported) throw UnsupportedError('Remote mouse is macOS-only.');
    await _channel.invokeMethod<void>('injectRemoteMouse', {
      'x': x.clamp(0, 1),
      'y': y.clamp(0, 1),
      'action': action,
      'button': button,
      'delta': delta,
    });
  }
}
