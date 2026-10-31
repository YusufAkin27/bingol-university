import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../core/push/push_router.dart';
import '../../core/push/push_targets.dart';
import '../news/news_tile.dart' show newsLocalDate;
import 'notif_row.dart';

/// Uygulama içi bildirim listesi (design/P-Notifications).
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, required this.session});

  final Session session;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _items = <Map<String, dynamic>>[];
  final _scroll = ScrollController();
  int? _cursor;
  bool _loading = true;
  bool _more = false;
  bool _unreadOnly = false;
  Object? _error;

  Session get _s => widget.session;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        _loadMore();
      }
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = _items.isEmpty);
    try {
      final r = await _s.api.get('/notifications') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(((r['items'] as List?) ?? []).cast<Map<String, dynamic>>());
        _cursor = (r['nextCursor'] as num?)?.toInt();
        _error = null;
        _loading = false;
      });
      final u = (r['unreadCount'] as num?)?.toInt();
      if (u != null) _s.badges.notifications.value = u;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_cursor == null || _more || _loading) return;
    setState(() => _more = true);
    try {
      final r = await _s.api.get('/notifications?cursor=$_cursor') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _items.addAll(((r['items'] as List?) ?? []).cast<Map<String, dynamic>>());
        _cursor = (r['nextCursor'] as num?)?.toInt();
        _more = false;
      });
    } catch (_) {
      if (mounted) setState(() => _more = false);
    }
  }

  int get _unread => _items.where((n) => n['read'] != true).length;

  void _snack(String m) => BuToast.show(context, m, kind: BuToastKind.error);

  Future<void> _markAll() async {
    try {
      await _s.api.post('/notifications/read', {'all': true});
      if (!mounted) return;
      setState(() {
        for (final n in _items) {
          n['read'] = true;
        }
      });
      _s.badges.notifications.value = 0;
    } catch (e) {
      if (mounted) _snack(errorText(e));
    }
  }

  Future<void> _markOne(Map<String, dynamic> n) async {
    if (n['read'] == true) return;
    setState(() => n['read'] = true);
    final cur = _s.badges.notifications.value;
    _s.badges.notifications.value = cur > 0 ? cur - 1 : 0;
    try {
      await _s.api.post('/notifications/read', {
        'ids': [n['id']],
      });
    } catch (_) {
      // Sessiz: bir sonraki yüklemede sayaç sunucudan eşitlenir.
    }
  }

  Map<String, dynamic> _data(Map<String, dynamic> n) {
    final d = n['data'];
    try {
      if (d is String && d.isNotEmpty) {
        final m = jsonDecode(d);
        if (m is Map) return m.cast<String, dynamic>();
      } else if (d is Map) {
        return d.cast<String, dynamic>();
      }
    } catch (_) {}
    return {};
  }

  Future<void> _open(Map<String, dynamic> n) async {
    _markOne(n);
    // Tek yönlendirme tablosu: push dokunuşu ile aynı (core/push/push_targets.dart).
    final d = _data(n);
    final t = resolvePushTarget(d);
    if (t.dest == PushDest.notifications || t.dest == PushDest.signOut) return;
    await PushRouter.open(d);
  }

  IconData _icon(String? type) {
    switch (type) {
      case 'NEWS':
        return LucideIcons.newspaper;
      case 'ANNOUNCEMENT':
        return LucideIcons.megaphone;
      case 'EVENT':
        return LucideIcons.calendarDays;
      case 'MESSAGE':
        return LucideIcons.messageCircle;
      case 'COMMUNITY':
        return LucideIcons.users;
      case 'POLL':
      case 'POLL_CLOSED':
      case 'POLL_NEW':
        return LucideIcons.vote;
      case 'POST_LIKE':
        return LucideIcons.heart;
      case 'POST_COMMENT':
        return LucideIcons.messageSquare;
      case 'COMMENT_REPLY':
        return LucideIcons.reply;
      default:
        return LucideIcons.bell;
    }
  }

  String _group(String? iso) {
    final l = context.l10n;
    final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (d == null) return l.notifGroupOlder;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return l.notifGroupToday;
    if (diff == 1) return l.notifGroupYesterday;
    return l.notifGroupOlder;
  }

  String _typeLabel(String? type) {
    final l = context.l10n;
    switch (type) {
      case 'NEWS':
        return l.bildirimTypeNews;
      case 'ANNOUNCEMENT':
        return l.bildirimTypeAnnouncement;
      case 'EVENT':
        return l.bildirimTypeEvent;
      case 'MESSAGE':
        return l.bildirimTypeMessage;
      case 'COMMUNITY':
        return l.bildirimTypeCommunity;
      case 'POLL':
      case 'POLL_CLOSED':
      case 'POLL_NEW':
        return l.bildirimTypePoll;
      case 'POST_LIKE':
      case 'POST_COMMENT':
      case 'COMMENT_REPLY':
        return l.bildirimTypePost;
      default:
        return l.bildirimTypeOther;
    }
  }

  /// Sağ hizalı kısa zaman: şimdi / 5 dk / 2 sa / Dün / 3 g; bir haftadan eskide tarih.
  String _ago(String? iso) {
    final l = context.l10n;
    final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return l.notifNow;
    if (diff.inMinutes < 60) {
      return l.bildirimShortMin(diff.inMinutes.toString());
    }
    final days = DateTime(now.year, now.month, now.day).difference(DateTime(d.year, d.month, d.day)).inDays;
    if (days <= 0) return l.bildirimShortHour(diff.inHours.toString());
    if (days == 1) return l.bildirimYesterday;
    if (days < 7) return l.p03NotifShortDay(days.toString());
    return newsLocalDate(context, iso);
  }

  Future<void> _delete(Map<String, dynamic> n) async {
    final wasUnread = n['read'] != true;
    setState(() => _items.remove(n));
    if (wasUnread) {
      final cur = _s.badges.notifications.value;
      _s.badges.notifications.value = cur > 0 ? cur - 1 : 0;
    }
    try {
      await _s.api.delete('/notifications/${n['id']}');
    } catch (e) {
      if (!mounted) return;
      _snack(errorText(e));
      _load(silent: true);
    }
  }

  Widget _filters(BuTokens t) {
    final l = context.l10n;
    final unread = _unread > 0 ? _unread : _s.badges.notifications.value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.start, children: [
          _NotifFilterChip(
              key: const ValueKey('notif-seg-all'),
              label: l.bildirimFilterAll,
              count: 0,
              selected: !_unreadOnly,
              onTap: () => setState(() => _unreadOnly = false)),
          _NotifFilterChip(
              key: const ValueKey('notif-seg-unread'),
              label: l.bildirimFilterUnread,
              count: unread,
              selected: _unreadOnly,
              onTap: () => setState(() => _unreadOnly = true)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    // Büyük yazı ölçeğinde başlığı ezmesin diye düğme başlığın altına iner.
    final bigText = MediaQuery.textScalerOf(context).scale(10) > 11.5 || MediaQuery.sizeOf(context).width < 430;
    final pill = _unread > 0 || _s.badges.notifications.value > 0
        ? ConstrainedBox(
            // Dar ekran/büyük yazıda başlığı ezmesin: genişliğin sınırlı bölümü, metin kısalır.
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * (bigText ? .9 : .6)),
            child: BuPressable(
              onTap: _markAll,
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                alignment: AlignmentDirectional.centerEnd,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(l.notifMarkAll,
                    maxLines: bigText ? 2 : 1,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w600, color: t.mut)),
              ),
            ),
          )
        : null;

    final shown = _unreadOnly ? _items.where((n) => n['read'] != true).toList() : _items;
    final failed = _error != null;

    Widget body;
    if (failed && _items.isEmpty) {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [_ErrorCard(onRetry: _load)],
      );
    } else if (shown.isEmpty) {
      final unreadEmpty = _unreadOnly && _items.isNotEmpty;
      body = RefreshIndicator(
        onRefresh: () => _load(silent: true),
        child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              BuEmptyState(
                illustration: unreadEmpty ? BuIllustration.check : BuIllustration.bell,
                title: unreadEmpty ? l.bildirimEmptyUnread : l.notifEmpty,
                message: unreadEmpty ? l.p03NotifUnreadEmptyBody : l.p03NotifEmptyBody,
                compact: true,
              ),
            ]),
      );
    } else {
      final children = <Widget>[];
      if (failed) {
        children.add(Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 4), child: _ErrorCard(onRetry: _load)));
      }
      String? last;
      final tx = Theme.of(context).textTheme;
      var row = 0;
      for (final n in shown) {
        final g = _group(n['createdAt'] as String?);
        if (g != last) {
          last = g;
          children.add(Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 24, 20, 8),
            child: Semantics(
              header: true,
              child: Text(g, style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w700, letterSpacing: .5, color: t.mut)),
            ),
          ));
        }
        // İlk görünürde ilk 8 satır sırayla belirir; kaydırınca ya da süzünce yeniden oynamaz.
        children.add(Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: BuStaggerItem(index: row++, child: _tile(t, n))));
      }
      if (_more) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Center(
            child: Semantics(
              label: l.p03NotifLoadingMore,
              liveRegion: true,
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: t.mut)),
            ),
          ),
        ));
      } else if (_cursor == null) {
        // Liste sonu: iki sakin satır (çizgi, simge, koyu hap yok).
        final quiet = tx.labelMedium!.copyWith(fontWeight: FontWeight.w500, color: t.mut);
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(l.bildirimAllCaughtUp, textAlign: TextAlign.center, style: quiet.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(l.bildirimSwipeHint, textAlign: TextAlign.center, style: quiet),
          ]),
        ));
      }
      body = RefreshIndicator(
        onRefresh: () => _load(silent: true),
        child: BuStaggerScope(
          child: ListView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(0, 0, 0, MediaQuery.of(context).padding.bottom + 24),
            children: children,
          ),
        ),
      );
    }

    // İskelet -> içerik: yalnız opaklık geçişi (düzen kayması yok).
    body = BuSwapIn(
      loading: _loading,
      skeleton: const BuSkeletonList(itemCount: 6, padding: EdgeInsets.fromLTRB(20, 12, 20, 24)),
      child: body,
    );

    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        BuHeader(
          title: l.notifTitle,
          onBack: () => Navigator.pop(context),
          actions: [if (pill != null && !bigText) pill],
        ),
        if (pill != null && bigText)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Align(alignment: AlignmentDirectional.centerEnd, child: pill),
          ),
        if (!_loading) _filters(t),
        Expanded(child: body),
      ]),
    );
  }

  Widget _tile(BuTokens t, Map<String, dynamic> n) {
    final un = n['read'] != true;
    final type = n['type'] as String?;
    final tx = Theme.of(context).textTheme;
    return Dismissible(
      key: ValueKey('notif-${n['id']}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        buHaptic(BuHaptic.light);
        _delete(n);
      },
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 28),
        decoration: BoxDecoration(color: t.danger, borderRadius: BuRadius.bLg),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(LucideIcons.trash2, size: 22, color: t.onMedia),
          const SizedBox(height: 4),
          Text(context.l10n.bildirimDelete,
              style: tx.labelMedium!.copyWith(fontWeight: FontWeight.w700, color: t.onMedia)),
        ]),
      ),
      child: NotifRow(
        icon: _icon(type),
        title: (n['title'] as String?) ?? '',
        typeLabel: _typeLabel(type),
        body: (n['body'] as String?) ?? '',
        time: _ago(n['createdAt'] as String?),
        unread: un,
        unreadLabel: context.l10n.notifUnread,
        onTap: () => _open(n),
      ),
    );
  }
}

