import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../widgets/bu.dart';
import '../../widgets/common.dart';
import '../academic/academic_api.dart';
import '../academic/academic_hub_page.dart';
import '../academic/academic_models.dart';
import '../events/event_detail_page.dart';
import '../events/events_page.dart';
import '../menu/menu_models.dart';
import '../menu/menu_page.dart';
import '../menu/menu_parts.dart' show menuDishTitle;
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

/// Ana sayfa (Stitch v3): selamlama + düzenle/zil, arama, "Bugün" tek bakış yüzeyi, ardından kullanıcının sıraladığı
/// bölümler (Hızlı erişim, Günün menüsü, Bugünkü dersler, Öne çıkan haberler, Yaklaşan etkinlikler, Duyurular).
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

  // İlk boyama için gerekmeyen bölümler görünür olunca yüklenir (gizli bölümün verisi hiç istenmez).
  final _feeds = {_newsFeedHaber: _Feed(), _newsFeedDuyuru: _Feed()};
  bool _newsStale = false;
  bool _statusRequested = false;

  // Bölüm verileri bir kez istenir (görünür olunca); gizliyken istek atılmaz.
  bool _eventRequested = false;

  // Ders programı + yaklaşan sınav: "Bugün" yüzeyi ve "Bugünkü dersler" bölümü için, ilk boyamadan sonra arka planda.
  bool _academicRequested = false;
  TimetableData? _timetable;
  List<Exam> _exams = const [];

  /// Kullanıcıya özel yerel düzen (bölüm sırası/görünürlüğü + Hızlı Erişim kısayolları).
  late final HomeLayoutController _layout = HomeLayoutController(uid: widget.session.userId);

  bool _loading = true;
  Object? _error;
  int _gen = 0;

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
    if (v.isVisible(HomeSection.upcomingEvents) && !_eventRequested) unawaited(_loadFeaturedSafe());
  }

  void _apply(int gen, VoidCallback f) {
    if (mounted && gen == _gen) setState(f);
  }

  /// Çekirdek bölümler (paralel): bilgi, özet, bugünün menüsü ("Bugün" yüzeyi için hep) + GÖRÜNÜR ise sıradaki etkinlik.
  Future<void> _load() async {
    final gen = ++_gen;
    final api = _s.api;
    final wantEvent = _layout.value.isVisible(HomeSection.upcomingEvents);
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
    unawaited(_loadAcademic()); // ilk boyamayı beklemez; hata sessiz
  }

  /// `GET /events/featured`: yaklaşan etkinlikler içinde en çok katılımcılı olan. 204/boş gövde -> null (boş durum).
  Future<void> _loadFeatured(int gen) async {
    final r = await _s.api.get('/events/featured', force: _force);
    final best = r is Map ? Map<String, dynamic>.from(r) : null;
    _apply(gen, () {
      _event = best;
      _eventFailed = false;
    });
  }

  /// Sonradan görünür yapılan etkinlik bölümü için tek başına yükleyici (hata: bölüm içi "Tekrar dene").
  Future<void> _loadFeaturedSafe() async {
    _eventRequested = true;
    try {
      await _loadFeatured(_gen);
    } catch (_) {
      if (mounted) setState(() => _eventFailed = true);
    }
  }

  Future<void> _retryFeatured() async {
    if (_eventRetrying) return;
    setState(() => _eventRetrying = true);
    try {
      await _loadFeatured(_gen);
    } catch (_) {
      if (mounted) _toast(context.l10n.homeEventLoadFailedToast);
    } finally {
      if (mounted) setState(() => _eventRetrying = false);
    }
  }

  /// Ders programı (`GET /timetable`) + yaklaşan sınavlar (`GET /timetable/exams/upcoming`): mevcut uçlar, hata sessiz.
  Future<void> _loadAcademic() async {
    _academicRequested = true;
    final api = AcademicApi(_s);
    final results = await Future.wait([
      api.timetable().then<Object?>((v) => v).catchError((Object _) => null),
      api.upcomingExams(days: 30).then<Object?>((v) => v).catchError((Object _) => null),
    ]);
    if (!mounted) return;
    setState(() {
      final tt = results[0];
      final ex = results[1];
      if (tt is TimetableData) _timetable = tt;
      if (ex is List<Exam>) _exams = ex;
    });
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
        if (_academicRequested) _loadAcademic(),
      ]);
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

  /// Ana Sayfa düzenleme sayfası (başlıktaki kalem, bölüm başlığında uzun basma, boş durumdaki "Bölüm ekle").
  void _editLayout() {
    BuHaptics.selection();
    openHomeLayoutPage(context, _layout);
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

  // --- "Bugün" ve dersler için akademik veri ---

  DateTime get _wallNow => istanbulWall(academicClock());

  /// Bugünün kalan/süren oturumları (en çok 3).
  List<DaySlot> _todaySlots() {
    final tt = _timetable;
    if (tt == null) return const [];
    final w = _wallNow;
    final today = DateTime.utc(w.year, w.month, w.day);
    return slotsForDay(tt.courses, tt.semester, today, nowWall: w).where((e) => e.status != SlotStatus.past).take(3).toList();
  }

  List<({String label, String value, VoidCallback onTap, bool muted})> _todayRows(BuildContext context) {
    final l = context.l10n;
    final rows = <({String label, String value, VoidCallback onTap, bool muted})>[];
    // Öğle yemeği: ilk iki yemek + "+N" + toplam kcal; liste yoksa soluk tek cümle.
    final day = _today == null ? const MenuDay() : MenuDay.fromJson(_today!);
    final names = [for (final d in _dishes(day)) d.name];
    if (names.isEmpty) {
      rows.add((label: l.yemekLunch, value: l.homeNoMenuToday, onTap: () => _push(MenuPage(session: _s)), muted: true));
    } else {
      final extra = names.length - 2;
      final kcal = day.totalKcal;
      final value = '${names.take(2).join(', ')}${extra > 0 ? ' +$extra' : ''}${kcal != null ? ' · ${day.kcalComplete ? l.p03MenuKcal('$kcal') : l.p03MenuAtLeast('$kcal')}' : ''}';
      rows.add((label: l.yemekLunch, value: value, onTap: () => _push(MenuPage(session: _s)), muted: false));
    }
    // Sıradaki ders (akademik veri yoksa satır gizlenir).
    final tt = _timetable;
    if (tt != null) {
      final n = nextSlot(tt.courses, tt.semester, _wallNow);
      if (n != null) {
        final s = n.slot;
        final w = _wallNow;
        final isToday = s.date.year == w.year && s.date.month == w.month && s.date.day == w.day;
        final prefix = isToday ? '' : '${newsWeekdayName(context, s.date.weekday, short: true)} ';
        final room = s.session.room;
        rows.add((
          label: l.p60NextClass,
          value: '$prefix${s.session.start} ${s.course.name}${room != null && room.trim().isNotEmpty ? ' · ${room.trim()}' : ''}',
          onTap: () => _push(AcademicHubPage(session: _s)),
          muted: false,
        ));
      }
    }
    // Yaklaşan sınav.
    final now = academicClock();
    final ex = [for (final e in _exams) if (!e.startsAt.isBefore(now)) e]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    if (ex.isNotEmpty) {
      final e = ex.first;
      final w = istanbulWall(e.startsAt);
      final name = (e.courseName ?? '').trim().isNotEmpty ? e.courseName!.trim() : e.title;
      rows.add((label: l.p60UpcomingExam, value: '${w.day} ${newsMonthName(context, w.month)} · $name', onTap: () => _push(AcademicHubPage(session: _s)), muted: false));
    }
    return rows;
  }

  List<MenuDish> _dishes(MenuDay day) => day.dishes.isNotEmpty ? day.dishes : [for (final s in day.items) MenuDish(s)];

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
    final todayRows = _todayRows(context);
    final slots = _todaySlots();
    // Bölüm içeriği var mı: dersler yoksa bölüm hiç çizilmez (boş durum yok).
    bool hasContent(HomeSection s) => s != HomeSection.todayClasses || slots.isNotEmpty;
    final anyVisible = layout.order.any((s) => layout.isVisible(s) && hasContent(s));
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
      // "Bugün": sabit, gizlenemez; satırlar yüklendikçe/boşalınca yükseklik + solma geçişi.
      HomeSectionSlot(
        key: const ValueKey('slot-today'),
        visible: todayRows.isNotEmpty,
        builder: () => stag(Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0), // Stitch: arama alt boşluğu 20 (12 + satır içi 12 = 24 yerine 8 + 12)
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            HomeSectionHeader(title: l.p60Today, onLongPress: _editLayout),
            HomeTodayCard(rows: todayRows),
          ]),
        )),
      ),
    ];
    for (final s in layout.order) {
      final on = layout.isVisible(s) && hasContent(s);
      out.add(HomeSectionSlot(
        key: ValueKey('slot-${s.id}'),
        visible: on,
        // Görünürken kademeli giriş sırası (gizliyken kurulmaz): builder yalnız görünürken çağrılır.
        builder: () => stag(Padding(padding: const EdgeInsets.only(top: 12), child: _sectionBody(context, s, slots))),
      ));
    }
    if (!anyVisible) {
      out.add(Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: HomeEmptyHome(
          title: l.p60EmptyTitle,
          subtitle: l.p60EmptySub,
          actionLabel: l.p60EmptyAction,
          onAction: _editLayout,
          resetLabel: l.p60ResetDefault,
          onReset: _layout.reset,
        ),
      ));
    }
    return out;
  }

  Widget _sectionBody(BuildContext context, HomeSection s, List<DaySlot> slots) => switch (s) {
        HomeSection.quickAccess => _quickAccess(context),
        HomeSection.menu => _menuSection(context),
        HomeSection.todayClasses => _classesSection(context, slots),
        HomeSection.featuredNews => _newsSection(context, _newsFeedHaber),
        HomeSection.upcomingEvents => _eventSection(context),
        HomeSection.announcements => _newsSection(context, _newsFeedDuyuru),
      };

  Widget _pad(Widget child) => Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: child);

  /// Haber bölümü: "Öne çıkan haberler" (yatay şerit) ya da "Duyurular" (kısa liste). Veri bölüm görününce istenir.
  Widget _newsSection(BuildContext context, String type) {
    final l = context.l10n;
    final feed = _feeds[type]!;
    final news = feed.items;
    final announce = type == _newsFeedDuyuru;
    Widget list;
    if (news == null && (feed.loading || !feed.failed)) {
      list = _pad(BuSkeletonScope(child: BuSkeleton(height: announce ? 132 : HomeNewsCard.heightFor(1), radius: BuRadius.md)));
    } else if (news == null) {
      list = _pad(HomeNewsStateCard(
        emptyText: announce ? l.p60NoAnnouncements : l.p60NoNews,
        errorText: l.homeContentLoadFailed,
        retryLabel: l.commonRetry,
        onRetry: () => _loadFeed(type),
      ));
    } else if (news.isEmpty) {
      list = _pad(HomeNewsStateCard(emptyText: announce ? l.p60NoAnnouncements : l.p60NoNews));
    } else if (announce) {
      list = _pad(HomeAnnouncementList(
        items: [
          for (final n in news)
            (title: (n['title'] as String?) ?? '', date: newsLocalDate(context, n['publishedDate'] as String?), onTap: () => _push(NewsDetailPage(session: _s, item: n))),
        ],
      ));
    } else {
      final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
      list = HomeNewsStrip(
        height: HomeNewsCard.heightFor(scale),
        itemExtent: HomeNewsCard.cardWidth,
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
          _pad(HomeSectionHeader(
            title: announce ? l.anasayfaAnnouncements : l.p03HomeFeaturedNews,
            action: l.homeAll,
            onAction: () => _push(NewsListPage(session: _s, initialType: type)),
            onLongPress: _editLayout,
          )),
          list,
        ],
      ),
    );
  }

  /// Bugünkü dersler: bugünün kalan/süren oturumları (en çok 3); sağda soluk gün adı. Ders yoksa bölüm çizilmez.
  Widget _classesSection(BuildContext context, List<DaySlot> slots) {
    final l = context.l10n;
    final w = _wallNow;
    return _pad(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      HomeSectionHeader(title: l.p60SectionClasses, trailing: newsWeekdayName(context, w.weekday), onLongPress: _editLayout),
      HomeClassList(
        rows: [
          for (final e in slots)
            (
              time: e.session.start,
              title: e.course.name,
              sub: [
                if ((e.session.room ?? '').trim().isNotEmpty) l.p60Classroom(e.session.room!.trim()),
                if ((e.course.instructor ?? '').trim().isNotEmpty) e.course.instructor!.trim(),
              ].join(' · '),
            ),
        ],
        onTap: () => _push(AcademicHubPage(session: _s)),
      ),
    ]));
  }

  /// Üst çubuk: "İyi günler" + "Merhaba, Ad"; sağda ana sayfayı düzenle (kalem) ve bildirimler (zil, okunmamış noktası).
  Widget _header(BuildContext context, {bool afterBanner = false}) {
    final l = context.l10n;
    final name = (_s.displayName ?? '').trim();
    return Padding(
      padding: EdgeInsets.fromLTRB(20, (afterBanner ? 0 : MediaQuery.of(context).padding.top) + 12, 20, 0),
      child: HomeBrandHeader(
        greeting: _greeting(context),
        hello: name.isEmpty ? l.anasayfaHelloNoName : l.anasayfaHello(name),
        actions: [
          BuIconButton(icon: LucideIcons.pencil, tooltip: l.p60EditHome, onTap: _editLayout),
          ValueListenableBuilder<int>(
            valueListenable: _s.badges.notifications,
            builder: (_, n, __) => BuIconButton(
              icon: LucideIcons.bell,
              badge: n > 0,
              tooltip: l.notifTitle,
              onTap: () => _push(NotificationsPage(session: _s)),
            ),
          ),
        ],
      ),
    );
  }

  /// "Yaklaşan etkinlikler": başlık + (en çok katılımcılı) etkinlik satırı ya da boş/hata satırı.
  Widget _eventSection(BuildContext context) {
    final l = context.l10n;
    return _pad(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      HomeSectionHeader(title: l.p03HomeUpcoming, action: l.homeAll, onAction: () => _push(EventsPage(session: _s)), onLongPress: _editLayout),
      _eventBody(context),
    ]));
  }

  Widget _eventBody(BuildContext context) {
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
        actionLabel: l.homeBrowseEvents,
        onAction: () => _push(EventsPage(session: _s)),
      );
    }
    final id = (e['id'] as num?)?.toInt();
    final official = e['source'] == 'OFFICIAL';
    final loc = ((e['location'] as String?) ?? '').trim();
    final d = DateTime.tryParse((official ? e['date'] : e['startsAt']) as String? ?? '')?.toLocal();
    final club = (e['communityName'] as String?)?.trim() ?? '';
    final hasTime = !official && d != null;
    final time = hasTime ? '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}' : '';
    final month = d == null ? '' : _monthShort(context, d.month);
    return HomeEventList(rows: [
      (
        month: month,
        day: d == null ? '' : '${d.day}',
        title: (e['title'] as String?) ?? '',
        sub: [if (!official && club.isNotEmpty) club, if (time.isNotEmpty) time, if (time.isEmpty && loc.isNotEmpty) loc].join(' · '),
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
      ),
    ]);
  }

  /// "KAS" gibi büyük harfli üç harflik ay kısaltması (Arapçada tam ad).
  String _monthShort(BuildContext context, int month) {
    final name = newsMonthName(context, month);
    if (Localizations.localeOf(context).languageCode == 'ar') return name;
    return trUpper(name).characters.take(3).toString();
  }

  /// Hızlı erişim: kullanıcının seçtiği en çok 5 kısayol (varsayılan: Haberler / Yemek / Etkinlikler / Anketler / Program).
  /// Hedefler mevcut ekranlardır (sekmeye geçenler kabuğa yönlendirir).
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
    final shortcuts = _layout.value.shortcuts;
    final labels = [for (final sc in shortcuts) homeShortcutLabel(l, sc)];
    // Karolar aynı boyda olsun: en çok sözcüklü etiket kadar satır.
    final lines = labels.fold<int>(1, (m, s) => s.split(' ').length > m ? s.split(' ').length : m).clamp(1, 2);
    return _pad(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      HomeSectionHeader(title: l.p03HomeQuickTitle, onLongPress: _editLayout),
      HomeQuickGrid(
        key: ValueKey(shortcuts.map((e) => e.id).join(',')),
        labels: labels,
        tiles: [
          for (var i = 0; i < shortcuts.length; i++) HomeQuickTile(icon: homeShortcutIcon(shortcuts[i]), label: labels[i], lines: lines, onTap: go(shortcuts[i])),
        ],
      ),
    ]));
  }

  /// Günün menüsü: yemek adı + kcal satırları ve toplam enerji; sağda `Menüyü aç`. Liste yoksa başlık + soluk tek cümle.
  Widget _menuSection(BuildContext context) {
    final l = context.l10n;
    final day = _today == null ? const MenuDay() : MenuDay.fromJson(_today!);
    final dishes = _dishes(day);
    final header = HomeSectionHeader(title: l.p03HomeMealTitle, action: l.p60OpenMenu, accent: true, onAction: () => _push(MenuPage(session: _s)), onLongPress: _editLayout);
    if (dishes.isEmpty) {
      return _pad(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        header,
        Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(l.homeNoMenuToday, style: BuType.body.copyWith(color: context.bu.mut))),
      ]));
    }
    final anyKcal = dishes.any((d) => d.kcal != null);
    final total = day.totalKcal;
    return _pad(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      header,
      HomeMenuCard(
        dishes: [for (final d in dishes) (name: menuDishTitle(d.name), kcal: d.kcal == null ? null : l.p03MenuKcal('${d.kcal}'))],
        kcalText: anyKcal,
        totalLabel: total == null ? null : l.p03MenuTotalEnergy,
        totalValue: total == null ? null : (day.kcalComplete ? '${l.p03MenuTotal} ${l.p03MenuKcal('$total')}' : l.p03MenuAtLeast('$total')),
        onTap: () => _push(MenuPage(session: _s)),
      ),
    ]));
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
