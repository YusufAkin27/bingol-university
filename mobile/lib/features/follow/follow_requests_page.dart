import 'package:flutter/material.dart';

import '../../core/academic_catalog.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/profile_photo_viewer.dart';
import '../news/news_tile.dart' show newsLocalDate, newsMonthName;
import '../posts/post_models.dart' show postAuthHeaders;
import '../profile/user_profile_page.dart';
import 'follow_requests_api.dart';
import 'follow_widgets.dart';

/// "Takip istekleri" ekranını açar; döndüğünde (kabul/red sayıyı değiştirmiş olabilir) çağıran sayacı yeniler.
Future<void> openFollowRequests(BuildContext context, Session session) =>
    Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => FollowRequestsPage(session: session)));

/// Gizli hesabın gelen takip istekleri: üstte başlık + bekleyen sayısı, satırlarda Onayla (birincil) / Sil (çizgili).
/// Kabul/red sonrası satır kayarak kalkar; hata olursa satır geri gelir. Boş/yükleniyor/hata durumları ve imleçli sayfalama.
class FollowRequestsPage extends StatefulWidget {
  const FollowRequestsPage({super.key, required this.session});

  final Session session;

  @override
  State<FollowRequestsPage> createState() => _FollowRequestsPageState();
}

class _FollowRequestsPageState extends State<FollowRequestsPage> {
  final _items = <FollowRequest>[];
  final _leaving = <int>{};
  final _scroll = ScrollController();
  String? _cursor;
  int? _total;
  bool _loading = true;
  bool _more = false;
  Object? _error;
  int _gen = 0;

  FollowRequestsApi get _api => FollowRequestsApi(widget.session);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _loadMore();
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final gen = ++_gen;
    if (!silent) setState(() => _loading = _items.isEmpty);
    try {
      final r = await _api.list();
      if (!mounted || gen != _gen) return;
      setState(() {
        _items
          ..clear()
          ..addAll(r.items);
        _leaving.clear();
        _cursor = r.hasMore ? r.nextCursor : null;
        _total = r.total;
        _error = null;
        _loading = false;
      });
      // Sayfa yanıtı toplam taşımaz: başlıktaki sayı `.../count` ucundan gelir (sayfalamada satır sayısından büyük olabilir).
      if (r.total == null) _loadTotal();
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        // Eldeki liste korunur; hata ekranı yalnız gösterilecek hiçbir şey yokken çıkar.
        _error = _items.isEmpty ? e : null;
        _loading = false;
      });
    }
  }

  Future<void> _loadTotal() async {
    try {
      final n = await _api.count();
      if (mounted && n != null) setState(() => _total = n);
    } catch (_) {}
  }

  Future<void> _loadMore() async {
    final cursor = _cursor;
    if (cursor == null || _more || _loading) return;
    setState(() => _more = true);
    try {
      final r = await _api.list(cursor: cursor);
      if (!mounted) return;
      setState(() {
        final seen = _items.map((e) => e.userId).toSet();
        _items.addAll(r.items.where((e) => seen.add(e.userId)));
        _cursor = r.hasMore ? r.nextCursor : null;
        _total = r.total ?? _total;
        _more = false;
      });
    } catch (_) {
      if (mounted) setState(() => _more = false);
    }
  }

  /// Onayla / Sil: satır hemen kayar (iyimser); hata olursa geri gelir ve hata bildirimi çıkar.
  Future<void> _decide(FollowRequest r, {required bool accept}) async {
    if (_leaving.contains(r.userId)) return;
    buHaptic(accept ? BuHaptic.light : BuHaptic.selection);
    setState(() => _leaving.add(r.userId));
    try {
      final left = await (accept ? _api.accept(r.userId) : _api.decline(r.userId));
      if (!mounted) return;
      await Future<void>.delayed(BuMotion.of(context, const Duration(milliseconds: 220)));
      if (!mounted) return;
      setState(() {
        _items.removeWhere((e) => e.userId == r.userId);
        _leaving.remove(r.userId);
        // Sunucunun kalan sayısı kesindir; yoksa yerel azaltma.
        final t = _total;
        _total = left ?? (t == null ? null : (t > 0 ? t - 1 : 0));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _leaving.remove(r.userId));
      BuToast.show(context, errorText(e), kind: BuToastKind.error);
    }
  }

  String _ago(String? iso) {
    final l = context.l10n;
    final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return l.notifNow;
    if (diff.inMinutes < 60) return l.bildirimShortMin('${diff.inMinutes}');
    final days = DateTime(now.year, now.month, now.day).difference(DateTime(d.year, d.month, d.day)).inDays;
    if (days <= 0) return l.bildirimShortHour('${diff.inHours}');
    if (days == 1) return l.bildirimYesterday;
    if (days < 7) return l.p03NotifShortDay('$days');
    return d.year == now.year ? '${d.day} ${newsMonthName(context, d.month)}' : newsLocalDate(context, iso);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final Widget body;
    if (_loading) {
      body = const FollowSkeletonCard(count: 4);
    } else if (_error != null && _items.isEmpty) {
      body = FollowStatusCard(
        error: true,
        icon: BuIcons.wifiOff,
        title: l.p18FollowErrorTitle,
        message: errorText(_error!),
        onRetry: _load,
      );
    } else if (_items.isEmpty) {
      body = FollowStatusCard(
        key: const ValueKey('follow-requests-empty'),
        icon: BuIcons.userPlus,
        title: l.frqReqEmpty,
      );
    } else {
      final n = _total ?? _items.length;
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        FollowSectionLabel(l.frqReqPending('$n')),
        FollowCard(children: [
          for (var i = 0; i < _items.length; i++)
            _RequestRow(
              key: ValueKey('follow-request-${_items[i].userId}'),
              session: widget.session,
              request: _items[i],
              ago: _ago(_items[i].requestedAt),
              leaving: _leaving.contains(_items[i].userId),
              onAccept: () => _decide(_items[i], accept: true),
              onDecline: () => _decide(_items[i], accept: false),
            ),
        ]),
        if (_more) const Padding(padding: EdgeInsets.only(top: 12), child: FollowSkeletonCard(count: 2)),
      ]);
    }
    return Scaffold(
      backgroundColor: context.bu.bg,
      body: Column(children: [
        BuHeader(title: l.frqReqTitle, onBack: () => Navigator.maybePop(context)),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _load(silent: true),
            child: ListView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.paddingOf(context).bottom + 24),
              children: [body],
            ),
          ),
        ),
      ]),
    );
  }
}

