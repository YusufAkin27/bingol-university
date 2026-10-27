import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/bu_widgets.dart';
import '../../widgets/common.dart';
import '../clubs/club_detail_page.dart';
import '../events/event_cover.dart';
import '../events/event_detail_page.dart';
import '../events/event_parts.dart';
import '../events/events_page.dart';
import '../menu/menu_page.dart';
import '../news/news_detail_page.dart';
import '../notifications/notifications_page.dart';
import '../search/search_page.dart';
import '../shell/app_shell.dart' show AppTab;
import '../support/support_page.dart';
import '../../core/typography.dart';

/// Ana sayfa: selamlama, arama, sıradaki etkinlik, hızlı erişim, bento kutular, kulüpler, gündem.
class HomeTab extends StatefulWidget {
  const HomeTab({super.key, required this.session, required this.onOpenTab});

  final Session session;

  /// Alt sekmeye geç (0 Ana Sayfa, 1 Keşfet, 2 Sohbet, 3 Kulüpler, 4 Profil); haber türü verilirse o filtre seçilir.
  final void Function(int tab, {String? newsType}) onOpenTab;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

const _newsTypes = [('HABER', 'Haber'), ('DUYURU', 'Duyuru'), ('ETKINLIK', 'Etkinlik')];
const _monthNames = [
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
];

class _HomeTabState extends State<HomeTab> {
  // Bölümler bağımsız yüklenir; null = henüz gelmedi ya da düştü.
  Map<String, dynamic>? _info;
  Map<String, dynamic>? _today;
  Map<String, dynamic>? _summary;
  Map<String, dynamic>? _event;
  bool _eventFailed = false; // öne çıkan etkinlik yüklenemedi: bölüm içi "Tekrar dene"
  bool _eventRetrying = false;
  List<Map<String, dynamic>> _avatars = const [];

  // İlk boyama için gerekmeyen bölümler görünür olunca yüklenir.
  List<Map<String, dynamic>>? _clubs;
  bool _clubsRequested = false;
  bool _clubsLoading = false;
  final Map<String, List<Map<String, dynamic>>> _news = {};
  final Set<String> _newsLoading = {};
  final Set<String> _newsFailed = {};
  bool _newsRequested = false;
  bool _newsStale = false;

