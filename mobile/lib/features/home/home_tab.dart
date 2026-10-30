import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/common.dart';
import '../academic/academic_hub_page.dart';
import '../events/event_detail_page.dart';
import '../events/event_parts.dart';
import '../events/events_page.dart';
import '../menu/menu_models.dart';
import '../menu/menu_page.dart';
import '../menu/menu_parts.dart' show menuDishTitle;
import '../menu/menu_photo.dart';
import '../news/news_detail_page.dart';
import '../news/news_list_page.dart';
import '../news/news_tile.dart' show newsLocalDate, newsMonthName, newsTypeLabel, newsWeekdayName;
import '../notifications/notifications_page.dart';
import '../search/search_page.dart';
import '../shell/app_shell.dart' show AppTab;
import 'home_parts.dart';

/// Ana sayfa: selamlama, arama, hızlı erişim, bugünün yemeği, (varsa) öne çıkan etkinlik, duyurular.
class HomeTab extends StatefulWidget {
  const HomeTab({super.key, required this.session, required this.onOpenTab});

  final Session session;

  /// Alt sekmeye geç (0 Ana Sayfa, 1 Keşfet, 2 Sohbet, 3 Kulüpler, 4 Profil); haber türü verilirse o filtre seçilir.
  final void Function(int tab, {String? newsType}) onOpenTab;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

/// Ana sayfada gösterilen liste türü (tasarım: yalnız "Duyurular").
const _homeNewsType = 'HABER';

/// Öğle yemeği saatleri (yalnız öğle yemeği vardır; dilden bağımsız).
const _lunchHours = '11:30 – 14:00';

class _HomeTabState extends State<HomeTab> {
  // Bölümler bağımsız yüklenir; null = henüz gelmedi ya da düştü.
  Map<String, dynamic>? _info;
  Map<String, dynamic>? _today;
  Map<String, dynamic>? _event;
  bool _eventFailed = false; // öne çıkan etkinlik yüklenemedi: bölüm içi "Tekrar dene"
  bool _eventRetrying = false;
  List<Map<String, dynamic>> _avatars = const [];

  // İlk boyama için gerekmeyen bölüm görünür olunca yüklenir.
  List<Map<String, dynamic>>? _news;
  bool _newsLoading = false;
  bool _newsFailed = false;
  bool _newsRequested = false;
  bool _newsStale = false;

  bool _loading = true;
  Object? _error;
  int _gen = 0;
  bool _rsvpBusy = false;

  Session get _s => widget.session;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _apply(int gen, VoidCallback f) {
    if (mounted && gen == _gen) setState(f);
  }

  /// Çekirdek bölümler (paralel): bilgi, yemek, özet, sıradaki etkinlik.
  Future<void> _load() async {
    final gen = ++_gen;
    final api = _s.api;
    var ok = 0;
    Object? firstError;
    Future<void> step(Future<void> Function() f) async {
      try {
        await f();
        ok++;
      } catch (e) {
        firstError ??= e;
      }
    }

    await Future.wait([
      step(() async {
        final res = await api.getResponse('/app/info');
        final r = res.body;
        _apply(gen, () {
          _info = r is Map<String, dynamic> ? r : null;
        });
      }),
      step(() async {
        final res = await api.getResponse('/menu/today', force: _force);
        final r = res.body;
        _apply(gen, () {
          _today = r is Map<String, dynamic> ? r : null;
        });
      }),
      step(() async {
        final r = await api.get('/me/summary');
        if (r is! Map<String, dynamic>) return;
        // Çan ve alt gezinme rozetlerini tek kaynaktan eşitle.
        _s.badges.notifications.value = (r['unreadNotifications'] as num?)?.toInt() ?? 0;
        _s.badges.chat.value = (r['unreadMessages'] as num?)?.toInt() ?? 0;
      }),
      step(() async {
        try {
          await _loadFeatured(gen);
        } catch (_) {
          _apply(gen, () => _eventFailed = true);
          rethrow;
        }
      }),
    ]);
    if (!mounted || gen != _gen) return;
    setState(() {
      _loading = false;
      _error = (ok == 0) ? firstError : null;
    });
  }

