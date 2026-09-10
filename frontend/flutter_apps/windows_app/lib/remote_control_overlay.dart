import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mytaskking_core/mytaskking_core.dart';
import 'package:mytaskking_mobile/live_desk/remote_desktop_session.dart';

import 'desktop_native.dart';

/// Host-side consent UI. The banner is intentionally always visible while a
/// session is active; it is not hidden behind the Live Desk screen.
class RemoteControlOverlay extends ConsumerStatefulWidget {
  final Widget child;
  const RemoteControlOverlay({super.key, required this.child});

  @override
  ConsumerState<RemoteControlOverlay> createState() =>
      _RemoteControlOverlayState();
}

class _RemoteControlOverlayState extends ConsumerState<RemoteControlOverlay> {
  Map<String, dynamic>? _pending;
  Map<String, dynamic>? _active;
  final List<VoidCallback> _cleanup = [];
  late final RemoteDesktopSession _desktopStream;
  bool _startingHostStream = false;
  String? _hostError;

  @override
  void initState() {
    super.initState();
    final rt = ref.read(realtimeProvider);
    _desktopStream = RemoteDesktopSession(
      rt,
      onCaptureEnded: () => unawaited(_stop()),
    );
    _cleanup.add(rt.onAny('remote.request', ([data]) {
      if (!mounted || data is! Map) return;
      setState(() => _pending = data.cast<String, dynamic>());
    }));
    _cleanup.add(rt.onAny('remote.approved', ([data]) {
      if (!mounted || data is! Map) return;
      final session = data.cast<String, dynamic>();
      if (session['hostUserId']?.toString() !=
          ref.read(authStoreProvider).user?.id) {
        return;
      }
      setState(() => _active = session);
      unawaited(_startHosting(session));
    }));
    _cleanup.add(rt.onAny('remote.stopped', ([data]) {
      if (!mounted || data is! Map) return;
      final id = data['id']?.toString();
      if (_active?['id']?.toString() == id) {
        unawaited(_desktopStream.dispose());
        setState(() => _active = null);
      }
    }));
    _cleanup.add(rt.onAny('remote.mouse', ([data]) {
      if (data is! Map || !mounted) return;
      if (_active?['id']?.toString() != data['sessionId']?.toString()) return;
      unawaited(_injectMouse(data));
    }));
  }

  @override
  void dispose() {
    for (final fn in _cleanup) {
      fn();
    }
    unawaited(_desktopStream.dispose());
    super.dispose();
  }

  Future<void> _approve() async {
    final pending = _pending;
    if (pending == null) return;
    try {
      final session =
          await ref.read(apiProvider).approveRemoteControl('${pending['id']}');
      if (mounted) {
        setState(() {
          _pending = null;
          _active = session;
        });
        await _startHosting(session);
      }
    } catch (_) {
      if (mounted) setState(() => _pending = null);
    }
  }

  Future<void> _stop() async {
    final active = _active;
    if (active == null) return;
    await _desktopStream.dispose();
    await ref.read(apiProvider).stopRemoteControl('${active['id']}');
    if (mounted) setState(() => _active = null);
  }

  Future<void> _startHosting(Map<String, dynamic> session) async {
    if (_startingHostStream || _desktopStream.isStreaming) return;
    _startingHostStream = true;
    try {
      await _desktopStream.startHosting('${session['id']}');
    } catch (error) {
      await ref.read(apiProvider).stopRemoteControl('${session['id']}');
      if (mounted) {
        setState(() {
          _active = null;
          _hostError =
              'Screen sharing could not start. Check Windows screen-capture permissions and try again. ($error)';
        });
      }
    } finally {
      _startingHostStream = false;
    }
  }

  Future<void> _injectMouse(Map data) async {
    try {
      await DesktopNative.injectRemoteMouse(
        x: (data['x'] as num?)?.toDouble() ?? 0.5,
        y: (data['y'] as num?)?.toDouble() ?? 0.5,
        action: data['action']?.toString() ?? 'move',
        button: (data['button'] as num?)?.toInt() ?? 0,
        delta: (data['delta'] as num?)?.toInt() ?? 0,
      );
    } catch (error) {
      if (mounted) {
        setState(() => _hostError = 'Remote mouse control failed: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _pending;
    final active = _active;
    return Stack(children: [
      widget.child,
      if (_hostError != null)
        Positioned(
          top: 70,
          left: 24,
          right: 24,
          child: MaterialBanner(
            content: Text(_hostError!),
            actions: [
              TextButton(
                onPressed: () => setState(() => _hostError = null),
                child: const Text('DISMISS'),
              ),
            ],
          ),
        ),
      if (active != null)
        Positioned(
            top: 12,
            left: 24,
            right: 24,
            child: Material(
              elevation: 8,
              color: Colors.red.shade700,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(children: [
                    const Icon(Icons.screen_lock_portrait, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(
                            'Remote control active: ${active['controllerUserId'] ?? 'authorized controller'}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700))),
                    TextButton(
                        onPressed: _stop,
                        child: const Text('STOP SESSION',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800))),
                  ])),
            )),
      if (pending != null)
        Positioned(
            right: 34,
            bottom: 34,
            child: Card(
              elevation: 12,
              child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Remote-control request',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        const Text(
                            'A controller wants to view and control this computer.'),
                        const SizedBox(height: 14),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          OutlinedButton(
                              onPressed: () => setState(() => _pending = null),
                              child: const Text('Reject')),
                          const SizedBox(width: 8),
                          FilledButton(
                              onPressed: _approve, child: const Text('Allow')),
                        ]),
                      ])),
            )),
    ]);
  }
}