  bool _loading = true;
  Object? _error;
  int _gen = 0;
  String _newsType = 'DUYURU';
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
        final r = await api.get('/app/info');
        _apply(gen, () => _info = r is Map<String, dynamic> ? r : null);
      }),
      step(() async {
        final r = await api.get('/menu/today');
        _apply(gen, () => _today = r is Map<String, dynamic> ? r : null);
      }),
      step(() async {
        final r = await api.get('/me/summary');
        if (r is! Map<String, dynamic>) return;
        // Çan ve alt gezinme rozetlerini tek kaynaktan eşitle.
        _s.badges.notifications.value = (r['unreadNotifications'] as num?)?.toInt() ?? 0;
        _s.badges.chat.value = (r['unreadMessages'] as num?)?.toInt() ?? 0;
        _apply(gen, () => _summary = r);
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
      if (mounted) _toast('Etkinlik yüklenemedi.');
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

  void _ensureClubs() {
    if (_clubsRequested) return;
    _clubsRequested = true;
    _loadClubs();
  }

  Future<void> _loadClubs() async {
    final gen = _gen;
    if (mounted) setState(() => _clubsLoading = true);
    try {
      final r = await _s.api.get('/me/communities?size=10') as Map<String, dynamic>;
      final l = List<Map<String, dynamic>>.from(r['items'] as List);
      _apply(gen, () => _clubs = l);
    } catch (_) {
      // Bölüm isteğe bağlı; düşerse gizli kalır.
    } finally {
      if (mounted) setState(() => _clubsLoading = false);
    }
  }

  void _ensureNews() {
    if (_newsRequested) return;
    _newsRequested = true;
    _loadNews(_newsType);
    unawaited(_loadStatus());
  }

  Future<void> _loadNews(String type) async {
    final gen = _gen;
    if (!mounted) return;
    setState(() {
      _newsLoading.add(type);
      _newsFailed.remove(type);
    });
    try {
      final r = await _s.api.get('/news?type=$type&page=0&size=3') as Map<String, dynamic>;
      final l = List<Map<String, dynamic>>.from(r['items'] as List);
      _apply(gen, () => _news[type] = l);
    } catch (_) {
      if (mounted) setState(() => _newsFailed.add(type));
    } finally {
      if (mounted) setState(() => _newsLoading.remove(type));
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

  void _selectNewsType(String type) {
    setState(() => _newsType = type);
    if (_news[type] == null && !_newsLoading.contains(type)) _loadNews(type);
  }

  Future<void> _reload() async {
    // Görünür olmuş tembel bölümler de tazelenir; yenileme hepsini bekler.
    await _load();
    if (!mounted) return;
    _news.removeWhere((k, _) => k != _newsType);
    await Future.wait([
      if (_clubsRequested) _loadClubs(),
      if (_newsRequested) ...[_loadNews(_newsType), _loadStatus()],
    ]);
  }

  void _push(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 6) return 'İyi geceler';
    if (h < 12) return 'Günaydın';
    if (h < 18) return 'İyi günler';
    return 'İyi akşamlar';
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
      _toast('Kontenjan doldu.');
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
      body = ErrorView(error: _error!, onRetry: () {
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
    final maintenance = _info?['maintenance'] as Map?;
    final banner = _info?['banner'] as Map?;
    return [
      _header(context),
      if (maintenance?['enabled'] == true)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: StaleBanner(text: (maintenance?['message'] as String?) ?? 'Sistem bakımda.'),
        ),
      if (banner != null && ((banner['text'] ?? banner['message']) as String?)?.isNotEmpty == true)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: InkWell(
            onTap: () => _openUrl(banner['url'] as String?),
            child: StaleBanner(
                text: (banner['text'] ?? banner['message']) as String, icon: LucideIcons.megaphone),
          ),
        ),
      if (_newsStale)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: StaleBanner(text: 'Kaynak site şu an ulaşılamıyor; veriler güncel olmayabilir.'),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: BuSearchField(
          hint: 'Haber, kulüp, etkinlik ara',
          readOnly: true,
          onTap: () => _push(SearchPage(session: _s)),
        ),
      ),
      Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 0), child: _eventCard(context)),
      Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 0), child: _quickAccess(context)),
      Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 0), child: _bento(context)),
      // Üyelik yoksa bölüm hiç istenmez; varsa görünür olunca yüklenir.
      if (_summary == null || ((_summary!['communities'] as num?) ?? 1) > 0)
        _LazyOnce(onFirstBuild: _ensureClubs, child: _clubsSection(context)),
      _LazyOnce(onFirstBuild: _ensureNews, child: _newsSection(context)),
    ];
  }

  Widget _clubsSection(BuildContext context) {
    final clubs = _clubs;
    if (clubs != null && clubs.isEmpty) return const SizedBox.shrink();
    if (clubs == null && !_clubsLoading) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BuSectionTitle('Kulüplerimden',
            action: 'Tümü', onAction: () => widget.onOpenTab(3), padding: const EdgeInsets.fromLTRB(20, 20, 20, 10)),
        SizedBox(
          height: 120,
          child: clubs == null
              ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: context.bu.pr))
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: clubs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => _clubCard(clubs[i], i),
                ),
        ),
      ],
    );
  }

  Widget _newsSection(BuildContext context) {
    final t = context.bu;
    final news = _news[_newsType];
    final loading = _newsLoading.contains(_newsType);
    Widget list;
    if (news == null && (loading || !_newsFailed.contains(_newsType))) {
      list = const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    } else if (news == null) {
      list = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(children: [
          Text('İçerik yüklenemedi.', style: TextStyle(color: t.mut)),
          TextButton(onPressed: () => _loadNews(_newsType), child: const Text('Tekrar dene')),
        ]),
      );
    } else if (news.isEmpty) {
      list = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Center(child: Text('Henüz içerik yok.', style: TextStyle(color: t.mut))),
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
        BuSectionTitle('Gündem',
            action: 'Tümü',
            onAction: () => widget.onOpenTab(1, newsType: _newsType),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10)),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            for (final nt in _newsTypes) ...[
              BuChip(label: nt.$2, selected: _newsType == nt.$1, onTap: () => _selectNewsType(nt.$1)),
              const SizedBox(width: 8),
            ],
          ]),
        ),
        const SizedBox(height: 12),
        list,
      ],
    );
  }

  Widget _header(BuildContext context) {
    final t = context.bu;
    final name = (_s.displayName ?? '').trim();
    return Padding(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: 'Profilim',
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => widget.onOpenTab(AppTab.profile),
                child: Row(
                  children: [
                    BuAvatar(name: name, size: 44, dark: false),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_greeting, style: BuType.caption.copyWith(color: t.mut)),
                          Text(name.isEmpty ? 'BÜ Kampüs' : name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: BuType.title.copyWith(color: t.ink)),
                        ],
                      ),
                    ),
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
              tooltip: 'Bildirimler',
              onTap: () => _push(NotificationsPage(session: _s)),
            ),
          ),
        ],
      ),
    );
  }

  String _eventWhen(Map<String, dynamic> e) {
    final d = DateTime.tryParse((e['startsAt'] as String?) ?? '')?.toLocal();
    if (d == null) return '';
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${_monthNames[d.month - 1]} · $hh:$mm';
  }

  Widget _eventCard(BuildContext context) {
    final e = _event;
    if (e == null && _eventFailed) {
      return BuHeroCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heroPill(LucideIcons.calendar, 'Öne çıkan etkinlik'),
            const SizedBox(height: 12),
            Text('Etkinlik yüklenemedi', style: BuType.title.copyWith(height: 1.2)),
            const SizedBox(height: 14),
            _whitePill('Tekrar dene', _retryFeatured, busy: _eventRetrying),
          ],
        ),
      );
    }
    if (e == null) {
      return BuHeroCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _heroPill(LucideIcons.calendar, 'Sıradaki etkinlik'),
            const SizedBox(height: 12),
            Text('Yaklaşan etkinlik yok',
                style: BuType.title.copyWith(height: 1.2)),
            const SizedBox(height: 14),
            _whitePill('Etkinliklere göz at', () => _push(EventsPage(session: _s))),
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
    final when = official ? niceDate(e['date'] as String?) : _eventWhen(e);
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
              _heroPill(LucideIcons.calendar, official ? 'Resmi etkinlik' : 'Öne çıkan etkinlik'),
              if (!official) _heroPill(LucideIcons.trendingUp, 'En çok katılım'),
            ]),
            const SizedBox(height: 10),
            Text((e['title'] as String?) ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: BuType.title.copyWith(height: 1.2)),
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
                  const Icon(LucideIcons.users, size: 16, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(going > 0 ? '$going kişi katılıyor' : 'İlk katılan sen ol',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.label),
                ),
                const SizedBox(width: 8),
                if (mine)
                  _whitePill('Etkinliklerimde', _openMyEvents, check: true)
                else if (full)
                  _whitePill('Dolu', null)
                else if (e['registrationClosed'] == true)
                  _whitePill('Kayıt kapalı', null)
                else
                  _whitePill('Katıl', id == null ? null : _join, busy: _rsvpBusy),
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
                  colors: [Colors.black.withValues(alpha: .25), Colors.black.withValues(alpha: .75)],
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
          Icon(icon, size: 13, color: Colors.white),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: busy
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: BuColors.red700))
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  if (check) ...const [
                    Icon(LucideIcons.check, size: 15, color: Color(0xFF8E1B13)),
                    SizedBox(width: 4),
                  ],
                  Text(label, style: BuType.label.copyWith(color: const Color(0xFF8E1B13))),
                ]),
        ),
      ),
    );
  }

  Widget _quickAccess(BuildContext context) {
    final items = <(IconData, String, ValueListenable<int>?, VoidCallback)>[
      (LucideIcons.messageCircle, 'Sohbet', _s.badges.chat, () => widget.onOpenTab(2)),
      (LucideIcons.users, 'Kulüpler', null, () => widget.onOpenTab(3)),
      (LucideIcons.calendar, 'Etkinlik', null, () => _push(EventsPage(session: _s))),
      (LucideIcons.utensils, 'Yemek', null, () => _push(MenuPage(session: _s))),
      (LucideIcons.lifeBuoy, 'Destek', null, () => _push(SupportPage(session: _s))),
    ];
    return Row(
      children: [
        for (final it in items)
          Expanded(child: _QuickItem(icon: it.$1, label: it.$2, badge: it.$3, onTap: it.$4)),
      ],
    );
  }

  Widget _bento(BuildContext context) {
    final t = context.bu;
    final items = List<String>.from((_today?['items'] as List?) ?? const []);
    final clubCount = (_summary?['communities'] as num?)?.toInt();
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 115,
            child: Material(
              color: t.soft,
              borderRadius: BorderRadius.circular(24),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _push(MenuPage(session: _s)),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 150),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(LucideIcons.utensils, size: 20, color: t.onSoft),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Bugünün yemeği',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: BuType.label.copyWith(color: t.onSoft)),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      Text(
                        items.isEmpty ? 'Bugün için liste yok' : items.take(4).join('\n'),
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: BuType.bodyStrong.copyWith(height: 1.5, color: t.onSoft),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 100,
            child: Column(
              children: [
                Expanded(
                  child: ValueListenableBuilder<int>(
                    valueListenable: _s.badges.chat,
                    builder: (_, n, __) => _statBox(
                      color: t.ink,
                      value: '$n',
                      label: 'yeni mesaj',
                      fg: t.bg,
                      sub: t.bg.withValues(alpha: .85),
                      arrow: t.bg,
                      border: false,
                      onTap: () => widget.onOpenTab(2),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: _statBox(
                    color: t.sf,
                    value: clubCount == null ? '–' : '$clubCount',
                    label: 'kulüp üyeliği',
                    fg: t.ink,
                    sub: t.mut,
                    arrow: t.pr,
                    border: true,
                    onTap: () => widget.onOpenTab(3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox({
    required Color color,
    required String value,
    required String label,
    required Color fg,
    required Color sub,
    required Color arrow,
    required bool border,
    required VoidCallback onTap,
  }) {
    final t = context.bu;
    return Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: border ? BorderSide(color: t.bd) : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: BuType.title.copyWith(color: fg, height: 1.2)),
                  Text(label,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.caption.copyWith(color: sub)),
                ],
              ),
            ),
            Icon(LucideIcons.arrowRight, size: 22, color: arrow),
          ]),
        ),
      ),
    );
  }

  Widget _clubCard(Map<String, dynamic> c, int i) {
    final t = context.bu;
    final id = (c['id'] as num?)?.toInt();
    final members = (c['memberCount'] as num?)?.toInt();
    return SizedBox(
      width: 168,
      child: BuCard(
        padding: const EdgeInsets.all(14),
        onTap: id == null ? null : () => _push(ClubDetailPage(session: _s, communityId: id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BuAvatar(name: c['name'] as String?, url: c['coverUrl'] as String?, size: 36, square: true, dark: i.isOdd),
            const SizedBox(height: 10),
            Text((c['name'] as String?) ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BuType.bodyStrong.copyWith(color: t.ink)),
            const SizedBox(height: 2),
            Text(members == null ? '' : '$members üye',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.caption.copyWith(color: t.mut)),
          ],
        ),
      ),
    );
  }

  Widget _newsRow(BuildContext context, Map<String, dynamic> n) {
    final t = context.bu;
    final img = n['imageUrl'] as String?;
    final type = n['type'] as String?;
    final eventDate = type == 'ETKINLIK' ? n['eventDate'] as String? : null;
    final dateText = (eventDate != null && eventDate.isNotEmpty)
        ? fmtDate(eventDate)
        : fmtDate(n['publishedDate'] as String?);
    return BuCard(
      padding: const EdgeInsets.all(12),
      radius: 18,
      onTap: () => _push(NewsDetailPage(session: _s, item: n)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NewsThumb(img, width: 72, height: 72, radius: 14),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  BuBadge(TypeBadge.label(type), soft: type == 'ETKINLIK'),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(dateText,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: BuType.caption.copyWith(color: t.mut)),
                  ),
                ]),
                const SizedBox(height: 6),
                Text((n['title'] as String?) ?? '',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: BuType.bodyStrong.copyWith(height: 1.3, color: t.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickItem extends StatelessWidget {
  const _QuickItem({required this.icon, required this.label, required this.onTap, this.badge});

  final IconData icon;
  final String label;
  final ValueListenable<int>? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 62,
            height: 62,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: t.sf,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: t.bd),
                  ),
                  child: Icon(icon, size: 24, color: t.pr),
                ),
                if (badge != null)
                  ValueListenableBuilder<int>(
                    valueListenable: badge!,
                    builder: (_, n, __) => n <= 0
                        ? const SizedBox.shrink()
                        : Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 18),
                              height: 18,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: t.pr,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(color: t.bg, width: 2),
                              ),
                              child: Text(n > 99 ? '99+' : '$n',
                                  style: BuType.micro.copyWith(color: t.onPr)),
                            ),
                          ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BuType.label.copyWith(color: t.ink)),
        ],
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
            Positioned(
              left: i * _step,
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
            Positioned(
              left: shown.length * _step,
              child: Container(
                width: _d,
                height: _d,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: const Color(0xFF171E33), border: Border.all(color: _ring, width: 2)),
                child: Text(extra > 99 ? '99+' : '+$extra',
                    maxLines: 1,
                    style: BuType.micro.copyWith(color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }
}