  /// `GET /events/featured`: yaklaşan etkinlikler içinde en çok katılımcılı olan. 204/boş gövde -> null (boş durum).
  Future<void> _loadFeatured(int gen) async {
    final r = await _s.api.get('/events/featured', force: _force);
    final best = r is Map ? Map<String, dynamic>.from(r) : null;
    final prev = best?['attendeesPreview'];
    final pl = prev is Map ? prev['avatars'] : prev;
    final avatars = [
      for (final a in (pl is List ? pl : const []))
        if (a is Map) Map<String, dynamic>.from(a),
    ];
    _apply(gen, () {
      _event = best;
      _eventFailed = false;
      _avatars = avatars;
    });
    final id = (best?['id'] as num?)?.toInt();
    if (best != null && avatars.isEmpty && id != null) unawaited(_loadPreview(id, gen));
  }

  Future<void> _retryFeatured() async {
    if (_eventRetrying) return;
    setState(() => _eventRetrying = true);
    final gen = _gen;
    try {
      await _loadFeatured(gen);
    } catch (_) {
      if (mounted) _toast(context.l10n.homeEventLoadFailedToast);
    } finally {
      if (mounted) setState(() => _eventRetrying = false);
    }
  }

  /// Katılımcı avatarları (herkese açık, en çok 8); hata sessizce yutulur.
  Future<void> _loadPreview(int eventId, int gen) async {
    try {
      final r = await _s.api.get('/events/$eventId/attendees/preview');
      if (r is! Map<String, dynamic>) return;
      final l = [
        for (final a in (r['avatars'] as List? ?? const []))
          if (a is Map<String, dynamic>) a,
      ];
      _apply(gen, () {
        if ((_event?['id'] as num?)?.toInt() != eventId) return;
        _avatars = l;
        final gc = r['goingCount'] as num?;
        if (gc != null && _event != null) _event = {..._event!, 'goingCount': gc.toInt()};
      });
    } catch (_) {}
  }

  // --- tembel bölüm ---

  void _ensureNews() {
    if (_newsRequested) return;
    _newsRequested = true;
    _loadNews();
    unawaited(_loadStatus());
  }

  Future<void> _loadNews() async {
    final gen = _gen;
    if (!mounted) return;
    setState(() {
      _newsLoading = true;
      _newsFailed = false;
    });
    try {
      final r = await _s.api.get('/news?type=$_homeNewsType&page=0&size=5', force: _force) as Map<String, dynamic>;
      final l = List<Map<String, dynamic>>.from(r['items'] as List);
      _apply(gen, () => _news = l);
    } catch (_) {
      if (mounted) setState(() => _newsFailed = true);
    } finally {
      if (mounted) setState(() => _newsLoading = false);
    }
  }

  Future<void> _loadStatus() async {
    final gen = _gen;
    try {
      final st = await _s.api.get('/status') as Map<String, dynamic>;
      final stale = (st['NEWS'] as Map?)?['maintenance'] == true || (st['MENU'] as Map?)?['maintenance'] == true;
      _apply(gen, () => _newsStale = stale);
    } catch (_) {}
  }

  /// Çekip yenileme sürerken taze önbellek süresi yok sayılır (ETag/304 ile ağdan doğrulanır).
  bool _force = false;

  Future<void> _reload() async {
    _force = true;
    try {
      // Görünür olmuş tembel bölüm de tazelenir; yenileme hepsini bekler.
      await _load();
      if (!mounted) return;
      if (_newsRequested) await Future.wait([_loadNews(), _loadStatus()]);
    } finally {
      _force = false;
    }
  }

