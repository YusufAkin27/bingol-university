import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/common.dart';
import '../academic/academic_api.dart';
import '../academic/academic_hub_page.dart';
import '../academic/academic_models.dart';
import '../events/event_detail_page.dart';
import '../events/event_parts.dart';
import '../events/events_page.dart';
import '../menu/menu_models.dart';
import '../menu/menu_page.dart';
import '../menu/menu_parts.dart' show menuDishTitle;
import '../menu/menu_photo.dart';
import '../news/news_detail_page.dart';
import '../news/news_list_page.dart';
import '../news/news_tile.dart' show newsLocalDate, newsMonthName, newsWeekdayName;
import '../notifications/notifications_page.dart';
import '../polls/poll_routes.dart';
import '../profile/saved_news_page.dart';
import '../search/search_page.dart';
import '../shell/app_shell.dart' show AppTab;
import '../support/support_page.dart';
import 'home_layout.dart';
import 'home_layout_sheet.dart';
import 'home_parts.dart';

/// Ana sayfa: selamlama, arama, bugünün yemeği, hızlı erişim, öne çıkan haberler, (varsa) yaklaşan etkinlik.
class HomeTab extends StatefulWidget {
  const HomeTab({super.key, required this.session, required this.onOpenTab});

  final Session session;

  /// Alt sekmeye geç (0 Ana Sayfa, 1 Keşfet, 2 Sohbet, 3 Kulüpler, 4 Profil); haber türü verilirse o filtre seçilir.
  final void Function(int tab, {String? newsType}) onOpenTab;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

/// Ana sayfada gösterilen haber akışları: öne çıkan haberler (HABER, 5) ve duyurular (DUYURU, 3).
const _newsFeedHaber = 'HABER';
const _newsFeedDuyuru = 'DUYURU';

/// Öğle yemeği saatleri (yalnız öğle yemeği vardır; dilden bağımsız).
const _lunchHours = '11:30 – 14:00';

/// Bir haber akışının (tembel bölüm) durumu.
class _Feed {
  List<Map<String, dynamic>>? items;
  bool loading = false;
  bool failed = false;
  bool requested = false;
}

class _HomeTabState extends State<HomeTab> {
  // Bölümler bağımsız yüklenir; null = henüz gelmedi ya da düştü.
  Map<String, dynamic>? _info;
  Map<String, dynamic>? _today;
  Map<String, dynamic>? _event;
  bool _eventFailed = false; // öne çıkan etkinlik yüklenemedi: bölüm içi "Tekrar dene"
  bool _eventRetrying = false;
  List<Map<String, dynamic>> _avatars = const [];

  // İlk boyama için gerekmeyen bölümler görünür olunca yüklenir (gizli bölümün verisi hiç istenmez).
  final _feeds = {_newsFeedHaber: _Feed(), _newsFeedDuyuru: _Feed()};
  bool _newsStale = false;
  bool _statusRequested = false;

  // Bölüm verileri bir kez istenir (görünür olunca); gizliyken istek atılmaz.
  bool _menuRequested = false;
  bool _eventRequested = false;
  bool _classesRequested = false;
  TimetableData? _timetable;
  bool _classesLoading = false;
  bool _classesFailed = false;

  /// Kullanıcıya özel yerel düzen (bölüm sırası/görünürlüğü + Hızlı Erişim kısayolları).
  late final HomeLayoutController _layout = HomeLayoutController(uid: widget.session.userId);

  bool _loading = true;
  Object? _error;
  int _gen = 0;
  bool _rsvpBusy = false;

  Session get _s => widget.session;

  @override
  void initState() {
    super.initState();
    _layout.addListener(_onLayout);
    _boot();
  }

  @override
  void dispose() {
    _layout.removeListener(_onLayout);
    _layout.dispose();
    super.dispose();
  }

  /// Önce yerel düzen (hızlı), sonra yalnız görünür bölümlerin verisi.
  Future<void> _boot() async {
    await _layout.load();
    if (!mounted) return;
    await _load();
  }

  /// Düzen değişti: yeni görünür olan bölümün verisi (daha önce istenmediyse) şimdi istenir.
  void _onLayout() {
    if (!mounted) return;
    setState(() {});
    if (!_loading) _ensureSectionData();
  }

