import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:mytaskking_core/mytaskking_core.dart';
import 'package:mytaskking_mobile/live_desk/remote_desktop_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LiveDeskScreen extends ConsumerStatefulWidget {
  const LiveDeskScreen({super.key});

  @override
  ConsumerState<LiveDeskScreen> createState() => _LiveDeskScreenState();
}

class _LiveDeskScreenState extends ConsumerState<LiveDeskScreen> {
  final _connectComputerId = TextEditingController();
  final _computerId = TextEditingController();
  final _computerName = TextEditingController(text: 'My Laptop');
  final _computerNameFocus = FocusNode();
  Timer? _refresh;
  List<Map<String, dynamic>> _sessions = [];
  Map<String, dynamic>? _hostComputer;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _viewingSession;
  late final RemoteDesktopSession _desktopStream;
  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  VoidCallback? _offApproved;
  VoidCallback? _offStopped;
  bool _rendererReady = false;
  late final Future<String> _localComputerIdFuture;

  static const _computerIdStoragePrefix = 'live_desk.windows.computer_id.';
  static const _idAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  @override
  void initState() {
    super.initState();
    _localComputerIdFuture = _localComputerId();
    _desktopStream = RemoteDesktopSession(ref.read(realtimeProvider));
    _desktopStream.remoteStream.addListener(_bindRemoteStream);
    unawaited(_initializeRenderer());
    final rt = ref.read(realtimeProvider);
    _offApproved = rt.onAny('remote.approved', ([data]) {
      if (data is! Map) return;
      final session = data.cast<String, dynamic>();
      if (session['controllerUserId']?.toString() ==
          ref.read(authStoreProvider).user?.id) {
        unawaited(_startViewing(session));
      }
    });
    _offStopped = rt.onAny('remote.stopped', ([data]) {
      if (data is! Map ||
          data['id']?.toString() != _viewingSession?['id']?.toString()) {
        return;
      }
      unawaited(_stopViewing());
    });
    _load();
    _refresh = Timer.periodic(const Duration(seconds: 8), (_) => _load());
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _offApproved?.call();
    _offStopped?.call();
    _desktopStream.remoteStream.removeListener(_bindRemoteStream);
    unawaited(_desktopStream.dispose());
    unawaited(_renderer.dispose());
    _connectComputerId.dispose();
    _computerId.dispose();
    _computerName.dispose();
    _computerNameFocus.dispose();
    super.dispose();
  }

