import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../clubs/club_detail_page.dart';
import '../clubs/club_form_page.dart';
import '../clubs/club_join_flow.dart';
import '../clubs/club_categories.dart';
import '../clubs/clubs_widgets.dart';
import 'home_parts.dart' show HomeSectionHeader;

/// Ana Sayfa "Kulüpler" bölümü: yatay kaydırılan küçük kulüp kartları. Önce kullanıcının kulüpleri
/// (üye / istek bekleyen), sonra popüler (üye sayısı çok) kulüpler; kart: logo, ad, kategori · üye sayısı ve
/// durum ("Katıl" / "Üyesin" / "İstek gönderildi"). Başlıkta "Tümünü gör" tüm kulüpler sayfasını açar.
/// Kulüp yoksa bölüm gizlenmez: "Henüz kulüp yok" + "Kulüp kur". Ağ hatasında "yüklenemedi + yeniden dene".
class HomeClubs extends StatefulWidget {
  const HomeClubs({super.key, required this.session, required this.onOpenAll, this.onLongPressTitle, this.refreshToken});

  final Session session;

  /// "Tümünü gör": tüm kulüpler sayfası.
  final VoidCallback onOpenAll;

  /// Başlığa uzun basma: "Ana sayfayı düzenle".
  final VoidCallback? onLongPressTitle;

  /// Değişirse (çek-yenile) liste yeniden yüklenir.
  final Object? refreshToken;

  @override
  State<HomeClubs> createState() => _HomeClubsState();
}

class _HomeClubsState extends State<HomeClubs> {
  List<Map<String, dynamic>>? _items;
  Object? _error;
  int _gen = 0;
  final Set<int> _joining = {};

  static const _max = 12;

  @override
  void initState() {
    super.initState();
    _load();
    // Kategori adları (istek dilinde) listeden çözülür; yüklü değilse arka planda çekilip etiketler tazelenir.
    if (ClubCategories.active.isEmpty) {
      ClubCategories.load(widget.session.api).then((l) {
        if (mounted && l != null) setState(() {});
      });
    }
  }

  @override
  void didUpdateWidget(HomeClubs old) {
    super.didUpdateWidget(old);
    if (old.refreshToken != widget.refreshToken) _load(force: true);
  }

  static List<Map<String, dynamic>> _parse(dynamic res) {
    final raw = res is Map ? res['items'] : res;
    if (raw is! List) return [];
    return [for (final m in raw) if (m is Map) Map<String, dynamic>.from(m)];
  }

  static int _id(Map<String, dynamic> c) => (c['id'] as num?)?.toInt() ?? -1;

  /// İki istek paralel; biri düşse de gelen veri gösterilir, ikisi de düşerse hata durumu.
  Future<void> _load({bool force = false}) async {
    final g = ++_gen;
    if (_items == null || _error != null) setState(() => _error = null);
    final api = widget.session.api;
    Object? err;
    Future<List<Map<String, dynamic>>> get(String path) async {
      try {
        return _parse(await api.get(path, force: force));
      } catch (e) {
        err = e;
        return const [];
      }
    }

    final res = await Future.wait([get('/me/communities?size=50'), get('/communities?size=20')]);
    if (!mounted || g != _gen) return;
    final mine = [for (final c in res[0]) if (c['myStatus'] == 'ACTIVE' || c['myStatus'] == 'PENDING') c];
    final seen = {for (final c in mine) _id(c)};
    final rest = [
      for (final c in res[1])
        if (c['myStatus'] != 'BANNED' && c['myStatus'] != 'ACTIVE' && c['myStatus'] != 'PENDING' && seen.add(_id(c))) c,
    ]..sort((a, b) => ((b['memberCount'] as num?) ?? 0).compareTo((a['memberCount'] as num?) ?? 0));
    final all = [...mine, ...rest].take(_max).toList();
    setState(() {
      if (all.isEmpty && err != null) {
        _items = null;
        _error = err;
      } else {
        _items = all;
        _error = null;
      }
    });
  }

