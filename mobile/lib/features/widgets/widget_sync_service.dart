/// Ana ekran widget'larının veri hattı: uygulamanın MEVCUT API katmanından (ETag/304 önbellekli `session.api`) hafif
/// okumalar yapar, widget başına tek bir snapshot JSON'u üretip paylaşımlı depoya yazar ve widget'lara "yeniden çiz"
/// der. Kaynak sitelere istek YOKTUR (yalnız kendi sunucumuz). Her adım sessizdir: hata uygulamayı bozmaz, önceki
/// snapshot korunur. Sözleşme: design/widget-previews/DATA_CONTRACT.md.
library;

import 'dart:async';
import 'dart:convert';
import '../../core/swallow.dart';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../core/locale_controller.dart';
import '../../core/session.dart';
import '../academic/academic_api.dart';
import '../academic/academic_models.dart' show istanbulWall, parseInstant;
import '../menu/menu_models.dart';
import '../polls/poll_api.dart';
import '../polls/poll_models.dart';
import 'widget_snapshots.dart';
import 'widget_store.dart';
import 'widget_strings.dart';

class WidgetSyncService {
  WidgetSyncService._();

  static final WidgetSyncService instance = WidgetSyncService._();

  /// Testlerde sahte depo ve saat verilir.
  WidgetStore store = HomeWidgetStore();
  DateTime Function() clock = DateTime.now;

  Session? _session;
  Timer? _debounce;
  final Set<WidgetSlug> _queued = {};
  bool _running = false;
  bool _rerun = false;

  /// Hesap/oturum nesli: [clear] her çağrıda artırır. Uçuştaki bir eşitleme, başlarken aldığı nesil değişmişse
  /// (çıkış, hesap değişimi) sonucunu YAZMAZ; böylece eski hesabın verisi yeni hesabın widget'ına sızmaz.
  int _gen = 0;

  /// Kişisel widget'larda ayrıntıyı gizleme tercihi (cihaza özel; çıkışta silinmez, hesaptan bağımsız gizlilik seçimi).
  static const String privacyKey = 'bu_widget_privacy';

  static const Set<WidgetSlug> personalSlugs = {WidgetSlug.timetable, WidgetSlug.exams, WidgetSlug.social};

  Future<bool> hidePersonal() async => (await store.get(privacyKey)) == '1';

  /// Tercihi kaydeder ve kişisel widget'ları hemen yeniden yazar (oturum yoksa yalnız tercih saklanır).
  Future<void> setHidePersonal(bool hide) async {
    await store.put(privacyKey, hide ? '1' : '0');
    if (_session == null) return;
    _queued.addAll(personalSlugs);
    _debounce?.cancel();
    await syncNow();
  }

  /// Debounce süresi: art arda tetikleyiciler (açılış + oturum + dil) tek eşitlemede birleşir.
  static const Duration debounceDelay = Duration(seconds: 2);

  bool get attached => _session != null;

  /// Oturum bağlanınca hizmet etkinleşir. Bağlanmadan yapılan tüm çağrılar no-op'tur (testler/ön yükleme).
  void attach(Session session) => _session = session;

  @visibleForTesting
  void detach() {
    _debounce?.cancel();
    _debounce = null;
    _queued.clear();
    _session = null;
  }

  // ------------------------------------------------------------ tetikleyiciler

  /// Uygulama açılışı / ön plana geliş / oturum açma / dil değişimi / push: hepsi bunu çağırır.
  void refreshAll({String reason = 'manual'}) => request(WidgetSlug.values.toSet());

  /// İlgili veri değişince yalnız o widget'lar (ör. oy verince `{poll}`).
  void request(Set<WidgetSlug> slugs) {
    if (_session == null) return;
    _queued.addAll(slugs);
    _debounce?.cancel();
    _debounce = Timer(debounceDelay, () => unawaited(syncNow()));
  }