  void _bindRemoteStream() {
    if (!_rendererReady) return;
    _renderer.srcObject = _desktopStream.remoteStream.value;
    if (mounted) setState(() {});
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
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = 'Could not initialize the live-screen viewer: $e',
        );
      }
    }
  }

  Future<void> _startViewing(Map<String, dynamic> session) async {
    setState(() {
      _viewingSession = session;
      _error = null;
    });
    try {
      await _desktopStream.startViewing('${session['id']}');
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not start live stream: $e');
    }
  }

  Future<void> _stopViewing() async {
    await _desktopStream.dispose();
    if (_rendererReady) _renderer.srcObject = null;
    if (mounted) setState(() => _viewingSession = null);
  }

  void _sendMouse(Offset localPosition, Size size, String action) {
    final sessionId = _viewingSession?['id']?.toString();
    if (sessionId == null || size.isEmpty) return;
    ref.read(realtimeProvider).emit('remote.mouse', {
      'sessionId': sessionId,
      'x': (localPosition.dx / size.width).clamp(0.0, 1.0),
      'y': (localPosition.dy / size.height).clamp(0.0, 1.0),
      'action': action,
      'button': 0,
    });
  }

  Future<void> _load() async {
    try {
      final localComputerId = await _localComputerIdFuture;
      final results = await Future.wait([
        ref.read(apiProvider).remoteControlSessions(),
        ref.read(apiProvider).remoteComputers(platform: 'WINDOWS'),
      ]);
      final sessionData = results[0];
      final computerData = results[1];
      final computers = ((computerData['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList();
      final host = computers.isEmpty ? null : computers.first;
      if (!mounted) return;
      if (host != null && !_computerNameFocus.hasFocus) {
        _computerId.text = '${host['computerId'] ?? ''}';
        _computerName.text = '${host['computerName'] ?? ''}';
      } else if (_computerId.text.isEmpty) {
        _computerId.text = localComputerId;
      }
      setState(() {
        _sessions = ((sessionData['items'] as List?) ?? const [])
            .whereType<Map>()
            .map((item) => item.cast<String, dynamic>())
            .toList();
        _hostComputer = host;
      });
      final currentUserId = ref.read(authStoreProvider).user?.id;
      final activeControllerSession = _sessions.where(
        (session) =>
            session['status'] == 'ACTIVE' &&
            session['controllerUserId']?.toString() == currentUserId,
      );
      if (_viewingSession == null && activeControllerSession.isNotEmpty) {
        unawaited(_startViewing(activeControllerSession.first));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<String> _localComputerId() async {
    final userId = ref.read(authStoreProvider).user?.id ?? 'anonymous';
    final key = '$_computerIdStoragePrefix$userId';
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(key);
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final suffix = List.generate(
      10,
      (_) => _idAlphabet[random.nextInt(_idAlphabet.length)],
    ).join();
    final id = 'MTK-WIN-$suffix';
    await prefs.setString(key, id);
    return id;
  }

  Future<void> _run(Future<Map<String, dynamic>> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveHost() {
    final host = _hostComputer;
    if (host == null) {
      return _run(
        () => ref.read(apiProvider).registerRemoteComputer(
              computerId: _computerId.text.trim(),
              computerName: _computerName.text.trim(),
              platform: 'WINDOWS',
            ),
      );
    }
    return _run(
      () => ref.read(apiProvider).renameRemoteComputer(
            computerRecordId: '${host['id']}',
            computerName: _computerName.text.trim(),
          ),
    );
  }

  Future<void> _copyComputerId() async {
    final id = _computerId.text.trim();
    if (id.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: id));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Computer ID copied.')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = ref.watch(authStoreProvider).user?.id;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Live Desk',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect to an approved MyTaskKing Windows computer. Remote control is never enabled without host approval.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 28),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connect to a computer',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _connectComputerId,
                            decoration: const InputDecoration(
                              labelText: 'Computer ID',
                              hintText: 'Example: MTK-ABCD-1234',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _run(
                                    () => ref
                                        .read(apiProvider)
                                        .requestRemoteControl(
                                          computerId:
                                              _connectComputerId.text.trim(),
                                        ),
                                  ),
                          icon: const Icon(Icons.send),
                          label: const Text('Request access'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            if (_viewingSession != null) ...[
              const SizedBox(height: 20),
              Text('Live screen', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  color: Colors.black,
                  child: LayoutBuilder(
                    builder: (context, constraints) => GestureDetector(
                      onTapDown: (details) => _sendMouse(
                        details.localPosition,
                        Size(constraints.maxWidth, constraints.maxHeight),
                        'click',
                      ),
                      onPanUpdate: (details) => _sendMouse(
                        details.localPosition,
                        Size(constraints.maxWidth, constraints.maxHeight),
                        'move',
                      ),
                      child: _renderer.srcObject == null
                          ? const Center(
                              child: Text(
                                'Waiting for the approved Mac to share its screen...',
                                style: TextStyle(color: Colors.white),
                              ),
                            )
                          : RTCVideoView(
                              _renderer,
                              objectFit: RTCVideoViewObjectFit
                                  .RTCVideoViewObjectFitContain,
                            ),
                    ),
                  ),
                ),
              ),
            ],
            Text('My Windows host', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.computer, size: 34),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            _hostComputer == null
                                ? 'Register this Windows computer as a host.'
                                : 'This Windows computer is ready for Live Desk.',
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text('Computer ID', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            _computerId.text,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy computer ID',
                          onPressed: _copyComputerId,
                          icon: const Icon(Icons.copy_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _computerName,
                            focusNode: _computerNameFocus,
                            decoration: const InputDecoration(
                              labelText: 'Computer name',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: _busy ? null : _saveHost,
                          child: Text(
                            _hostComputer == null
                                ? 'Register host'
                                : 'Save name',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Sessions', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            if (_sessions.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(22),
                  child: Text('No active remote sessions.'),
                ),
              ),
            ..._sessions.map(
              (s) => _SessionCard(
                session: s,
                busy: _busy,
                canApprove: s['hostUserId']?.toString() == currentUserId,
                onApprove: () => _run(
                  () =>
                      ref.read(apiProvider).approveRemoteControl('${s['id']}'),
                ),
                onStop: () => _run(
                  () => ref.read(apiProvider).stopRemoteControl('${s['id']}'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final bool busy;
  final bool canApprove;
  final VoidCallback onApprove;
  final VoidCallback onStop;
  const _SessionCard({
    required this.session,
    required this.busy,
    required this.canApprove,
    required this.onApprove,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final status = '${session['status'] ?? 'UNKNOWN'}';
    final pending = status == 'PENDING';
    final active = status == 'ACTIVE';
    return Card(
      child: ListTile(
        leading: Icon(
          active ? Icons.screen_lock_portrait : Icons.computer,
          color: active ? Colors.red : null,
        ),
        title: Text(
          '${session['computerName'] ?? 'Windows computer'} (${session['computerId'] ?? ''})',
        ),
        subtitle: Text('Status: $status'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pending && canApprove)
              FilledButton(
                onPressed: busy ? null : onApprove,
                child: const Text('Approve'),
              ),
            if (pending && !canApprove) const Text('Waiting for host approval'),
            if (active)
              OutlinedButton(
                onPressed: busy ? null : onStop,
                child: const Text('Stop session'),
              ),
          ],
        ),
      ),
    );
  }
}
