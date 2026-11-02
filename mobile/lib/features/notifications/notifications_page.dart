import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/api.dart' show ApiError;
import '../../core/locale_controller.dart';
import '../../core/push/push_router.dart';
import '../../core/push/push_targets.dart';
import '../../core/push/rich/rich_actions.dart' show personIdOf;
import '../../core/push/rich/rich_card.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/sistem_widgets.dart' show MaintenanceBand;
import '../follow/follow_requests_api.dart';
import '../follow/follow_requests_entry.dart';
import '../news/news_tile.dart' show newsLocalDate, newsMonthName;
import '../profile/notification_prefs_page.dart';
import 'notif_card.dart';

/// Uygulama içi bildirim listesi (Stitch "Bildirim - Uygulama içi şerit ve liste", alt kısım):
/// marka başlığı, "N Yeni" + "Tümünü okundu yap", kategori çipleri, Bugün/Dün/Daha eski grupları,
/// kişi avatarlı ya da sistem rozetli kartlar, takip isteğinde Onayla/Reddet.
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
  NotifCategory _cat = NotifCategory.all;
  Object? _error;

  /// Takip isteği satırında verilen karar: bildirim kimliği -> true (onaylandı) / false (reddedildi).
  final _decided = <Object?, bool>{};
  final _deciding = <Object?>{};

  /// Yenilemede artar: üstteki "Takip istekleri" satırı sayısını yeniden yükler.
  int _reqRefresh = 0;

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
    if (silent) _reqRefresh++;
    try {
      final r = await _s.api.get('/notifications') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(_inbox(r['items']));
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
        _items.addAll(_inbox(r['items']));
        _cursor = (r['nextCursor'] as num?)?.toInt();
        _more = false;
      });
    } catch (_) {
      if (mounted) setState(() => _more = false);
    }
  }

  /// Sohbet mesajları Bildirimler'e düşmez (sohbet kendi sekmesindedir; push yine gider ve sohbeti açar). Sunucu
  /// artık `MESSAGE` döndürmez; eski sürüm/önbellekten gelen satır istemcide de gizlenir.
  static List<Map<String, dynamic>> _inbox(Object? items) => [
        for (final e in (items as List?) ?? const [])
          if (e is Map<String, dynamic> && '${e['type'] ?? ''}'.toUpperCase() != 'MESSAGE') e,
      ];

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
    if (t.dest == PushDest.notifications || t.dest == PushDest.signOut) {
      PushRouter.trackOpen(t); // hedefsiz satır da bir açılıştır (PushRouter.open çağrılmadığı için burada)
      return;
    }
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
      case 'FOLLOW':
      case 'FOLLOW_REQUEST':
      case 'FOLLOW_ACCEPTED':
        return l.frqNotifTypeFollow;
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

  /// Süzgeç: kategori (istemci) ya da yalnız okunmamışlar. Bilinmeyen tür yalnız "Tümü"nde görünür.
  List<Map<String, dynamic>> get _shown {
    switch (_cat) {
      case NotifCategory.all:
        return _items;
      case NotifCategory.unread:
        return _items.where((n) => n['read'] != true).toList();
      default:
        return _items.where((n) => notifCategoryOf('${n['type'] ?? ''}', subtype: '${n['subtype'] ?? _data(n)['subtype'] ?? ''}') == _cat).toList();
    }
  }

  /// Takip isteği satırı: onayla (true) / reddet (false). Başarıda satır karar etiketi gösterir ve okunur.
  Future<void> _decide(Map<String, dynamic> n, int userId, bool accept) async {
    final id = n['id'];
    if (_deciding.contains(id)) return;
    setState(() => _deciding.add(id));
    try {
      final api = FollowRequestsApi(_s);
      if (accept) {
        await api.accept(userId);
      } else {
        await api.decline(userId);
      }
      if (!mounted) return;
      setState(() {
        _decided[id] = accept;
        _deciding.remove(id);
      });
      _markOne(n);
      setState(() => _reqRefresh++);
    } catch (e) {
      if (!mounted) return;
      setState(() => _deciding.remove(id));
      _snack(errorText(e));
    }
  }

  // ---------------------------------------------------------------------------------------------------------------

  Widget _chips(BuTokens t) {
    final l = context.l10n;
    final defs = <(NotifCategory, String, String)>[
      (NotifCategory.all, l.bildirimFilterAll, 'notif-seg-all'),
      (NotifCategory.messages, l.notifFilterMessages, 'notif-seg-messages'),
      (NotifCategory.events, l.notifFilterEvents, 'notif-seg-events'),
      (NotifCategory.announcements, l.notifFilterAnnouncements, 'notif-seg-announcements'),
      (NotifCategory.social, l.notifFilterSocial, 'notif-seg-social'),
      // Önceki sürümden gelen "yalnız okunmamışlar" süzgeci: son çip, tasarımdaki gibi yatay kaydırmada.
      (NotifCategory.unread, l.bildirimFilterUnread, 'notif-seg-unread'),
    ];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: defs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final d = defs[i];
          return Center(
            child: _NotifFilterChip(key: ValueKey(d.$3), label: d.$2, selected: _cat == d.$1, onTap: () => setState(() => _cat = d.$1)),
          );
        },
      ),
    );
  }

  Widget _brandHeader(BuTokens t) {
    final l = context.l10n;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(8, MediaQuery.of(context).padding.top + 8, 8, 8),
      child: Row(children: [
        BuIconButton(icon: BuIcons.arrowLeft, onTap: () => Navigator.pop(context), tooltip: l.commonBack),
        const SizedBox(width: 8),
        ExcludeSemantics(
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: t.pr, shape: BoxShape.circle),
            child: Text('BU', style: BuType.caption.copyWith(fontSize: 13, fontWeight: FontWeight.w800, color: t.onPr, height: 1)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(l.notifBrandCaption,
                maxLines: 1, style: BuType.caption.copyWith(fontSize: 11, height: 1.2, fontWeight: FontWeight.w800, letterSpacing: .6, color: t.pr)),
            Semantics(
              header: true,
              child: Text(l.notifTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.caption.copyWith(fontSize: 18, height: 1.2, fontWeight: FontWeight.w800, color: t.ink)),
            ),
          ]),
        ),
        BuIconButton(icon: BuIcons.bell, onTap: _openPrefs, tooltip: l.notifSettings),
        PopupMenuButton<String>(
          key: const ValueKey('notif-menu'),
          tooltip: l.notifSettings,
          icon: Icon(BuIcons.ellipsisVertical, size: 22, color: t.ink),
          onSelected: (v) {
            if (v == 'all') _markAll();
            if (v == 'prefs') _openPrefs();
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'all', child: Text(l.notifMarkAll)),
            PopupMenuItem(value: 'prefs', child: Text(l.notifSettings)),
          ],
        ),
      ]),
    );
  }

  void _openPrefs() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => NotificationPrefsPage(session: _s)));
  }

  /// "Bildirimler [2 Yeni]                Tümünü okundu yap"
  Widget _titleRow(BuTokens t) {
    final l = context.l10n;
    final n = _unread > 0 ? _unread : _s.badges.notifications.value;
    final bigText = MediaQuery.textScalerOf(context).scale(10) > 11.5 || MediaQuery.sizeOf(context).width < 380;
    final markAll = n > 0
        ? BuPressable(
            onTap: _markAll,
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              alignment: AlignmentDirectional.centerEnd,
              child: Text(l.notifMarkAll,
                  key: const ValueKey('notif-mark-all'),
                  maxLines: bigText ? 2 : 1,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: BuType.caption.copyWith(fontSize: 13, height: 1.3, fontWeight: FontWeight.w700, color: t.pr)),
            ),
          )
        : null;
    final heading = Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
      Text(l.notifTitle, style: BuType.caption.copyWith(fontSize: 22, height: 1.25, fontWeight: FontWeight.w800, color: t.ink)),
      if (n > 0)
        Container(
          key: const ValueKey('notif-new-badge'),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(BuRadius.pill)),
          child: Text(l.notifNewBadge('$n'), style: BuType.caption.copyWith(fontSize: 11, height: 1.2, fontWeight: FontWeight.w800, color: t.onSoft)),
        ),
    ]);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: bigText && markAll != null
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [heading, Align(alignment: AlignmentDirectional.centerEnd, child: markAll)])
          : Row(children: [Expanded(child: heading), if (markAll != null) Flexible(child: markAll)]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final shown = _shown;
    final failed = _error != null;
    final maintenance = _error is ApiError && (((_error as ApiError).status == 503) || (_error as ApiError).code.toUpperCase().contains('MAINTENANCE'));

    Widget body;
    if (failed && _items.isEmpty) {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          if (maintenance) MaintenanceBand(text: l.coreMaintenance, margin: const EdgeInsets.only(bottom: 8)),
          _ErrorCard(onRetry: _load),
        ],
      );
    } else if (shown.isEmpty) {
      final filtered = _cat != NotifCategory.all && _items.isNotEmpty;
      final text = _cat == NotifCategory.unread && _items.isNotEmpty
          ? l.bildirimEmptyUnread
          : filtered
              ? l.notifEmptyFilter
              : l.notifEmpty;
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
                    child: Text(text, textAlign: TextAlign.center, style: BuType.caption.copyWith(fontSize: 16, height: 1.5, color: t.mut)),
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
      // Grup başlığında o gruptaki okunmamış sayısı ("2 okunmamış").
      final unreadByGroup = <String, int>{};
      for (final n in shown) {
        if (n['read'] != true) {
          final g = _group(n['createdAt'] as String?);
          unreadByGroup[g] = (unreadByGroup[g] ?? 0) + 1;
        }
      }
      String? last;
      var row = 0;
      for (final n in shown) {
        final g = _group(n['createdAt'] as String?);
        if (g != last) {
          last = g;
          final u = unreadByGroup[g] ?? 0;
          children.add(Padding(
            padding: EdgeInsetsDirectional.fromSTEB(20, row == 0 ? 8 : 16, 20, 6),
            child: Row(children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(trUpper(g), style: BuType.caption.copyWith(fontSize: 12, height: 1.3, fontWeight: FontWeight.w700, letterSpacing: .6, color: t.mut)),
                ),
              ),
              if (u > 0) Text(l.notifGroupUnreadCount('$u'), style: BuType.caption.copyWith(fontSize: 12, height: 1.3, color: t.mut)),
            ]),
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
        // Liste sonu: onay simgesi + "Başka bildiriminiz bulunmuyor".
        children.add(const _EndOfList(key: ValueKey('notif-end')));
      }
      body = RefreshIndicator(
        onRefresh: () => _load(silent: true),
        child: BuStaggerScope(
          child: ListView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(0, 0, 0, MediaQuery.of(context).padding.bottom + 16),
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
        _brandHeader(t),
        if (maintenance && _items.isNotEmpty)
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: MaintenanceBand(text: l.coreMaintenance)),
        if (!_loading) _titleRow(t),
        if (!_loading) FollowRequestsEntry(session: _s, refresh: _reqRefresh),
        if (!_loading) _chips(t),
        Expanded(child: body),
      ]),
    );
  }

  Widget _tile(BuTokens t, Map<String, dynamic> n) {
    final l = context.l10n;
    final un = n['read'] != true;
    final type = n['type'] as String?;
    final data = _data(n);
    final kind = notifKindOf(n, data);
    final id = n['id'];
    String? field(String k) {
      final v = n[k] ?? data[k];
      final s = v == null ? '' : '$v'.trim();
      return s.isEmpty ? null : s;
    }

    final title = (n['title'] as String?) ?? '';
    final avatarUrl = field('senderAvatarUrl');
    final person = notifIsPerson(kind);
    final name = field('senderName') ?? title;
    final Widget leading = person
        ? BuAvatar(name: name, url: avatarUrl, size: 44)
        : NotifBadge(kind: kind);

    Widget? actions;
    if (kind == RichKind.followRequest) {
      final uid = personIdOf(data) ?? int.tryParse(field('requestId') ?? '') ?? int.tryParse(field('senderId') ?? '');
      final decided = _decided[id];
      if (decided != null) {
        actions = Text(decided ? l.notifActAccept : l.notifActReject,
            key: ValueKey('notif-decided-$id'), style: BuType.caption.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: t.mut));
      } else if (uid != null) {
        final busy = _deciding.contains(id);
        actions = Row(children: [
          NotifPill(key: ValueKey('notif-accept-$id'), label: l.notifActAccept, primary: true, onTap: busy ? () {} : () => _decide(n, uid, true)),
          const SizedBox(width: 8),
          NotifPill(key: ValueKey('notif-reject-$id'), label: l.notifActReject, primary: false, onTap: busy ? () {} : () => _decide(n, uid, false)),
        ]);
      }
    }

    return Dismissible(
      key: ValueKey('notif-$id'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        buHaptic(BuHaptic.light);
        _delete(n);
      },
      // Sola kaydırınca sağdan `danger` zeminli "Sil" levhası.
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: t.danger, borderRadius: BorderRadius.circular(20)),
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 24),
        child: Text(l.bildirimDelete, style: BuType.caption.copyWith(fontSize: 14, fontWeight: FontWeight.w600, color: t.onMedia)),
      ),
      child: NotifCard(
        title: title,
        body: (n['body'] as String?) ?? '',
        time: _ago(n['createdAt'] as String?),
        unread: un,
        leading: leading,
        // Okunmamış bilgisi + tür + zaman tek okuma: "Okunmamış, Duyuru, 5 dk".
        semanticsLabel: [if (un) l.notifUnread, _typeLabel(type), _ago(n['createdAt'] as String?)].where((s) => s.isNotEmpty).join(', '),
        warning: kind == RichKind.newDeviceLogin ? l.notifSecWarn : null,
        actions: actions,
        onTap: () => _open(n),
      ),
    );
  }
}