  /// Push yükünden hangi widget'ların tazeleneceğini çıkarır (yalnız tür adı; içerik okunmaz).
  void onPush(Map<String, dynamic>? data) {
    if (_session == null) return;
    final t = '${data?['targetType'] ?? data?['target'] ?? data?['type'] ?? ''}'.toUpperCase();
    final s = <WidgetSlug>{WidgetSlug.social};
    if (t.contains('EVENT')) s.add(WidgetSlug.events);
    if (t.contains('NEWS') || t.contains('ANNOUNCEMENT')) s.add(WidgetSlug.announcements);
    if (t.contains('POLL')) s.add(WidgetSlug.poll);
    if (t.contains('MEAL') || t.contains('MENU')) s.add(WidgetSlug.menu);
    if (t.contains('EXAM')) s.add(WidgetSlug.exams);
    if (t.contains('ACADEMIC') || t.contains('CALENDAR')) s.add(WidgetSlug.academic);
    if (t.contains('CLASS') || t.contains('TIMETABLE') || t.contains('COURSE')) s.add(WidgetSlug.timetable);
    request(s);
  }

  // ------------------------------------------------------------ eşitleme

  /// Kuyruktaki widget'ları hemen eşitler (testler bunu doğrudan çağırır). Oturum yoksa depo temizlenir.
  Future<void> syncNow({Set<WidgetSlug>? only}) async {
    final session = _session;
    if (session == null) return;
    final slugs = {...?only, ..._queued};
    if (only == null && slugs.isEmpty) slugs.addAll(WidgetSlug.values);
    if (session.state == SessionState.loading) {
      _queued.addAll(slugs); // oturum henüz geri yüklenmedi: silme/yazma yok, geri yüklenince tekrar denenir
      return;
    }
    _queued.clear();
    if (_running) {
      _rerun = true;
      _queued.addAll(slugs);
      return;
    }
    _running = true;
    try {
      if (session.state != SessionState.signedIn) {
        await clear(lang: session.api.lang);
        return;
      }
      final now = clock();
      final b = WidgetSnapshotBuilder(lang: session.api.lang, now: now);
      final written = <WidgetSlug>{};
      final gen = _gen;
      final owner = session.userId;
      // Hesap/oturum değişti mi (çıkış, hesap değişimi)? Değiştiyse bu turun hiçbir çıktısı yazılmaz.
      bool stale() => gen != _gen || session.state != SessionState.signedIn || session.userId != owner;
      final hide = await hidePersonal();
      for (final slug in slugs) {
        try {
          final snap = hide && personalSlugs.contains(slug) ? b.hidden(slug) : await _build(slug, b, session);
          if (snap == null) continue; // ağ/okuma hatası: önceki snapshot kalır
          if (stale()) return;
          await store.put(slug.key, jsonEncode(snap));
          written.add(slug);
        } catch (e) {
          swallow('widget.sync_one', e);
          // Tek widget'ın hatası diğerlerini etkilemez.
        }
      }
      if (stale()) return;
      await store.put(kWidgetMetaKey, jsonEncode(b.meta(signedIn: true, ownerUserId: owner)));
      if (written.isNotEmpty) await store.reload(written);
      await _scheduleMidnight(now);
    } catch (e) {
      swallow('widget.sync', e);
      // Eşitleme uygulamayı asla bozmaz.
    } finally {
      _running = false;
      if (_rerun) {
        _rerun = false;
        unawaited(syncNow());
      }
    }
  }

  Future<void> _scheduleMidnight(DateTime now) async {
    try {
      final w = istanbulWall(now);
      // Ertesi gün 00:05 İstanbul.
      final at = DateTime.utc(w.year, w.month, w.day + 1, 0, 5).subtract(const Duration(hours: 3));
      await store.scheduleMidnight(at, const [WidgetSlug.menu, WidgetSlug.timetable, WidgetSlug.events]);
    } catch (e) {
      swallow('widget.midnight', e);
    }
  }

