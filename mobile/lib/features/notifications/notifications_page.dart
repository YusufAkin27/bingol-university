import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../core/push/push_router.dart';
import '../../core/push/push_targets.dart';
import '../news/news_tile.dart' show newsLocalDate, newsMonthName;
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
    // Aynı yıl: "22 Ekim"; daha eski: yıllı tam tarih.
    return d.year == now.year ? '${d.day} ${newsMonthName(context, d.month)}' : newsLocalDate(context, iso);
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
    // Çipin 48 dp dokunma alanı görsel 34 dp'nin 7 dp üstüne taşar; görsel konumu Stitch ölçüsüne oturtmak için
    // paint + hit-test 7 dp yukarı alınır (yer ayırma aynı kalır, alt boşluk buna göre).
    return Transform.translate(
      offset: const Offset(0, -7),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        _NotifFilterChip(
            key: const ValueKey('notif-seg-all'),
            label: l.bildirimFilterAll,
            selected: !_unreadOnly,
            onTap: () => setState(() => _unreadOnly = false)),
        _NotifFilterChip(
            key: const ValueKey('notif-seg-unread'),
            label: l.bildirimFilterUnread,
            selected: _unreadOnly,
            onTap: () => setState(() => _unreadOnly = true)),
      ]),
      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    // Geniş ekranda "Tümünü okundu yap" başlık satırının sağında; dar ekran / büyük yazıda başlığın altında.
    final bigText = MediaQuery.textScalerOf(context).scale(10) > 11.5 || MediaQuery.sizeOf(context).width < 380;
    final pill = _unread > 0 || _s.badges.notifications.value > 0
        ? ConstrainedBox(
            // Başlığı ezmesin: genişliğin sınırlı bölümü, metin kısalır.
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * (bigText ? .9 : .5)),
            child: BuPressable(
              onTap: _markAll,
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                alignment: AlignmentDirectional.centerEnd,
                child: Text(l.notifMarkAll,
                    maxLines: bigText ? 2 : 1,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: BuType.caption.copyWith(fontSize: 14, height: 1.3, fontWeight: FontWeight.w600, color: t.pr)),
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
      // Boş: ortada soluk tek cümle (illüstrasyon yok).
      body = RefreshIndicator(
        onRefresh: () => _load(silent: true),
        child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              SizedBox(
                height: 360,
                child: Center(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(unreadEmpty ? l.bildirimEmptyUnread : l.notifEmpty,
                        textAlign: TextAlign.center, style: BuType.caption.copyWith(fontSize: 16, height: 1.5, color: t.mut)),
                  ),
                ),
              ),
            ]),
      );
    } else {
      final children = <Widget>[];
      if (failed) {
        children.add(Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: _ErrorCard(onRetry: _load)));
      }
      String? last;
      var row = 0;
      for (final n in shown) {
        final g = _group(n['createdAt'] as String?);
        if (g != last) {
          last = g;
          children.add(Padding(
            padding: EdgeInsetsDirectional.fromSTEB(20, row == 0 ? 8 : 16, 20, 6),
            child: Semantics(
              header: true,
              child: Text(trUpper(g), style: BuType.caption.copyWith(fontSize: 13, height: 1.3, fontWeight: FontWeight.w600, letterSpacing: .6, color: t.mut)),
            ),
          ));
        }
        // İlk görünürde ilk 8 satır sırayla belirir; kaydırınca ya da süzünce yeniden oynamaz.
        children.add(Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20), child: BuStaggerItem(index: row++, child: _tile(t, n))));
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
        // Liste sonu: tek sakin satır.
        children.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: Text(l.bildirimAllCaughtUp, textAlign: TextAlign.center, style: BuType.caption.copyWith(fontSize: 13, height: 1.4, color: t.mut)),
          ),
        ));
      }
      body = RefreshIndicator(
        onRefresh: () => _load(silent: true),
        child: BuStaggerScope(
          child: ListView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(0, 0, 0, MediaQuery.of(context).padding.bottom),
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
    return Dismissible(
      key: ValueKey('notif-${n['id']}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        buHaptic(BuHaptic.light);
        _delete(n);
      },
      // Sola kaydırınca sağdan `danger` zeminli "Sil" levhası (köşe 0, satırın yüksekliğinde).
      background: Container(
        color: t.danger,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 24),
        child: Text(context.l10n.bildirimDelete, style: BuType.caption.copyWith(fontSize: 14, fontWeight: FontWeight.w600, color: t.onMedia)),
      ),
      child: NotifRow(
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

/// Süzgeç hapı (Stitch v3): seçili = `soft` zemin + `pr` metin (çerçevesiz); seçili değil = 1 dp `bd` çerçeve +
/// ink metin. Görünür yükseklik 34 dp, dokunma alanı 48 dp; sayaç rozeti yok.
class _NotifFilterChip extends StatelessWidget {
  const _NotifFilterChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return Semantics(
      button: true,
      selected: selected,
      child: BuPressable(
        onTap: onTap,
        child: BuTouchTarget(
          child: AnimatedContainer(
            duration: BuMotion.of(context, BuMotion.short),
            constraints: const BoxConstraints(minHeight: 34),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            decoration: BoxDecoration(
              color: selected ? t.soft : t.bg,
              borderRadius: BorderRadius.circular(BuRadius.pill),
              border: Border.all(color: selected ? t.soft : t.bd),
            ),
            child: Text(label, style: BuType.caption.copyWith(fontSize: 14, height: 1.3, fontWeight: FontWeight.w500, color: selected ? t.pr : t.ink)),
          ),
        ),
      ),
    );
  }
}

/// Yükleme hatası: soluk tek cümle + `pr` metin eylemi.
class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Semantics(
          liveRegion: true,
          child: Text(l.p03NotifLoadFailed, textAlign: TextAlign.center, style: BuType.caption.copyWith(fontSize: 16, height: 1.5, color: t.mut)),
        ),
        const SizedBox(height: 8),
        BuPressable(
          onTap: onRetry,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l.commonRetry, style: BuType.caption.copyWith(fontSize: 14, fontWeight: FontWeight.w600, color: t.pr)),
          ),
        ),
      ]),
    );
  }
}