/// Süzgeç hapı: seçili = yumuşak vurgu zemini (BuChip stili); sayaç yalnız sıfırdan büyükse, sade rakam.
class _NotifFilterChip extends StatelessWidget {
  const _NotifFilterChip(
      {super.key, required this.label, required this.count, required this.selected, required this.onTap});

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final fg = selected ? t.onSoft : t.ink;
    return Semantics(
      button: true,
      selected: selected,
      child: BuPressable(
        onTap: onTap,
        child: BuTouchTarget(
          child: AnimatedContainer(
          duration: BuMotion.of(context, BuMotion.short),
          constraints: const BoxConstraints(minHeight: BuSize.chip),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? t.soft : t.sf,
            borderRadius: BorderRadius.circular(BuRadius.pill),
            border: Border.all(color: selected ? t.selectedBorder : t.bd),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: tx.labelLarge!.copyWith(fontWeight: FontWeight.w700, color: fg)),
            if (count > 0) ...[
              const SizedBox(width: 8),
              Text(count > 99 ? '99+' : '$count',
                  style: tx.labelLarge!.copyWith(
                      fontWeight: FontWeight.w700,
                      color: fg.withValues(alpha: .7),
                      fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ]),
        ),
        ),
      ),
    );
  }
}

/// Yükleme hatası: tek cümle + tek eylem.
class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    return BuCard(
      radius: BuRadius.lg,
      padding: const EdgeInsets.all(16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Text(l.p03NotifLoadFailed,
                style: tx.titleSmall!.copyWith(fontWeight: FontWeight.w700, height: 1.3, color: t.ink)),
          ),
        ),
        const SizedBox(width: 12),
        BuButton(label: l.commonRetry, compact: true, onPressed: onRetry),
      ]),
    );
  }
}