  /// Çıkış / hesap değişimi / hesap silme: TÜM snapshot'lar silinir, meta `signedIn=false` yazılır ve widget'lar
  /// "Giriş yap" boş durumuna döner. Kişisel veri (kısayol sırası) da silinir.
  Future<void> clear({String? lang}) async {
    try {
      _gen++;
      _debounce?.cancel();
      _queued.clear();
      for (final s in WidgetSlug.values) {
        await store.remove(s.key);
      }
      final b = WidgetSnapshotBuilder(lang: normalizeWidgetLang(lang), now: clock());
      await store.put(kWidgetMetaKey, jsonEncode(b.meta(signedIn: false)));
      await store.reload(WidgetSlug.values);
      await QuickAccessPrefs.clear();
    } catch (e) {
      swallow('widget.clear', e);
    }
  }

  /// `registerUserDataCleaners` kancası: oturum bağlı olmasa da (token silinince) depoyu temizler.
  static Future<void> clearUserData() async {
    final s = instance;
    await s.clear(lang: s._session?.api.lang ?? LocaleController.current?.locale.languageCode);
  }

  // ------------------------------------------------------------ veri okuma

  Future<Map<String, Object?>?> _build(WidgetSlug slug, WidgetSnapshotBuilder b, Session session) async {
    switch (slug) {
      case WidgetSlug.menu:
        final byDay = await _readMenu(session, b.today);
        return byDay == null ? null : b.menu(byDay);
      case WidgetSlug.timetable:
        final t = await AcademicApi(session).timetable();
        return b.timetable(t.courses, t.semester);
      case WidgetSlug.events:
        final e = await _readEvents(session);
        return e == null ? null : b.events(e);
      case WidgetSlug.announcements:
        final n = await _readNews(session);
        return n == null ? null : b.announcements(n);
      case WidgetSlug.poll:
        return b.poll(await _readPoll(session));
      case WidgetSlug.quickaccess:
        return b.quickAccess(order: await QuickAccessPrefs.load());
      case WidgetSlug.exams:
        final x = await _readExams(session);
        return x == null ? null : b.exams(x);
      case WidgetSlug.academic:
        final a = await _readAcademic(session, b.today);
        return a == null ? null : b.academic(a);
      case WidgetSlug.social:
        final likes = await _readSocialLikes(session);
        return b.social(
          unreadMessages: session.badges.chat.value,
          newNotifications: session.badges.notifications.value,
          newLikesAndFollowers: likes ?? 0,
        );
    }
  }

  Future<Map<DateTime, MenuDay>?> _readMenu(Session session, DateTime today) async {
    final months = <String>{
      for (var i = 0; i <= 2; i++) () {
        final d = today.add(Duration(days: i));
        return '${d.year}-${d.month.toString().padLeft(2, '0')}';
      }(),
    };
    final out = <DateTime, MenuDay>{};
    var ok = false;
    for (final m in months) {
      try {
        final res = await session.api.get('/menu?month=$m');
        ok = true;
        if (res is List) {
          for (final e in res) {
            if (e is! Map) continue;
            final d = DateTime.tryParse('${e['date'] ?? ''}');
            if (d == null) continue;
            out[DateTime.utc(d.year, d.month, d.day)] = MenuDay.fromJson(e);
          }
        }
      } catch (e) {
        swallow('widget.read_menu', e);
      }
    }
    return ok ? out : null;
  }

  Future<List<WidgetEventInput>?> _readEvents(Session session) async {
    try {
      final res = await session.api.get('/events?size=10');
      final items = res is Map && res['items'] is List ? res['items'] as List : const [];
      final out = <WidgetEventInput>[];
      for (final e in items) {
        if (e is! Map) continue;
        final status = '${e['status'] ?? 'ACTIVE'}'.toUpperCase();
        final id = e['id'] is num ? (e['id'] as num).toInt() : null;
        final at = parseInstant(e['startsAt']);
        final community = '${e['communityName'] ?? ''}'.trim();
        if (id == null || at == null || status != 'ACTIVE' || e['communityId'] == null || community.isEmpty) continue;
        out.add(WidgetEventInput(
          id: id,
          title: '${e['title'] ?? ''}',
          communityName: community,
          startsAt: at,
          venue: e['location'] is String ? e['location'] as String : null,
        ));
      }
      return out;
    } catch (e) {
      swallow('widget.read_events', e);
      return null;
    }
  }