/// Liste sonu (tasarım 08): çift onay simgesi + "Başka bildiriminiz bulunmuyor" + açıklama.
class _EndOfList extends StatelessWidget {
  const _EndOfList({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ExcludeSemantics(
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: t.sf2, shape: BoxShape.circle),
            child: Icon(BuIcons.checkCheck, size: 22, color: t.mut),
          ),
        ),
        const SizedBox(height: 10),
        Text(l.notifEndTitle, textAlign: TextAlign.center, style: BuType.caption.copyWith(fontSize: 13, height: 1.4, fontWeight: FontWeight.w700, color: t.ink)),
        const SizedBox(height: 2),
        Text(l.notifEndSub, textAlign: TextAlign.center, style: BuType.caption.copyWith(fontSize: 12, height: 1.4, color: t.mut)),
      ]),
    );
  }
}

/// Süzgeç hapı (tasarım 08): seçili = koyu (ink) zemin + açık yazı; seçili değil = gri zemin + ink yazı.
/// Görünür yükseklik 34 dp, dokunma alanı 48 dp.
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? t.ink : t.sf2,
              borderRadius: BorderRadius.circular(BuRadius.pill),
            ),
            child: Text(label, style: BuType.caption.copyWith(fontSize: 14, height: 1.3, fontWeight: FontWeight.w600, color: selected ? t.bg : t.ink)),
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