  Future<void> _open(Map<String, dynamic> c) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'club_detail'),
        builder: (_) => ClubDetailPage(session: widget.session, communityId: _id(c)),
      ),
    );
    if (mounted) _load(force: true);
  }

  Future<void> _join(Map<String, dynamic> c) async {
    final id = _id(c);
    if (_joining.contains(id)) return;
    setState(() => _joining.add(id));
    try {
      final st = await joinClubFlow(
        context,
        widget.session,
        communityId: id,
        clubName: (c['name'] ?? '').toString(),
        needsApproval: c['joinPolicy'] == 'APPROVAL' || c['visibility'] == 'PRIVATE',
      );
      if (!mounted || st == null) return;
      setState(() {
        c['myStatus'] = st;
        if (st == 'ACTIVE') c['memberCount'] = ((c['memberCount'] as num?) ?? 0).toInt() + 1;
      });
      if (st == 'ACTIVE') buHaptic(BuHaptic.light);
    } catch (e) {
      if (mounted) BuToast.show(context, errorText(e), kind: BuToastKind.error);
    } finally {
      if (mounted) setState(() => _joining.remove(id));
    }
  }

  Future<void> _create() async {
    if (await openCreateClub(context, widget.session) && mounted) _load(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final items = _items;
    final scale = (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 2.0);
    final height = HomeClubCard.heightFor(scale);
    return Column(
      key: const ValueKey('homeClubs'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: BuSpace.pageH,
          child: HomeSectionHeader(
            title: l.clubMgmtClubsTitle,
            action: l.homeViewAll,
            onAction: widget.onOpenAll,
            onLongPress: widget.onLongPressTitle,
          ),
        ),
        if (items == null && _error == null)
          SizedBox(height: height, child: const BuSkeletonScope(child: _SkeletonStrip()))
        else if (items == null)
          Padding(
            padding: BuSpace.pageH,
            child: _StateCard(
              key: const ValueKey('homeClubsError'),
              title: l.chcLoadFailed,
              actionLabel: l.commonRetry,
              onAction: () => _load(force: true),
            ),
          )
        else if (items.isEmpty)
          Padding(
            padding: BuSpace.pageH,
            child: _StateCard(
              key: const ValueKey('homeClubsEmpty'),
              title: l.chcEmptyTitle,
              body: l.chcEmptyBody,
              actionLabel: l.clubMgmtCreateTitle,
              onAction: _create,
            ),
          )
        else
          SizedBox(
            height: height,
            child: ListView.separated(
              key: const ValueKey('homeClubsStrip'),
              scrollDirection: Axis.horizontal,
              padding: BuSpace.pageH,
              itemCount: items.length,
              separatorBuilder: (_, __) => BuGap.w12,
              itemBuilder: (_, i) => HomeClubCard(
                club: items[i],
                busy: _joining.contains(_id(items[i])),
                onOpen: () => _open(items[i]),
                onJoin: () => _join(items[i]),
              ),
            ),
          ),
      ],
    );
  }
}

/// Ana Sayfa kulüp kartı: 48 dp logo, ad, "Kategori · N üye" ve durum satırı. Dokunma = kulüp detayı.
class HomeClubCard extends StatelessWidget {
  const HomeClubCard({super.key, required this.club, required this.busy, required this.onOpen, required this.onJoin});

  final Map<String, dynamic> club;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onJoin;

  static const double width = 160;