  /// Kullanıcının kendi yaklaşan sınavları (başkasının verisi okunmaz).
  Future<List<WidgetExamInput>?> _readExams(Session session) async {
    try {
      final list = await AcademicApi(session).upcomingExams(days: 60);
      return [
        for (final e in list)
          WidgetExamInput(id: e.id, title: e.title, courseName: e.courseName, type: e.type, startsAt: e.startsAt, room: e.room),
      ];
    } catch (e) {
      swallow('widget.read_exams', e);
      return null;
    }
  }

  /// Herkese açık akademik takvim: bugünden 60 gün.
  Future<List<WidgetAcademicInput>?> _readAcademic(Session session, DateTime today) async {
    try {
      final list = await AcademicApi(session).calendarRange(today, today.add(const Duration(days: 60)));
      return [
        for (final e in list)
          WidgetAcademicInput(id: e.id, kind: e.kind, title: e.title, startsAt: e.startsAt, endsAt: e.endsAt),
      ];
    } catch (e) {
      swallow('widget.read_academic', e);
      return null;
    }
  }

  Future<List<WidgetNewsInput>?> _readNews(Session session) async {
    try {
      final res = await session.api.get('/news?type=DUYURU&page=0&size=8');
      final items = res is Map && res['items'] is List ? res['items'] as List : const [];
      final out = <WidgetNewsInput>[];
      for (final e in items) {
        if (e is! Map) continue;
        final id = e['id'] is num ? (e['id'] as num).toInt() : null;
        final title = '${e['title'] ?? ''}'.trim();
        final raw = '${e['publishedDate'] ?? ''}';
        final d = raw.length >= 10 ? DateTime.tryParse(raw.substring(0, 10)) : null;
        if (id == null || title.isEmpty || d == null) continue;
        out.add(WidgetNewsInput(id: id, title: title, publishedDay: DateTime.utc(d.year, d.month, d.day)));
      }
      return out;
    } catch (e) {
      swallow('widget.read_news', e);
      return null;
    }
  }

  /// "Günün anketi": açık, genel (GLOBAL), tek/çoklu seçimli, 2-4 seçenekli ilk anket. Menü puanlaması ve kulüp anketleri
  /// dışarıda kalır. Kimlik/oy veren ASLA okunmaz (gizli oy), yalnız toplu sayılar.
  Future<WidgetPollInput?> _readPoll(Session session) async {
    try {
      final page = await PollApi(session).list(scope: 'open', size: 10);
      for (final p in page.items) {
        if (p.scope != 'GLOBAL' || p.isClosed(clock()) || p.notOpenYet) continue;
        if (p.type != PollType.single && p.type != PollType.multi) continue;
        if (p.options.length < 2 || p.options.length > 4 || p.menuItems.isNotEmpty) continue;
        return WidgetPollInput(
          id: p.id,
          question: p.title,
          options: [for (final o in p.options) WidgetPollOptionInput(o.text, p.countOf(o))],
          userVoted: p.hasVote,
          resultsVisible: p.resultsVisible,
          totalVotes: p.participants,
          closesAt: p.closesAt == null ? null : DateTime.tryParse(p.closesAt!),
          multi: p.type == PollType.multi,
        );
      }
    } catch (e) {
      swallow('widget.read_poll', e);
    }
    return null;
  }

  /// Okunmamış sosyal bildirim sayısı (beğeni/takip kategorisi). Kişi adı OKUNMAZ, yalnız adet.
  Future<int?> _readSocialLikes(Session session) async {
    try {
      final res = await session.api.get('/notifications?unread=true&category=SOCIAL&size=50');
      final items = res is Map && res['items'] is List ? res['items'] as List : const [];
      return items.length;
    } catch (e) {
      swallow('widget.read_likes', e);
      return null;
    }
  }
}
