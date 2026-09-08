import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mytaskking_core/mytaskking_core.dart';

class LiveDeskScreen extends ConsumerStatefulWidget {
  const LiveDeskScreen({super.key});

  @override
  ConsumerState<LiveDeskScreen> createState() => _LiveDeskScreenState();
}

class _LiveDeskScreenState extends ConsumerState<LiveDeskScreen> {
  final _computerId = TextEditingController();
  final _computerName = TextEditingController();
  Timer? _refresh;
  List<Map<String, dynamic>> _sessions = [];
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
    _computerId.dispose();
    _computerName.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await ref.read(apiProvider).remoteControlSessions();
      if (!mounted) return;
      setState(
        () => _sessions = ((data['items'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList(),
      );
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
                            controller: _computerId,
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
                                          computerId: _computerId.text.trim(),
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
            Text('My Windows host', style: theme.textTheme.titleLarge),
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
                              'Register this Windows computer as a host.',
                              style: theme.textTheme.titleMedium)),
                    ]),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(
                          child: TextField(
                              controller: _computerName,
                              decoration: const InputDecoration(
                                  labelText: 'Computer name'))),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() => ref
                                .read(apiProvider)
                                .registerRemoteComputer(
                                    computerId: _computerId.text.trim(),
                                    computerName: _computerName.text.trim())),
                        child: const Text('Register host'),
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
          '${session['computerName'] ?? 'Windows computer'} (${session['computerId'] ?? ''})',
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
