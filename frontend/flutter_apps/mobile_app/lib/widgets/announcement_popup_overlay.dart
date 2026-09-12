import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mytaskking_design/mytaskking_design.dart';

import '../state.dart';

/// Shows only the newest eligible announcement above every authenticated route.
class AnnouncementPopupOverlay extends ConsumerStatefulWidget {
  const AnnouncementPopupOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AnnouncementPopupOverlay> createState() =>
      _AnnouncementPopupOverlayState();
}

class _AnnouncementPopupOverlayState
    extends ConsumerState<AnnouncementPopupOverlay> {
  String? _userId;
  Map<String, dynamic>? _announcement;
  void Function()? _unsubscribe;
  bool _loading = false;
  bool _acknowledging = false;

  @override
  void dispose() {
    _unsubscribe?.call();
    super.dispose();
  }

  void _activateForUser(String? userId) {
    if (userId == _userId) return;
    _unsubscribe?.call();
    _unsubscribe = null;
    _userId = userId;
    _announcement = null;
    _loading = false;

    if (userId == null) return;
    _unsubscribe = ref.read(realtimeProvider).onAny(
          'announcement.published',
          ([_]) => unawaited(_loadLatest(userId)),
        );
    unawaited(_loadLatest(userId));
  }

  Future<void> _loadLatest(String expectedUserId) async {
    if (_loading || expectedUserId != _userId) return;
    _loading = true;
    try {
      final item = await ref.read(apiProvider).latestAnnouncement();
      if (!mounted || expectedUserId != _userId) return;
      setState(() => _announcement = item);
    } catch (_) {
      // A transient API failure must not block the authenticated workspace.
    } finally {
      _loading = false;
    }
  }

  Future<void> _acknowledge() async {
    final item = _announcement;
    if (item == null || _acknowledging) return;
    final id = item['id']?.toString();
    if (id == null || id.isEmpty) return;

    setState(() => _acknowledging = true);
    try {
      await ref.read(apiProvider).ackAnnouncement(id);
      ref.invalidate(announcementsProvider);
      if (mounted) setState(() => _announcement = null);
    } catch (error) {
      if (mounted) {
        bestieToast(
          context,
          'Could not acknowledge announcement',
          body: formatApiError(error),
          kind: BestieToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _acknowledging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).asData?.value ??
        ref.watch(authStoreProvider).user;
    final userId = user?.id;
    if (userId != _userId) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _activateForUser(userId));
    }

    final item = _announcement;
    if (item == null || userId == null) return widget.child;
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: PopScope(
            canPop: false,
            child: _AnnouncementDialog(
              announcement: item,
              acknowledging: _acknowledging,
              onAcknowledge: _acknowledge,
            ),
          ),
        ),
      ],
    );
  }
}

class _AnnouncementDialog extends StatelessWidget {
  const _AnnouncementDialog({
    required this.announcement,
    required this.acknowledging,
    required this.onAcknowledge,
  });

  final Map<String, dynamic> announcement;
  final bool acknowledging;
  final VoidCallback onAcknowledge;

  @override
  Widget build(BuildContext context) {
    final c = BestieColors.of(context);
    final priority =
        (announcement['priority'] ?? 'INFO').toString().toUpperCase();
    final accent = switch (priority) {
      'URGENT' => c.danger,
      'IMPORTANT' => c.warning,
      _ => c.brand,
    };
    final title = (announcement['title'] ?? 'Announcement').toString();
    final body = (announcement['body'] ?? '').toString();

    return Material(
      color: Colors.black.withValues(alpha: 0.56),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(BestieTokens.rLg),
                  border: Border.all(color: accent.withValues(alpha: 0.55)),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black38,
                        blurRadius: 30,
                        offset: Offset(0, 12)),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.campaign_rounded, color: accent),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Text(
                              priority,
                              style: TextStyle(
                                color: accent,
                                fontSize: 12,
                                fontWeight: BestieTokens.fwBold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        title,
                        style: TextStyle(
                          color: c.text,
                          fontSize: 21,
                          fontWeight: BestieTokens.fwBold,
                          height: 1.18,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: SingleChildScrollView(
                          child: Text(
                            body,
                            style: TextStyle(
                                color: c.textSoft, fontSize: 15, height: 1.45),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: acknowledging ? null : onAcknowledge,
                          icon: acknowledging
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.check_rounded),
                          label: Text(acknowledging ? 'Saving...' : 'Got it'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
