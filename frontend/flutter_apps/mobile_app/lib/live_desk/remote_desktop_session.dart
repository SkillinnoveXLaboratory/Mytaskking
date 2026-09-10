import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:mytaskking_core/mytaskking_core.dart';

/// A one-to-one, consented desktop stream. The backend authorizes and relays
/// only signaling; desktop frames travel directly between the approved peers.
class RemoteDesktopSession {
  RemoteDesktopSession(this._realtime, {this.onCaptureEnded});

  final BestieRealtime _realtime;
  final VoidCallback? onCaptureEnded;
  final ValueNotifier<MediaStream?> remoteStream = ValueNotifier(null);
  final List<RTCIceCandidate> _pendingCandidates = [];
  final List<void Function()> _cleanup = [];

  RTCPeerConnection? _peer;
  MediaStream? _displayStream;
  String? _sessionId;
  Timer? _viewerReadyRetry;
  bool _hosting = false;
  bool _offerSent = false;
  bool _viewerReady = false;

  bool get isHosting => _hosting;
  bool get isStreaming => _displayStream != null;

  Future<void> startHosting(String sessionId) async {
    await dispose();
    _sessionId = sessionId;
    _hosting = true;
    _listen();
    _peer = await _createPeer();
    _join();

    // This runs directly from the host's Allow action, so macOS can show its
    // system Screen Recording picker/permission prompt with clear intent.
    try {
      _displayStream = await navigator.mediaDevices.getDisplayMedia({
        'video': {
          'mandatory': {
            'minWidth': '640',
            'minHeight': '480',
            'minFrameRate': '8',
          },
        },
        'audio': false,
      });
      final tracks = _displayStream!.getVideoTracks();
      if (tracks.isEmpty) {
        throw StateError('Screen sharing returned no video track.');
      }
      for (final track in tracks) {
        track.onEnded = () {
          unawaited(dispose());
          onCaptureEnded?.call();
        };
        await _peer!.addTrack(track, _displayStream!);
      }
      if (_viewerReady) await _sendOffer();
    } catch (_) {
      await dispose();
      rethrow;
    }
  }

  Future<void> startViewing(String sessionId) async {
    await dispose();
    _sessionId = sessionId;
    _hosting = false;
    _listen();
    _peer = await _createPeer();
    _join();
    // A room join is asynchronous on the server. Retry briefly so the host
    // receives this even when it is still opening the macOS capture picker.
    _notifyViewerReady();
    _viewerReadyRetry = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_sessionId == null || _hosting || remoteStream.value != null) {
        _viewerReadyRetry?.cancel();
        return;
      }
      _notifyViewerReady();
    });
  }

  void _listen() {
    _cleanup.add(_realtime.onAny('remote.signal', ([data]) {
      if (data is! Map) return;
      final event = data.cast<String, dynamic>();
      if (event['sessionId']?.toString() != _sessionId) return;
      final payload = event['payload'];
      if (payload is Map) {
        unawaited(_handleSignal(payload.cast<String, dynamic>()));
      }
    }));
    _cleanup.add(_realtime.onAny('remote.viewer-ready', ([data]) {
      if (!_hosting || data is! Map) return;
      if (data['sessionId']?.toString() != _sessionId) return;
      _viewerReady = true;
      unawaited(_sendOffer());
    }));
  }

  Future<RTCPeerConnection> _createPeer() async {
    final peer = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan',
    });
    peer.onIceCandidate = (candidate) {
      if (candidate.candidate == null || candidate.candidate!.isEmpty) return;
      _sendSignal({'kind': 'candidate', ...candidate.toMap()});
    };
    peer.onTrack = (event) {
      if (event.streams.isNotEmpty) remoteStream.value = event.streams.first;
    };
    return peer;
  }

  void _join() => _realtime.emit('remote.join', {'sessionId': _sessionId});

  void _notifyViewerReady() {
    final sessionId = _sessionId;
    if (sessionId != null) {
      _realtime.emit('remote.viewer-ready', {'sessionId': sessionId});
    }
  }

  void _sendSignal(Map<String, dynamic> payload) {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    _realtime
        .emit('remote.signal', {'sessionId': sessionId, 'payload': payload});
  }

  Future<void> _sendOffer() async {
    if (_offerSent || _peer == null || _displayStream == null) return;
    _offerSent = true;
    final offer = await _peer!.createOffer();
    await _peer!.setLocalDescription(offer);
    _sendSignal({'kind': 'offer', 'type': offer.type, 'sdp': offer.sdp});
  }

  Future<void> _handleSignal(Map<String, dynamic> payload) async {
    final peer = _peer;
    if (peer == null) return;
    switch (payload['kind']) {
      case 'offer':
        if (_hosting) return;
        final sdp = payload['sdp']?.toString();
        final type = payload['type']?.toString() ?? 'offer';
        if (sdp == null || sdp.isEmpty) return;
        await peer.setRemoteDescription(RTCSessionDescription(sdp, type));
        await _flushCandidates(peer);
        final answer = await peer.createAnswer();
        await peer.setLocalDescription(answer);
        _sendSignal({'kind': 'answer', 'type': answer.type, 'sdp': answer.sdp});
      case 'answer':
        if (!_hosting) return;
        final sdp = payload['sdp']?.toString();
        final type = payload['type']?.toString() ?? 'answer';
        if (sdp == null || sdp.isEmpty) return;
        await peer.setRemoteDescription(RTCSessionDescription(sdp, type));
        await _flushCandidates(peer);
      case 'candidate':
        final candidate = payload['candidate']?.toString();
        if (candidate == null || candidate.isEmpty) return;
        final ice = RTCIceCandidate(
          candidate,
          payload['sdpMid']?.toString(),
          (payload['sdpMLineIndex'] as num?)?.toInt(),
        );
        if (await peer.getRemoteDescription() == null) {
          _pendingCandidates.add(ice);
        } else {
          await peer.addCandidate(ice);
        }
    }
  }

  Future<void> _flushCandidates(RTCPeerConnection peer) async {
    for (final candidate in List<RTCIceCandidate>.from(_pendingCandidates)) {
      await peer.addCandidate(candidate);
    }
    _pendingCandidates.clear();
  }

  Future<void> dispose() async {
    for (final remove in _cleanup) {
      remove();
    }
    _cleanup.clear();
    _viewerReadyRetry?.cancel();
    _viewerReadyRetry = null;
    _pendingCandidates.clear();
    remoteStream.value = null;
    final display = _displayStream;
    _displayStream = null;
    if (display != null) {
      for (final track in display.getTracks()) {
        // Do not treat our own explicit teardown as a user-ended capture.
        track.onEnded = null;
        await track.stop();
      }
      await display.dispose();
    }
    await _peer?.close();
    _peer = null;
    _sessionId = null;
    _hosting = false;
    _offerSent = false;
    _viewerReady = false;
  }
}