  void _push(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  String _greeting(BuildContext context) {
    final l = context.l10n;
    final h = DateTime.now().hour;
    if (h < 6) return l.homeGreetNight;
    if (h < 12) return l.homeGreetMorning;
    if (h < 18) return l.homeGreetDay;
    return l.homeGreetEvening;
  }

  Future<void> _openUrl(String? url) async {
    final u = url == null ? null : Uri.tryParse(url);
    if (u != null && u.scheme == 'https') {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    }
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  /// "Katıl": GOING yazar ve Etkinliklerim'e ekler; kart üzerinden geri alma yoktur.
  Future<void> _join() async {
    final ev = _event;
    final id = (ev?['id'] as num?)?.toInt();
    if (ev == null || id == null || _rsvpBusy) return;
    final going = (ev['goingCount'] as num?)?.toInt() ?? 0;
    final cap = (ev['capacity'] as num?)?.toInt();
    if (cap != null && going >= cap) {
      _toast(context.l10n.homeQuotaFull);
      return;
    }
    final gen = _gen;
    setState(() {
      _rsvpBusy = true;
      _event = {...ev, 'myRsvp': 'GOING', 'goingCount': going + 1};
    });
    try {
      await _s.api.put('/events/$id/rsvp', {'status': 'GOING'});
      if (!mounted) return;
      showJoinedToast(context, _openMyEvents);
      unawaited(_loadPreview(id, gen));
    } catch (e) {
      if (!mounted) return;
      setState(() => _event = {
            ...ev,
            if (e is ApiError && e.code == 'EVENT_REGISTRATION_CLOSED') 'registrationClosed': true,
          });
      _toast(eventErrorText(e));
    } finally {
      if (mounted) setState(() => _rsvpBusy = false);
    }
  }

  void _openMyEvents() {
    if (mounted) _push(EventsPage(session: _s, initialTab: 1));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    Widget body;
    if (_loading) {
      body = const HomeSkeleton();
    } else if (_error != null) {
      body = ErrorView(
          error: _error!,
          onRetry: () {
            setState(() => _loading = true);
            _load();
          });
    } else {
      body = RefreshIndicator(
        color: t.pr,
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.only(bottom: kNavInset),
          physics: const AlwaysScrollableScrollPhysics(),
          children: _content(context),
        ),
      );
    }
    return ColoredBox(color: t.bg, child: body);
  }

  List<Widget> _content(BuildContext context) {
    final maintenance = _info?['maintenance'] is Map ? _info!['maintenance'] as Map : null;
    final banner = _info?['banner'] is Map ? _info!['banner'] as Map : null;
    final banners = <Widget>[
      if (maintenance?['enabled'] == true)
        StaleBanner(
            text: (maintenance?['message'] is String ? maintenance!['message'] as String : null) ??
                context.l10n.homeMaintenanceDefault),
      if (banner != null && (banner['text'] ?? banner['message']) is String && ((banner['text'] ?? banner['message']) as String).isNotEmpty)
        InkWell(
          onTap: () => _openUrl(banner['url'] is String ? banner['url'] as String : null),
          child: StaleBanner(text: (banner['text'] ?? banner['message']) as String, icon: LucideIcons.megaphone),
        ),
      if (_newsStale) StaleBanner(text: context.l10n.homeSourceUnreachable, icon: LucideIcons.triangleAlert),
    ];
    return [
      if (banners.isNotEmpty)
        Padding(
          padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 8, 20, 0),
          child: Column(children: [
            for (var i = 0; i < banners.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              banners[i],
            ],
          ]),
        ),
      _header(context, afterBanner: banners.isNotEmpty),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: HomeSearchBox(hint: context.l10n.homeSearchHint, onTap: () => _push(SearchPage(session: _s))),
      ),
      Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 0), child: _mealCard(context)),
      Padding(padding: const EdgeInsets.fromLTRB(20, 22, 20, 0), child: _quickAccess(context)),
      _LazyOnce(onFirstBuild: _ensureNews, child: _newsSection(context)),
      _eventSection(context),
    ];
  }

  Widget _newsSection(BuildContext context) {
    final l = context.l10n;
    final news = _news;
    Widget list;
    if (news == null && (_newsLoading || !_newsFailed)) {
      list = const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: BuSkeletonScope(child: BuSkeleton(height: 250, radius: 24)),
      );
    } else if (news == null) {
      list = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: HomeNewsStateCard(
          emptyText: l.homeNoContent,
          errorText: l.homeContentLoadFailed,
          retryLabel: l.commonRetry,
          onRetry: _loadNews,
        ),
      );
    } else if (news.isEmpty) {
      list = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: HomeNewsStateCard(emptyText: l.homeNoContent),
      );
    } else {
      final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
      list = SizedBox(
        height: 150 + 122 * scale.clamp(1.0, 1.5),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: news.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, i) {
            final n = news[i];
            return HomeNewsCard(
              title: (n['title'] as String?) ?? '',
              tag: newsTypeLabel(context, n['type'] as String?),
              dateText: newsLocalDate(context, n['publishedDate'] as String?),
              imageUrl: n['imageUrl'] as String?,
              onTap: () => _push(NewsDetailPage(session: _s, item: n)),
            );
          },
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: HomeSectionHeader(
            title: l.p03HomeFeaturedNews,
            action: l.homeAll,
            onAction: () => _push(NewsListPage(session: _s)),
          ),
        ),
        list,
      ],
    );
  }

  /// Marka çubuğu (logo + BU KAMPÜS + zil + profil) ve selamlama.
  Widget _header(BuildContext context, {bool afterBanner = false}) {
    final t = context.bu;
    final l = context.l10n;
    final name = (_s.displayName ?? '').trim();
    return Padding(
      padding: EdgeInsets.fromLTRB(20, (afterBanner ? 0 : MediaQuery.of(context).padding.top) + 12, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        HomeBrandHeader(
          displayName: name.isEmpty ? null : name,
          profileLabel: l.homeMyProfile,
          onProfile: () => widget.onOpenTab(AppTab.profile),
          bell: ValueListenableBuilder<int>(
            valueListenable: _s.badges.notifications,
            builder: (_, n, __) => BuIconButton(
              icon: LucideIcons.bell,
              badge: n > 0,
              tooltip: l.notifTitle,
              onTap: () => _push(NotificationsPage(session: _s)),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Semantics(
          button: true,
          label: l.homeMyProfile,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => widget.onOpenTab(AppTab.profile),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_greeting(context), style: BuType.body.copyWith(fontSize: 13, color: t.mut)),
                Text(name.isEmpty ? l.anasayfaHelloNoName : l.anasayfaHello(name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BuType.display.copyWith(fontSize: 24, letterSpacing: -.4, color: t.ink)),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  /// "Yaklaşan Etkinlik" bölümü: başlık + kart (ya da boş/hata durumu).
  Widget _eventSection(BuildContext context) {
    final l = context.l10n;
    final card = _eventCard(context);
    final has = _event != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (has) HomeSectionHeader(title: l.p03HomeUpcoming, action: l.homeAll, onAction: () => _push(EventsPage(session: _s))),
        card,
      ]),
    );
  }

  Widget _eventCard(BuildContext context) {
    final l = context.l10n;
    final e = _event;
    if (e == null && _eventFailed) {
      return HomeEmptyCard(
        title: l.p03HomeEventsTitle,
        icon: LucideIcons.cloudOff,
        headline: l.homeEventLoadFailedTitle,
        body: '',
        actionLabel: l.commonRetryShort,
        onAction: _eventRetrying ? null : _retryFeatured,
      );
    }
    if (e == null) {
      return HomeEmptyCard(
        title: l.p03HomeEventsTitle,
        trailingIcon: LucideIcons.calendarX,
        icon: LucideIcons.calendarClock,
        headline: l.homeNoUpcoming,
        body: l.p03HomeNoEventBody,
        actionLabel: l.homeBrowseEvents,
        onAction: () => _push(EventsPage(session: _s)),
      );
    }
    final id = (e['id'] as num?)?.toInt();
    final official = e['source'] == 'OFFICIAL';
    final going = (e['goingCount'] as num?)?.toInt() ?? 0;
    final mine = e['myRsvp'] == 'GOING';
    final cap = (e['capacity'] as num?)?.toInt();
    final full = cap != null && going >= cap;
    final loc = (e['location'] as String?) ?? '';
    final d = DateTime.tryParse((official ? e['date'] : e['startsAt']) as String? ?? '')?.toLocal();
    final club = (e['communityName'] as String?)?.trim();
    final hasTime = !official && d != null;
    final when = d == null
        ? null
        : hasTime
            ? '${newsWeekdayName(context, d.weekday)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}'
            : null;
    Widget? footer;
    if (!official) {
      Widget action;
      if (mine) {
        action = BuButton(label: l.homeInMyEvents, icon: LucideIcons.check, kind: BuButtonKind.soft, compact: true, onPressed: _openMyEvents);
      } else if (full) {
        action = BuButton(label: l.homeFull, compact: true, kind: BuButtonKind.soft, onPressed: null);
      } else if (e['registrationClosed'] == true) {
        action = BuButton(label: l.homeRegClosed, compact: true, kind: BuButtonKind.soft, onPressed: null);
      } else {
        action = BuButton(label: l.homeJoin, compact: true, busy: _rsvpBusy, onPressed: id == null ? null : _join);
      }
      footer = Row(children: [
        HomeAvatarStack(avatars: _avatars, total: going),
        const SizedBox(width: 10),
        Expanded(
          child: Text(going > 0 ? l.homeGoingCount(going.toString()) : l.homeBeFirst,
              maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall!.copyWith(color: context.bu.mut)),
        ),
        const SizedBox(width: 8),
        action,
      ]);
    }
    return HomeEventCard(
      title: (e['title'] as String?) ?? '',
      host: (!official && club != null && club.isNotEmpty) ? l.p03HomeHosts(club) : null,
      month: d == null ? null : trUpper(newsMonthName(context, d.month)),
      day: d == null ? null : '${d.day}',
      whenLine: when,
      location: loc,
      footer: footer,
      onTap: id == null
          ? null
          : () => official
              ? _push(NewsDetailPage(session: _s, item: {
                  'id': id,
                  'title': e['title'],
                  'type': 'ETKINLIK',
                  'imageUrl': e['imageUrl'],
                  'publishedDate': e['date'],
                  'url': e['url'],
                }))
              : _push(EventDetailPage(session: _s, eventId: id)),
    );
  }

  /// Hızlı erişim: Haberler / Yemek / Etkinlikler / Kulüpler / Ders Programı (gerçek işlevler).
  Widget _quickAccess(BuildContext context) {
    final l = context.l10n;
    final t = context.bu;
    final items = <(IconData, String, HomeTone, VoidCallback)>[
      (LucideIcons.newspaper, l.icerikNewsTitle, HomeTone.red, () => _push(NewsListPage(session: _s))),
      (LucideIcons.utensils, l.homeQuickFood, HomeTone.amber, () => _push(MenuPage(session: _s))),
      (LucideIcons.calendar, l.p03HomeQuickEvents, HomeTone.blue, () => _push(EventsPage(session: _s))),
      (LucideIcons.users, l.navClubs, HomeTone.green, () => widget.onOpenTab(AppTab.clubs)),
      (LucideIcons.graduationCap, l.p03HomeQuickSchedule, HomeTone.red, () => _push(AcademicHubPage(session: _s))),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsetsDirectional.only(start: 4, bottom: 10),
        child: Semantics(
          header: true,
          child: Text(l.p03HomeQuickTitle, style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w700, color: t.mut)),
        ),
      ),
      Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: HomeQuickTile(icon: items[i].$1, label: items[i].$2, tone: items[i].$3, onTap: items[i].$4)),
          ],
        ],
      ),
    ]);
  }

  /// Bugünün (öğle) yemeği: kırmızı vitrin kartı (fotoğraf varsa arka plan); liste yoksa boş durum kartı.
  Widget _mealCard(BuildContext context) {
    final l = context.l10n;
    final today = _today == null ? const MenuDay() : MenuDay.fromJson(_today!);
    final items = today.items;
    if (items.isEmpty) {
      return HomeEmptyCard(
        title: l.p03HomeMealTitle,
        subtitle: l.yemekLunch,
        icon: LucideIcons.utensils,
        headline: l.homeNoMenuToday,
        body: l.p03HomeNoMenuBody,
        onTap: () => _push(MenuPage(session: _s)),
      );
    }
    return MenuPhotoGate(
      url: today.imageUrl,
      builder: (context, photo) => HomeMealHero(
        chip: l.p03HomeLunchCount('${items.length}'),
        title: l.p03HomeMealHeroTitle,
        time: _lunchHours,
        dishes: [for (final s in items) menuDishTitle(s)],
        detailLabel: l.p03HomeMenuDetail,
        photo: photo,
        photoLabel: l.menuPhotoLabel,
        onTap: () => _push(MenuPage(session: _s)),
      ),
    );
  }
}

/// Alt ağaç ilk kez kurulduğunda (yani kaydırmayla yaklaşınca) bir kez tetikler.
class _LazyOnce extends StatefulWidget {
  const _LazyOnce({required this.onFirstBuild, required this.child});

  final VoidCallback onFirstBuild;
  final Widget child;

  @override
  State<_LazyOnce> createState() => _LazyOnceState();
}

class _LazyOnceState extends State<_LazyOnce> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onFirstBuild();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