  void _ensureSectionData() {
    final v = _layout.value;
    if (v.isVisible(HomeSection.menu) && !_menuRequested) unawaited(_loadMenuSafe());
    if (v.isVisible(HomeSection.upcomingEvents) && !_eventRequested) unawaited(_loadFeaturedSafe());
    if (v.isVisible(HomeSection.todayClasses) && !_classesRequested) unawaited(_loadClasses());
  }

  void _apply(int gen, VoidCallback f) {
    if (mounted && gen == _gen) setState(f);
  }

  /// Çekirdek bölümler (paralel): bilgi, özet + yalnız GÖRÜNÜR bölümlerin verisi (yemek, sıradaki etkinlik).
  Future<void> _load() async {
    final gen = ++_gen;
    final api = _s.api;
    final layout = _layout.value;
    final wantMenu = layout.isVisible(HomeSection.menu);
    final wantEvent = layout.isVisible(HomeSection.upcomingEvents);
    if (wantMenu) _menuRequested = true;
    if (wantEvent) _eventRequested = true;
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
      if (wantMenu)
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
      if (wantEvent)
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
    _ensureSectionData(); // yükleme sırasında görünür olan bölüm varsa
  }

  /// Sonradan görünür yapılan bölümler için tek başına yükleyiciler (hata sessiz: bölüm kendi boş/hata durumunu gösterir).
  Future<void> _loadMenuSafe() async {
    _menuRequested = true;
    final gen = _gen;
    try {
      final res = await _s.api.getResponse('/menu/today', force: _force);
      final r = res.body;
      _apply(gen, () => _today = r is Map<String, dynamic> ? r : null);
    } catch (_) {}
  }

  Future<void> _loadFeaturedSafe() async {
    _eventRequested = true;
    try {
      await _loadFeatured(_gen);
    } catch (_) {
      if (mounted) setState(() => _eventFailed = true);
    }
  }

  /// Bugünkü dersler: yalnız bölüm görünürken `GET /timetable` (mevcut uç).
  Future<void> _loadClasses() async {
    _classesRequested = true;
    if (!mounted) return;
    setState(() {
      _classesLoading = true;
      _classesFailed = false;
    });
    try {
      final d = await AcademicApi(_s).timetable();
      if (mounted) setState(() => _timetable = d);
    } catch (_) {
      if (mounted) setState(() => _classesFailed = true);
    } finally {
      if (mounted) setState(() => _classesLoading = false);
    }
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

  // --- tembel bölümler ---

  void _ensureFeed(String type) {
    final f = _feeds[type]!;
    if (f.requested) return;
    f.requested = true;
    _loadFeed(type);
    if (!_statusRequested) {
      _statusRequested = true;
      unawaited(_loadStatus());
    }
  }

  Future<void> _loadFeed(String type) async {
    final f = _feeds[type]!;
    final gen = _gen;
    if (!mounted) return;
    setState(() {
      f.loading = true;
      f.failed = false;
    });
    try {
      final size = type == _newsFeedHaber ? 5 : 3;
      final r = await _s.api.get('/news?type=$type&page=0&size=$size', force: _force) as Map<String, dynamic>;
      final l = List<Map<String, dynamic>>.from(r['items'] as List);
      _apply(gen, () => f.items = l);
    } catch (_) {
      if (mounted) setState(() => f.failed = true);
    } finally {
      if (mounted) setState(() => f.loading = false);
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
      await Future.wait([
        for (final e in _feeds.entries)
          if (e.value.requested) _loadFeed(e.key),
        if (_statusRequested) _loadStatus(),
        if (_classesRequested && _layout.value.isVisible(HomeSection.todayClasses)) _loadClasses(),
      ]);
    } finally {
      _force = false;
    }
  }

  void _push(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

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
    if (!_loading && _error != null) {
      body = ErrorView(
          error: _error!,
          onRetry: () {
            setState(() => _loading = true);
            _load();
          });
    } else {
      // İskelet -> içerik: yalnız opaklık geçişi; kartlar ilk görünürde bir kez sırayla belirir (yenilemede oynamaz).
      body = BuSwapIn(
        loading: _loading,
        skeleton: const HomeSkeleton(),
        child: _loading
            ? const SizedBox.shrink()
            : RefreshIndicator(
                color: t.pr,
                onRefresh: _reload,
                child: BuStaggerScope(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: kNavInset),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: _content(context),
                  ),
                ),
              ),
      );
    }
    return ColoredBox(color: t.bg, child: body);
  }