/// İstek satırı: avatar (44), ad, bölüm, zaman; sağda Onayla (birincil) ve Sil (çizgili). Dar ekran / büyük yazıda
/// düğmeler adın altına (yan yana) iner (ad kesilmesin). Kabul/red sırasında satır yüksekliği 0'a kayar.
class _RequestRow extends StatelessWidget {
  const _RequestRow({
    super.key,
    required this.session,
    required this.request,
    required this.ago,
    required this.leaving,
    required this.onAccept,
    required this.onDecline,
  });

  final Session session;
  final FollowRequest request;
  final String ago;
  final bool leaving;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final r = request;
    final dept = context.departmentName((r.department ?? '').trim());
    final sub = [if (dept.isNotEmpty) dept, if (ago.isNotEmpty) ago].join(' · ');
    final narrow = MediaQuery.sizeOf(context).width < 420 || MediaQuery.textScalerOf(context).scale(10) > 11.5;

    final accept = Semantics(
      label: l.frqReqAcceptSem(r.displayName),
      excludeSemantics: true,
      button: true,
      onTap: leaving ? null : onAccept,
      child: BuButton(
        key: ValueKey('follow-request-accept-${r.userId}'),
        label: l.frqReqAccept,
        compact: true,
        onPressed: leaving ? null : onAccept,
      ),
    );
    final decline = Semantics(
      label: l.frqReqDeclineSem(r.displayName),
      excludeSemantics: true,
      button: true,
      onTap: leaving ? null : onDecline,
      child: BuButton(
        key: ValueKey('follow-request-decline-${r.userId}'),
        label: l.frqReqDecline,
        kind: BuButtonKind.outline,
        compact: true,
        onPressed: leaving ? null : onDecline,
      ),
    );

    final info = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(r.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tx.titleMedium!.copyWith(fontSize: 15, fontWeight: FontWeight.w600, color: t.ink)),
      if (sub.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: tx.bodyMedium!.copyWith(fontSize: 13, color: t.mut)),
        ),
    ]);
    final avatar = AvatarLongPress(
      imageUrl: r.avatarUrl,
      headers: postAuthHeaders(session),
      title: r.displayName,
      child: BuAvatar(name: r.displayName, url: r.avatarUrl, size: 44, headers: postAuthHeaders(session)),
    );

    final content = narrow
        ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [avatar, const SizedBox(width: 12), Expanded(child: info)]),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 56),
              child: Wrap(spacing: 8, runSpacing: 0, children: [accept, decline]),
            ),
          ])
        : Row(children: [
            avatar,
            const SizedBox(width: 12),
            Expanded(child: info),
            const SizedBox(width: 8),
            accept,
            const SizedBox(width: 4),
            decline,
          ]);

    final row = Semantics(
      container: true,
      child: InkWell(
        onTap: () => openUserProfile(context, session, userId: r.userId, name: r.displayName, avatarUrl: r.avatarUrl),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 12, 8),
          child: content,
        ),
      ),
    );
    return ClipRect(
      child: IgnorePointer(
        ignoring: leaving,
        child: AnimatedAlign(
          alignment: Alignment.topCenter,
          heightFactor: leaving ? 0 : 1,
          duration: BuMotion.of(context, const Duration(milliseconds: 220)),
          curve: Curves.easeOutCubic,
          child: row,
        ),
      ),
    );
  }
}
