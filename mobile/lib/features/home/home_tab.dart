import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/connectivity/offline_banner.dart' show StaleLabel;
import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../academic/academic_hub_page.dart';
import '../events/event_cover.dart';
import '../events/event_detail_page.dart';
import '../events/event_parts.dart';
import '../events/events_page.dart';
import '../menu/menu_models.dart';
import '../menu/menu_page.dart';
import '../menu/menu_photo.dart';
import '../news/news_detail_page.dart';
import '../news/news_tile.dart' show newsLocalDate, newsMonthName, newsTypeLabel;
import '../notifications/notifications_page.dart';
import '../search/search_page.dart';
import '../shell/app_shell.dart' show AppTab;
import '../support/support_page.dart';
import '../../core/typography.dart';
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
const _homeNewsType = 'DUYURU';

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

  /// Yanıt önbellekten (bayat) geldiyse sunucudan alındığı an; aksi halde null.
  DateTime? _staleInfoAt;
  DateTime? _staleMenuAt;

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
          _staleInfoAt = res.fromCache ? res.cachedAt : null;
        });
      }),
      step(() async {
        final res = await api.getResponse('/menu/today');
        final r = res.body;
        _apply(gen, () {
          _today = r is Map<String, dynamic> ? r : null;
          _staleMenuAt = res.fromCache ? res.cachedAt : null;
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
    final r = await _s.api.get('/events/featured');
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
      final r = await _s.api.get('/news?type=$_homeNewsType&page=0&size=3') as Map<String, dynamic>;
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

  Future<void> _reload() async {
    // Görünür olmuş tembel bölüm de tazelenir; yenileme hepsini bekler.
    await _load();
    if (!mounted) return;
    if (_newsRequested) await Future.wait([_loadNews(), _loadStatus()]);
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
      body = const LoadingView();
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
    return [
      _header(context),
      StaleLabel(cachedAt: _staleInfoAt ?? _staleMenuAt),
      if (maintenance?['enabled'] == true)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: StaleBanner(text: (maintenance?['message'] is String ? maintenance!['message'] as String : null) ?? context.l10n.homeMaintenanceDefault),
        ),
      if (banner != null && (banner['text'] ?? banner['message']) is String && ((banner['text'] ?? banner['message']) as String).isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: InkWell(
            onTap: () => _openUrl(banner['url'] is String ? banner['url'] as String : null),
            child: StaleBanner(text: (banner['text'] ?? banner['message']) as String, icon: LucideIcons.megaphone),
          ),
        ),
      if (_newsStale)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: StaleBanner(text: context.l10n.homeSourceUnreachable),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: HomeSearchBox(hint: context.l10n.homeSearchHint, onTap: () => _push(SearchPage(session: _s))),
      ),
      Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 0), child: _quickAccess(context)),
      Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 0), child: _mealCard(context)),
      Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 0), child: _eventCard(context)),
      _LazyOnce(onFirstBuild: _ensureNews, child: _newsSection(context)),
    ];
  }

  Widget _newsSection(BuildContext context) {
    final t = context.bu;
    final news = _news;
    Widget list;
    if (news == null && (_newsLoading || !_newsFailed)) {
      list = const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    } else if (news == null) {
      list = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(children: [
          Text(context.l10n.homeContentLoadFailed, style: TextStyle(color: t.mut)),
          TextButton(onPressed: _loadNews, child: Text(context.l10n.commonRetryShort)),
        ]),
      );
    } else if (news.isEmpty) {
      list = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Center(child: Text(context.l10n.homeNoContent, style: TextStyle(color: t.mut))),
      );
    } else {
      list = Column(children: [
        for (final n in news)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: _newsRow(context, n),
          ),
      ]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: HomeSectionHeader(
            title: context.l10n.anasayfaAnnouncements,
            action: context.l10n.homeAll,
            onAction: () => widget.onOpenTab(1, newsType: _homeNewsType),
          ),
        ),
        list,
      ],
    );
  }

  Widget _header(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    final name = (_s.displayName ?? '').trim();
    return Padding(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
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
          ),
          const SizedBox(width: 8),
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

  String _eventWhen(BuildContext context, Map<String, dynamic> e) {
    final d = DateTime.tryParse((e['startsAt'] as String?) ?? '')?.toLocal();
    if (d == null) return '';
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${newsMonthName(context, d.month)} · $hh:$mm';
  }

  Widget _eventCard(BuildContext context) {
    final l = context.l10n;
    final e = _event;
    if (e == null && _eventFailed) {
      return BuHeroCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heroPill(LucideIcons.calendar, l.homeFeaturedEvent),
            const SizedBox(height: 12),
            Text(l.homeEventLoadFailedTitle, style: BuType.title.copyWith(height: 1.2)),
            const SizedBox(height: 14),
            _whitePill(l.commonRetryShort, _retryFeatured, busy: _eventRetrying),
          ],
        ),
      );
    }
    if (e == null) {
      return BuHeroCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heroPill(LucideIcons.calendar, l.homeNextEvent),
            const SizedBox(height: 12),
            Text(l.homeNoUpcoming, style: BuType.title.copyWith(height: 1.2)),
            const SizedBox(height: 14),
            _whitePill(l.homeBrowseEvents, () => _push(EventsPage(session: _s))),
          ],
        ),
      );
    }
    final id = (e['id'] as num?)?.toInt();
    final official = e['source'] == 'OFFICIAL';
    final going = (e['goingCount'] as num?)?.toInt() ?? 0;
    final mine = e['myRsvp'] == 'GOING';
    final cap = (e['capacity'] as num?)?.toInt();
    final full = cap != null && going >= cap;
    final loc = (e['location'] as String?) ?? '';
    final when = official ? newsLocalDate(context, e['date'] as String?) : _eventWhen(context, e);
    final cover = official ? null : fileUrl(e['coverUrl'] as String?);
    return GestureDetector(
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
      child: _heroShell(
        cover,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(spacing: 8, runSpacing: 6, children: [
              _heroPill(LucideIcons.calendar, official ? l.homeOfficialEvent : l.homeFeaturedEvent),
              if (!official) _heroPill(LucideIcons.trendingUp, l.homeMostAttended),
            ]),
            const SizedBox(height: 10),
            Text((e['title'] as String?) ?? '',
                maxLines: 2, overflow: TextOverflow.ellipsis, style: BuType.title.copyWith(height: 1.2)),
            const SizedBox(height: 6),
            Wrap(spacing: 14, runSpacing: 2, children: [
              if (when.isNotEmpty) Text(when, style: BuType.caption),
              if (loc.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(loc, maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.caption),
                ),
            ]),
            const SizedBox(height: 14),
            if (!official)
              Row(children: [
                if (_avatars.isNotEmpty)
                  _AvatarStack(avatars: _avatars, total: going)
                else
                  const Icon(LucideIcons.users, size: 14.5, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(going > 0 ? l.homeGoingCount(going.toString()) : l.homeBeFirst,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.label),
                ),
                const SizedBox(width: 8),
                if (mine)
                  _whitePill(l.homeInMyEvents, _openMyEvents, check: true)
                else if (full)
                  _whitePill(l.homeFull, null)
                else if (e['registrationClosed'] == true)
                  _whitePill(l.homeRegClosed, null)
                else
                  _whitePill(l.homeJoin, id == null ? null : _join, busy: _rsvpBusy),
              ]),
          ],
        ),
      ),
    );
  }

  /// Kapak varsa fotoğraf + koyu geçiş üstüne, yoksa kırmızı hero kart.
  Widget _heroShell(String? cover, {required Widget child}) {
    if (cover == null) return BuHeroCard(child: child);
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Stack(
        children: [
          Positioned.fill(child: EventCoverImage(url: cover, cacheWidth: 900)),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: .65), Colors.black.withValues(alpha: .85)],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: DefaultTextStyle.merge(style: const TextStyle(color: Colors.white), child: child),
          ),
        ],
      ),
    );
  }

  Widget _heroPill(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .2), borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11.5, color: Colors.white),
          const SizedBox(width: 6),
          Text(text, style: BuType.micro.copyWith(color: Colors.white)),
        ]),
      );

  Widget _whitePill(String label, VoidCallback? onTap, {bool busy = false, bool check = false}) {
    return Material(
      color: Colors.white.withValues(alpha: onTap == null ? .75 : 1),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: busy ? null : onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Center(
              widthFactor: 1,
              child: busy
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: BuColors.red700))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      if (check) ...const [
                        Icon(LucideIcons.check, size: 13.5, color: Color(0xFF8E1B13)),
                        SizedBox(width: 4),
                      ],
                      Text(label, style: BuType.label.copyWith(color: const Color(0xFF8E1B13))),
                    ]),
            ),
          ),
        ),
      ),
    );
  }

  /// Akademik / Yemek / Etkinlik / Destek.
  Widget _quickAccess(BuildContext context) {
    final l = context.l10n;
    final items = <(IconData, String, HomeTone, VoidCallback)>[
      (LucideIcons.graduationCap, l.anasayfaQuickAcademic, HomeTone.red, () => _push(AcademicHubPage(session: _s))),
      (LucideIcons.utensils, l.homeQuickFood, HomeTone.green, () => _push(MenuPage(session: _s))),
      (LucideIcons.calendar, l.homeQuickEvent, HomeTone.blue, () => _push(EventsPage(session: _s))),
      (LucideIcons.circleHelp, l.homeQuickSupport, HomeTone.amber, () => _push(SupportPage(session: _s))),
    ];
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: HomeQuickTile(icon: items[i].$1, label: items[i].$2, tone: items[i].$3, onTap: items[i].$4)),
        ],
      ],
    );
  }

  /// Bugünün (öğle) yemeği: fotoğrafsız kırmızı kart; fotoğraf varsa arka plan + koyu degrade.
  Widget _mealCard(BuildContext context) {
    final today = _today == null ? const MenuDay() : MenuDay.fromJson(_today!);
    final items = today.items;
    return MenuPhotoGate(
      url: today.imageUrl,
      builder: (context, photo) => HomeMealCard(
        title: context.l10n.anasayfaMealLunch,
        time: _lunchHours,
        text: items.isEmpty ? context.l10n.homeNoMenuToday : items.join(', '),
        photo: photo,
        photoLabel: context.l10n.menuPhotoLabel,
        onTap: () => _push(MenuPage(session: _s)),
      ),
    );
  }

  Widget _newsRow(BuildContext context, Map<String, dynamic> n) {
    final type = n['type'] as String?;
    final eventDate = type == 'ETKINLIK' ? n['eventDate'] as String? : null;
    final dateText =
        (eventDate != null && eventDate.isNotEmpty) ? fmtDate(eventDate) : fmtDate(n['publishedDate'] as String?);
    final label = newsTypeLabel(context, type);
    return HomeAnnouncementCard(
      meta: dateText.isEmpty ? label : '$label · $dateText',
      title: (n['title'] as String?) ?? '',
      onTap: () => _push(NewsDetailPage(session: _s, item: n)),
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

/// Katılımcı avatar yığını (en çok 3) + kalan sayı.
class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.avatars, required this.total});

  final List<Map<String, dynamic>> avatars;
  final int total;

  static const _d = 26.0;
  static const _step = 18.0;
  static const _ring = Color(0xFFE8362B);

  @override
  Widget build(BuildContext context) {
    final shown = avatars.take(3).toList();
    final extra = total - shown.length;
    final count = shown.length + (extra > 0 ? 1 : 0);
    return SizedBox(
      width: _d + _step * (count - 1),
      height: _d,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            PositionedDirectional(
              start: i * _step,
              child: Container(
                width: _d,
                height: _d,
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(shape: BoxShape.circle, color: _ring),
                child: BuAvatar(
                    name: shown[i]['displayName'] as String?, url: shown[i]['avatarUrl'] as String?, size: _d - 4),
              ),
            ),
          if (extra > 0)
            PositionedDirectional(
              start: shown.length * _step,
              child: Container(
                width: _d,
                height: _d,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: const Color(0xFF171E33), border: Border.all(color: _ring, width: 2)),
                child: Text(extra > 99 ? '99+' : '+$extra',
                    maxLines: 1, style: BuType.micro.copyWith(color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }
}
