import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:mytaskking_core/mytaskking_core.dart';
import 'package:mytaskking_mobile/live_desk/remote_desktop_session.dart';

class RemoteControlScreen extends ConsumerStatefulWidget {
  const RemoteControlScreen({super.key});

  @override
  ConsumerState<RemoteControlScreen> createState() =>
      _RemoteControlScreenState();
}

class _RemoteControlScreenState extends ConsumerState<RemoteControlScreen> {
  final _computerId = TextEditingController();
  Map<String, dynamic>? _session;
  String? _message;
  VoidCallback? _offApproved;
  VoidCallback? _offStopped;
  late final RemoteDesktopSession _desktopStream;
  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  Timer? _recovery;
  bool _rendererReady = false;
  bool _startingViewer = false;

  @override
  void initState() {
    super.initState();
    final rt = ref.read(realtimeProvider);
    _desktopStream = RemoteDesktopSession(rt);
    _desktopStream.remoteStream.addListener(_bindRemoteStream);
    unawaited(_initializeRenderer());
    _offApproved = rt.onAny('remote.approved', ([data]) {
      if (mounted && data is Map) {
        final session = data.cast<String, dynamic>();
        if (session['controllerUserId']?.toString() !=
            ref.read(authStoreProvider).user?.id) {
          return;
        }
        setState(() {
          _session = session;
          _message = 'Host approved the session.';
        });
        unawaited(_startViewing(session));
      }
    });
    unawaited(_recoverActiveSession());
    _recovery = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(_recoverActiveSession()),
    );
    _offStopped = rt.onAny('remote.stopped', ([data]) {
      if (mounted) {
        unawaited(_desktopStream.dispose());
        if (_rendererReady) _renderer.srcObject = null;
        setState(() {
          _session = null;
          _message = 'Remote session stopped.';
        });
      }
    });
  }

  @override
  void dispose() {
    _offApproved?.call();
    _offStopped?.call();
    _recovery?.cancel();
    _desktopStream.remoteStream.removeListener(_bindRemoteStream);
    unawaited(_desktopStream.dispose());
    unawaited(_renderer.dispose());
    _computerId.dispose();
    super.dispose();
  }

  Future<void> _initializeRenderer() async {
    try {
      await _renderer.initialize();
      if (!mounted) {
        await _renderer.dispose();
        return;
      }
      _rendererReady = true;
      _bindRemoteStream();
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = 'Could not initialize the live viewer: $error',
        );
      }
    }
  }

  void _bindRemoteStream() {
    if (!_rendererReady) {
      return;
    }
    _renderer.srcObject = _desktopStream.remoteStream.value;
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _startViewing(Map<String, dynamic> session) async {
    if (_startingViewer || _desktopStream.isHosting) {
      return;
    }
    _startingViewer = true;
    try {
      await _desktopStream.startViewing('${session['id']}');
      if (mounted) {
        setState(() => _message = 'Connecting to the live screen...');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'Could not start the live viewer: $error');
      }
    } finally {
      _startingViewer = false;
    }
  }

  Future<void> _recoverActiveSession() async {
    try {
      final response = await ref.read(apiProvider).remoteControlSessions();
      final userId = ref.read(authStoreProvider).user?.id;
      final sessions = ((response['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>());
      final active = sessions.where(
        (item) =>
            item['status'] == 'ACTIVE' &&
            item['controllerUserId']?.toString() == userId,
      );
      if (active.isEmpty || !mounted) {
        return;
      }
      final session = active.first;
      if (_session?['id']?.toString() != session['id']?.toString()) {
        setState(() => _session = session);
        await _startViewing(session);
      }
    } catch (_) {
      // A temporary API failure should not tear down an already live stream.
    }
  }

  Future<void> _request() async {
    try {
      final session = await ref
          .read(apiProvider)
          .requestRemoteControl(computerId: _computerId.text.trim());
      if (mounted) {
        setState(() {
          _session = session;
          _message = 'Waiting for the Windows user to approve.';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _message = 'Request failed: $e');
    }
  }

  Future<void> _stop() async {
    final id = _session?['id']?.toString();
    if (id == null) {
      return;
    }
    await ref.read(apiProvider).stopRemoteControl(id);
    await _desktopStream.dispose();
    if (_rendererReady) {
      _renderer.srcObject = null;
    }
    if (mounted) {
      setState(() {
        _session = null;
        _message = 'Remote session stopped.';
      });
    }
  }

  void _mouse(Offset local, Size size, String action) {
    final id = _session?['id']?.toString();
    if (id == null || _session?['status'] != 'ACTIVE') return;
    ref.read(realtimeProvider).emit('remote.mouse', {
      'sessionId': id,
      'x': (local.dx / size.width).clamp(0.0, 1.0),
      'y': (local.dy / size.height).clamp(0.0, 1.0),
      'action': action,
      'button': 0,
    });
  }

  @override
  Widget build(BuildContext context) {
    final active = _session?['status'] == 'ACTIVE';
    return Scaffold(
      appBar: AppBar(title: const Text('Live Desk')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _computerId,
              decoration: const InputDecoration(labelText: 'Computer ID'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton(
                  onPressed: active ? null : _request,
                  child: const Text('Request access'),
                ),
                const SizedBox(width: 10),
                if (_session != null)
                  OutlinedButton(onPressed: _stop, child: const Text('Stop')),
              ],
            ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_message!),
              ),
            const SizedBox(height: 20),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  return GestureDetector(
                    onTapDown: (d) => _mouse(d.localPosition, size, 'click'),
                    onPanUpdate: (d) => _mouse(d.localPosition, size, 'move'),
                    child: Container(
                      width: double.infinity,
                      color: Colors.black87,
                      alignment: Alignment.center,
                      child: _renderer.srcObject == null
                          ? Text(
                              active
                                  ? 'Waiting for the host screen...'
                                  : 'Approve a session to begin',
                              style: const TextStyle(color: Colors.white),
                            )
                          : RTCVideoView(
                              _renderer,
                              objectFit: RTCVideoViewObjectFit
                                  .RTCVideoViewObjectFitContain,
                            ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