  List<Widget> _content(BuildContext context) {
    final l = context.l10n;
    final maintenance = _info?['maintenance'] is Map ? _info!['maintenance'] as Map : null;
    final banner = _info?['banner'] is Map ? _info!['banner'] as Map : null;
    final banners = <Widget>[
      if (maintenance?['enabled'] == true)
        StaleBanner(
            text: (maintenance?['message'] is String ? maintenance!['message'] as String : null) ??
                l.homeMaintenanceDefault),
      if (banner != null && (banner['text'] ?? banner['message']) is String && ((banner['text'] ?? banner['message']) as String).isNotEmpty)
        InkWell(
          onTap: () => _openUrl(banner['url'] is String ? banner['url'] as String : null),
          child: StaleBanner(text: (banner['text'] ?? banner['message']) as String, icon: LucideIcons.megaphone),
        ),
      if (_newsStale) StaleBanner(text: l.homeSourceUnreachable, icon: LucideIcons.triangleAlert),
    ];
    // Kademeli giriş yalnız ilk ekrandaki blokta (ilk 4); aşağıdakiler kaydırırken animasyonlanmaz. Yalnız görünür bölümler sayılır.
    var slot = 0;
    Widget stag(Widget w) => BuStaggerItem(index: slot++, maxAnimated: 4, child: w);
    final layout = _layout.value;
    final visible = layout.visible;
    // Blok aralığı ritmi: 16 (arama -> ilk bölüm) / 24 (bölümler arası).
    final out = <Widget>[
      if (banners.isNotEmpty)
        stag(Padding(
          padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 8, 20, 0),
          child: Column(children: [
            for (var i = 0; i < banners.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              banners[i],
            ],
          ]),
        )),
      stag(_header(context, afterBanner: banners.isNotEmpty)),
      stag(Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: HomeSearchBox(hint: l.homeSearchHint, onTap: () => _push(SearchPage(session: _s))),
      )),
    ];
    for (final s in layout.order) {
      final on = layout.isVisible(s);
      final first = on && identical(visible.first, s);
      out.add(HomeSectionSlot(
        key: ValueKey('slot-${s.id}'),
        visible: on,
        // Görünürken kademeli giriş sırası (gizliyken kurulmaz): builder yalnız görünürken çağrılır.
        builder: () => stag(Padding(padding: EdgeInsets.only(top: first ? 16 : 24), child: _sectionBody(context, s))),
      ));
    }
    if (visible.isEmpty) {
      out.add(Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: HomeEmptyHome(title: l.p60EmptyTitle, actionLabel: l.p60EmptyAction, onAction: _editLayout),
      ));
    }
    return out;
  }

  Widget _sectionBody(BuildContext context, HomeSection s) => switch (s) {
        HomeSection.menu => Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _mealCard(context)),
        HomeSection.quickAccess => Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _quickAccess(context)),
        HomeSection.featuredNews => _newsSection(context, _newsFeedHaber),
        HomeSection.upcomingEvents => _eventSection(context),
        HomeSection.announcements => _newsSection(context, _newsFeedDuyuru),
        HomeSection.todayClasses => _classesSection(context),
      };

  /// Ana Sayfa düzenleme alt sayfası (başlıktaki düğme, bölüm başlığında uzun basma, boş durumdaki "Bölüm ekle").
  void _editLayout() {
    BuHaptics.selection();
    showHomeLayoutSheet(context, _layout);
  }

  /// Haber bölümü: "Öne Çıkan Haberler" (yatay şerit) ya da "Duyurular" (kısa liste). Veri bölüm görününce istenir.
  Widget _newsSection(BuildContext context, String type) {
    final l = context.l10n;
    final feed = _feeds[type]!;
    final news = feed.items;
    final announce = type == _newsFeedDuyuru;
    Widget list;
    if (news == null && (feed.loading || !feed.failed)) {
      list = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: BuSkeletonScope(child: BuSkeleton(height: announce ? 132 : 228, radius: BuRadius.lg)),
      );
    } else if (news == null) {
      list = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: HomeNewsStateCard(
          emptyText: l.homeNoContent,
          errorText: l.homeContentLoadFailed,
          retryLabel: l.commonRetry,
          onRetry: () => _loadFeed(type),
        ),
      );
    } else if (news.isEmpty) {
      list = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: HomeNewsStateCard(emptyText: l.homeNoContent),
      );
    } else if (announce) {
      list = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: HomeAnnouncementList(
          items: [
            for (final n in news)
              (title: (n['title'] as String?) ?? '', date: newsLocalDate(context, n['publishedDate'] as String?), onTap: () => _push(NewsDetailPage(session: _s, item: n))),
          ],
        ),
      );
    } else {
      final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
      list = HomeNewsStrip(
        height: HomeNewsCard.heightFor(scale),
        itemCount: news.length,
        itemBuilder: (context, i) {
          final n = news[i];
          return HomeNewsCard(
            title: (n['title'] as String?) ?? '',
            dateText: newsLocalDate(context, n['publishedDate'] as String?),
            imageUrl: n['imageUrl'] as String?,
            heroId: (n['id'] as num?)?.toInt(),
            onTap: () => _push(NewsDetailPage(session: _s, item: n)),
          );
        },
      );
    }
    return _LazyOnce(
      key: ValueKey('feed-$type'),
      onFirstBuild: () => _ensureFeed(type),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: HomeSectionHeader(
              title: announce ? l.anasayfaAnnouncements : l.p03HomeFeaturedNews,
              action: l.homeAll,
              onAction: () => _push(NewsListPage(session: _s, initialType: type)),
              onLongPress: _editLayout,
            ),
          ),
          list,
        ],
      ),
    );
  }

  /// Bugünkü dersler (isteğe bağlı bölüm): bugünün kalan/süren oturumları, en çok 3; veri yoksa tek satır.
  Widget _classesSection(BuildContext context) {
    final l = context.l10n;
    final tt = _timetable;
    Widget body;
    if (tt == null && (_classesLoading || !_classesFailed)) {
      body = const BuSkeletonScope(child: BuSkeleton(height: 92, radius: BuRadius.lg));
    } else if (tt == null) {
      body = HomeEmptyCard(icon: LucideIcons.cloudOff, headline: l.homeContentLoadFailed, actionLabel: l.commonRetry, onAction: _loadClasses, live: true);
    } else if (tt.courses.isEmpty) {
      body = HomeEmptyCard(icon: LucideIcons.graduationCap, headline: l.p60NoTimetable, onTap: () => _push(AcademicHubPage(session: _s)));
    } else {
      final w = istanbulWall(academicClock());
      final today = DateTime.utc(w.year, w.month, w.day);
      final slots = slotsForDay(tt.courses, tt.semester, today, nowWall: w).where((e) => e.status != SlotStatus.past).take(3).toList();
      body = slots.isEmpty
          ? HomeEmptyCard(icon: LucideIcons.graduationCap, headline: l.p60NoClassesToday, onTap: () => _push(AcademicHubPage(session: _s)))
          : HomeClassList(
              rows: [
                for (final e in slots)
                  (time: '${e.session.start} – ${e.session.end}', title: e.course.name, place: e.session.room ?? '', now: e.status == SlotStatus.ongoing),
              ],
              onTap: () => _push(AcademicHubPage(session: _s)),
            );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        HomeSectionHeader(
          title: l.p60SectionClasses,
          action: l.homeAll,
          onAction: () => _push(AcademicHubPage(session: _s)),
          onLongPress: _editLayout,
        ),
        body,
      ]),
    );
  }

  /// Üst çubuk: BÜ KAMPÜS + selamlama (tek blok), zil ve profil avatarı.
  Widget _header(BuildContext context, {bool afterBanner = false}) {
    final l = context.l10n;
    final name = (_s.displayName ?? '').trim();
    return Padding(
      padding: EdgeInsets.fromLTRB(20, (afterBanner ? 0 : MediaQuery.of(context).padding.top) + 12, 20, 0),
      child: HomeBrandHeader(
        displayName: name.isEmpty ? null : name,
        hello: name.isEmpty ? l.anasayfaHelloNoName : l.anasayfaHello(name),
        profileLabel: l.homeMyProfile,
        onProfile: () => widget.onOpenTab(AppTab.profile),
        bell: Row(mainAxisSize: MainAxisSize.min, children: [
          BuIconButton(icon: LucideIcons.slidersHorizontal, tooltip: l.p60EditHome, onTap: _editLayout),
          ValueListenableBuilder<int>(
            valueListenable: _s.badges.notifications,
            builder: (_, n, __) => BuIconButton(
              icon: LucideIcons.bell,
              badge: n > 0,
              tooltip: l.notifTitle,
              onTap: () => _push(NotificationsPage(session: _s)),
            ),
          ),
        ]),
      ),
    );
  }

  /// "Yaklaşan Etkinlik" bölümü: başlık + kart (ya da boş/hata durumu).
  Widget _eventSection(BuildContext context) {
    final l = context.l10n;
    final card = _eventCard(context);
    final has = _event != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (has) HomeSectionHeader(title: l.p03HomeUpcoming, action: l.homeAll, onAction: () => _push(EventsPage(session: _s)), onLongPress: _editLayout),
        card,
      ]),
    );
  }

  Widget _eventCard(BuildContext context) {
    final l = context.l10n;
    final e = _event;
    if (e == null && _eventFailed) {
      return HomeEmptyCard(
        icon: LucideIcons.cloudOff,
        headline: l.homeEventLoadFailedTitle,
        actionLabel: l.commonRetryShort,
        onAction: _eventRetrying ? null : _retryFeatured,
        live: true,
      );
    }
    if (e == null) {
      return HomeEmptyCard(
        icon: LucideIcons.calendarClock,
        headline: l.homeNoUpcoming,
        onTap: () => _push(EventsPage(session: _s)),
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
            ? '${newsWeekdayName(context, d.weekday, short: true)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}'
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

  /// Hızlı erişim: kullanıcının seçtiği en çok 5 kısayol (varsayılan: Haberler / Yemek / Etkinlikler / Anketler / Program).
  /// Tek mavi ton; hedefler mevcut ekranlardır (sekmeye geçenler kabuğa yönlendirir).
  Widget _quickAccess(BuildContext context) {
    final l = context.l10n;
    VoidCallback go(HomeShortcut sc) => switch (sc) {
          HomeShortcut.news => () => _push(NewsListPage(session: _s)),
          HomeShortcut.menu => () => _push(MenuPage(session: _s)),
          HomeShortcut.events => () => _push(EventsPage(session: _s)),
          HomeShortcut.polls => () => openPollList(context, _s),
          HomeShortcut.schedule => () => _push(AcademicHubPage(session: _s)),
          HomeShortcut.clubs => () => widget.onOpenTab(AppTab.clubs),
          HomeShortcut.chat => () => widget.onOpenTab(AppTab.chat),
          HomeShortcut.support => () => _push(SupportPage(session: _s)),
          HomeShortcut.search => () => _push(SearchPage(session: _s)),
          HomeShortcut.notifications => () => _push(NotificationsPage(session: _s)),
          HomeShortcut.bookmarks => () => _push(SavedNewsPage(session: _s)),
        };
    final items = [for (final sc in _layout.value.shortcuts) (homeShortcutIcon(sc), homeShortcutLabel(l, sc), go(sc))];
    // Başlık satırı yok (simgeler kendini anlatır); ekran okuyucu için kapsayıcı etiketi kalır.
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: l.p03HomeQuickTitle,
      child: HomeQuickGrid(
        key: ValueKey(_layout.value.shortcuts.map((e) => e.id).join(',')),
        labels: [for (final i in items) i.$2],
        tiles: [for (final i in items) HomeQuickTile(icon: i.$1, label: i.$2, tone: HomeTone.blue, onTap: i.$3)],
      ),
    );
  }

  /// Bugünün (öğle) yemeği: kırmızı vitrin kartı (fotoğraf varsa arka plan); liste yoksa tek satırlık boş durum.
  Widget _mealCard(BuildContext context) {
    final l = context.l10n;
    final today = _today == null ? const MenuDay() : MenuDay.fromJson(_today!);
    final items = today.items;
    if (items.isEmpty) {
      return HomeEmptyCard(
        icon: LucideIcons.utensils,
        headline: l.homeNoMenuToday,
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
  const _LazyOnce({super.key, required this.onFirstBuild, required this.child});

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
