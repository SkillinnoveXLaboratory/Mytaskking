import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:mytaskking_core/mytaskking_core.dart';
import 'package:mytaskking_mobile/calls/mediasoup_call_session.dart';

/// Windows-only Live Desk transport. The SFU room is authorized by the backend
/// for one active remote-control session and publishes only the host display.
class LiveDeskSfuSession {
  LiveDeskSfuSession(this._realtime, {this.onCaptureEnded}) {
    _media = MediasoupCallSession()
      ..onRemoteStream = (_, stream, kind) {
        if (kind == 'video') remoteStream.value = stream;
      }
      ..onRemoteScreenShare = (_, stream) {
        remoteStream.value = stream;
      }
      ..onScreenShareEnded = () {
        unawaited(dispose());
        onCaptureEnded?.call();
      };
  }

  final BestieRealtime _realtime;
  final VoidCallback? onCaptureEnded;
  final ValueNotifier<MediaStream?> remoteStream = ValueNotifier(null);

  late final MediasoupCallSession _media;
  Timer? _heartbeat;
  String? _sessionId;

  bool get isStreaming => _media.isScreenSharing;

  Future<void> startHosting(
    String sessionId,
    Map<String, dynamic> media,
  ) async {
    await _connect(sessionId, media);
    try {
      await _media.startScreenShare();
    } catch (_) {
      await dispose();
      rethrow;
    }
  }

  Future<void> startViewing(
    String sessionId,
    Map<String, dynamic> media,
  ) =>
      _connect(sessionId, media);

  Future<void> _connect(String sessionId, Map<String, dynamic> media) async {
    await dispose();
    final connectUrl = media['connectUrl']?.toString();
    final roomId = media['roomId']?.toString();
    final userName = media['userName']?.toString();
    if (media['disabled'] == true ||
        connectUrl == null ||
        connectUrl.isEmpty ||
        roomId == null ||
        roomId.isEmpty ||
        userName == null ||
        userName.isEmpty) {
      throw StateError('Live Desk media service is unavailable.');
    }

    _sessionId = sessionId;
    _joinAndHeartbeat();
    try {
      await _media.connect(
        connectUrl: connectUrl,
        roomId: roomId,
        userName: userName,
        joinToken: media['joinToken']?.toString(),
        screenOnly: true,
      );
    } catch (_) {
      await dispose();
      rethrow;
    }
  }

  void _joinAndHeartbeat() {
    final id = _sessionId;
    if (id == null) return;
    _realtime.emit('remote.join', {'sessionId': id});
    _realtime.emit('remote.heartbeat', {'sessionId': id});
    _heartbeat = Timer.periodic(const Duration(seconds: 20), (_) {
      final currentId = _sessionId;
      if (currentId == null) return;
      // Rejoin after Socket.IO reconnects before relaying mouse control.
      _realtime.emit('remote.join', {'sessionId': currentId});
      _realtime.emit('remote.heartbeat', {'sessionId': currentId});
    });
  }

  Future<void> dispose() async {
    _heartbeat?.cancel();
    _heartbeat = null;
    _sessionId = null;
    remoteStream.value = null;
    await _media.disconnect();
  }
}