  /// Yazı ölçeğine göre kart yüksekliği: sabit kısım (logo + durum satırı + boşluklar) + 2 yazı satırı.
  static double heightFor(double textScale) => 138 + 40 * textScale.clamp(1.0, 2.0);

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    final l = context.l10n;
    final name = (club['name'] as String?) ?? '';
    final category = ClubCategories.labelFor(club['category'] as String?);
    final count = ((club['memberCount'] as num?) ?? 0).toInt();
    final status = (club['myStatus'] as String?) ?? 'NONE';
    final id = (club['id'] as num?)?.toInt() ?? 0;
    final sub = [if (category.isNotEmpty) category, l.clubMgmtMemberCount('$count')].join(' · ');
    return SizedBox(
      width: width,
      child: BuCard(
        key: ValueKey('home-club-$id'),
        padding: const EdgeInsetsDirectional.fromSTEB(BuSpace.md, BuSpace.md, BuSpace.md, BuSpace.xs),
        radius: BuRadius.md,
        onTap: onOpen,
        child: Semantics(
          container: true,
          label: '$name, $sub',
          child: Column(
            children: [
              ClubsLogo(name: name, id: id, url: club['logoUrl'] as String?),
              BuGap.h8,
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: tx.titleSmall?.copyWith(color: t.ink, fontSize: 14, fontWeight: FontWeight.w400)),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: tx.labelSmall?.copyWith(color: t.mut, fontSize: 12)),
              const Spacer(),
              SizedBox(height: 48, child: Center(child: _status(context, status))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _status(BuildContext context, String status) {
    final t = context.bu;
    final l = context.l10n;
    final muted = Theme.of(context).textTheme.bodySmall!.copyWith(color: t.mut, fontSize: 13);
    switch (status) {
      case 'ACTIVE':
        return Row(mainAxisSize: MainAxisSize.min, children: [
          ExcludeSemantics(child: Icon(BuIcons.check, size: 16, color: t.ok)),
          const SizedBox(width: 4),
          Flexible(child: Text(l.clubMgmtYouAreMember, maxLines: 1, overflow: TextOverflow.ellipsis, style: muted)),
        ]);
      case 'PENDING':
        return Text(l.clubMgmtRequestSent, maxLines: 1, overflow: TextOverflow.ellipsis, style: muted);
      default:
        return ClubJoinButton(label: l.clubMgmtJoin, busy: busy, onPressed: busy ? null : onJoin);
    }
  }
}

/// Boş / hata durumu kartı: ince çerçeve, kısa metin, marka renkli eylem.
class _StateCard extends StatelessWidget {
  const _StateCard({super.key, required this.title, this.body, this.actionLabel, this.onAction});

  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final tx = Theme.of(context).textTheme;
    return BuCard(
      radius: BuRadius.md,
      padding: const EdgeInsets.fromLTRB(BuSpace.lg, BuSpace.lg, BuSpace.lg, BuSpace.md),
      child: Semantics(
        container: true,
        liveRegion: true,
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: tx.titleSmall!.copyWith(color: t.ink, fontWeight: FontWeight.w400)),
              if (body != null) ...[
                const SizedBox(height: 4),
                Text(body!, style: tx.bodyMedium!.copyWith(color: t.mut, height: 1.45)),
              ],
              if (actionLabel != null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    style: TextButton.styleFrom(
                        foregroundColor: t.prText, minimumSize: const Size(48, 48), padding: EdgeInsets.zero, alignment: AlignmentDirectional.centerStart),
                    onPressed: onAction,
                    child: Text(actionLabel!, style: tx.titleSmall!.copyWith(color: t.prText, fontWeight: FontWeight.w400)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonStrip extends StatelessWidget {
  const _SkeletonStrip();

  @override
  Widget build(BuildContext context) => ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: BuSpace.pageH,
        itemCount: 3,
        separatorBuilder: (_, __) => BuGap.w12,
        itemBuilder: (_, __) => const SizedBox(
          width: HomeClubCard.width,
          child: BuCard(
            padding: EdgeInsets.all(BuSpace.md),
            radius: BuRadius.md,
            child: Column(children: [
              BuSkeleton.circle(48),
              BuGap.h8,
              BuSkeleton.line(width: 88, height: 14),
              BuGap.h6,
              BuSkeleton.line(width: 64),
              Spacer(),
              BuSkeleton(width: 72, height: 36, radius: 999),
            ]),
          ),
        ),
      );
}
