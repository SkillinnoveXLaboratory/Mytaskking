import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mytaskking_core/mytaskking_core.dart';

class LiveDeskScreen extends ConsumerStatefulWidget {
  const LiveDeskScreen({super.key});

  @override
  ConsumerState<LiveDeskScreen> createState() => _LiveDeskScreenState();
}

class _LiveDeskScreenState extends ConsumerState<LiveDeskScreen> {
  final _connectComputerId = TextEditingController();
  final _computerId = TextEditingController(text: 'MTK-LINUX-001');
  final _computerName = TextEditingController(text: 'My Linux PC');
  final _computerNameFocus = FocusNode();
  Timer? _refresh;
  List<Map<String, dynamic>> _sessions = [];
  Map<String, dynamic>? _hostComputer;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _refresh = Timer.periodic(const Duration(seconds: 8), (_) => _load());
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _connectComputerId.dispose();
    _computerId.dispose();
    _computerName.dispose();
    _computerNameFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ref.read(apiProvider).remoteControlSessions(),
        ref.read(apiProvider).remoteComputers(platform: 'LINUX'),
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
      }
      setState(() {
        _sessions = ((sessionData['items'] as List?) ?? const [])
            .whereType<Map>()
            .map((item) => item.cast<String, dynamic>())
            .toList();
        _hostComputer = host;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
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
              platform: 'LINUX',
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Computer ID copied.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              'Connect to an approved MyTaskKing Linux or Windows computer. Remote control is never enabled without host approval.',
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
            Text('My Linux host', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.computer, size: 34),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          _hostComputer == null
                              ? 'Register this Linux computer as a host.'
                              : 'This Linux computer is ready for Live Desk.',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    Text('Computer ID', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 4),
                    Row(children: [
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
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                          child: TextField(
                        controller: _computerName,
                        focusNode: _computerNameFocus,
                        decoration: const InputDecoration(
                          labelText: 'Computer name',
                        ),
                      )),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: _busy ? null : _saveHost,
                        child: Text(
                          _hostComputer == null ? 'Register host' : 'Save name',
                        ),
                      ),
                    ]),
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
  final VoidCallback onApprove;
  final VoidCallback onStop;
  const _SessionCard({
    required this.session,
    required this.busy,
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
          '${session['computerName'] ?? 'Linux computer'} (${session['computerId'] ?? ''})',
        ),
        subtitle: Text('Status: $status'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pending)
              FilledButton(
                onPressed: busy ? null : onApprove,
                child: const Text('Approve'),
              ),
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
