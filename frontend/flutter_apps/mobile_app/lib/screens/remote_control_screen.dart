import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mytaskking_core/mytaskking_core.dart';

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

  @override
  void initState() {
    super.initState();
    final rt = ref.read(realtimeProvider);
    _offApproved = rt.onAny('remote.approved', (data) {
      if (mounted && data is Map) {
        final session = data.cast<String, dynamic>();
        setState(() {
          _session = session;
          _message = 'Host approved the session.';
        });
        rt.emit('remote.join', {'sessionId': session['id']});
      }
    });
    _offStopped = rt.onAny('remote.stopped', (data) {
      if (mounted)
        setState(() {
          _session = null;
          _message = 'Remote session stopped.';
        });
    });
  }

  @override
  void dispose() {
    _offApproved?.call();
    _offStopped?.call();
    _computerId.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    try {
      final session = await ref
          .read(apiProvider)
          .requestRemoteControl(computerId: _computerId.text.trim());
      if (mounted)
        setState(() {
          _session = session;
          _message = 'Waiting for the Windows user to approve.';
        });
    } catch (e) {
      if (mounted) setState(() => _message = 'Request failed: $e');
    }
  }

  Future<void> _stop() async {
    final id = _session?['id']?.toString();
    if (id == null) return;
    await ref.read(apiProvider).stopRemoteControl(id);
    if (mounted)
      setState(() {
        _session = null;
        _message = 'Remote session stopped.';
      });
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
                      child: Text(
                        active
                            ? 'Live screen stream will appear here'
                            : 'Approve a session to begin',
                        style: const TextStyle(color: Colors.white),
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
