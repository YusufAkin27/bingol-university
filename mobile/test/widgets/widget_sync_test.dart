import 'dart:convert';

import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/user_data.dart';
import 'package:bu_kampus/features/widgets/widget_snapshots.dart';
import 'package:bu_kampus/features/widgets/widget_store.dart';
import 'package:bu_kampus/features/widgets/widget_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';

/// Cuma 6 Kasim 2026 10:00 Istanbul.
final DateTime kNow = DateTime.utc(2026, 11, 6, 7, 0);

FakeBackend backend() {
  final b = FakeBackend();
  b.on('/menu?month=2026-11', [
    {
      'date': '2026-11-06',
      'items': ['Mercimek Çorbası', 'Pilav'],
      'dishes': [
        {'name': 'Mercimek Çorbası', 'kcal': 150},
        {'name': 'Pilav', 'kcal': 380},
      ],
      'totalKcal': 530,
      'kcalComplete': true,
    },
  ]);
  b.on('/timetable', {
    'semester': null,
    'courses': [
      {
        'id': 1,
        'name': 'Algoritma',
        'sessions': [
          {'dayOfWeek': 5, 'start': '10:30', 'end': '11:20', 'room': 'B-204'},
        ],
      },
    ],
  });
  b.on('/events*', {
    'items': [
      {
        'id': 9,
        'title': 'Kodlama Gecesi',
        'status': 'ACTIVE',
        'communityId': 3,
        'communityName': 'Yazılım Kulübü',
        'startsAt': '2026-11-12T11:00:00Z',
        'location': 'Amfi 2',
      },
      // Kulupsuz ya da aktif olmayan etkinlik widget'a girmez.
      {'id': 10, 'title': 'X', 'status': 'PENDING_REVIEW', 'communityId': 3, 'communityName': 'K', 'startsAt': '2026-11-13T11:00:00Z'},
      {'id': 11, 'title': 'Y', 'status': 'ACTIVE', 'communityId': null, 'communityName': '', 'startsAt': '2026-11-14T11:00:00Z'},
    ],
  });
  b.on('/news*', {
    'items': [
      {'id': 5, 'title': 'Kayıt yenileme duyurusu', 'publishedDate': '2026-11-05', 'type': 'DUYURU'},
    ],
  });
  b.on('/polls*', {
    'items': [
      {
        'id': 42,
        'title': 'Yemekhane nasıl?',
        'type': 'SINGLE',
        'scope': 'GLOBAL',
        'status': 'OPEN',
        'closesAt': '2026-11-30T00:00:00Z',
        'resultsVisible': true,
        'totalVotes': 100,
        'myVote': {'optionIds': [1]},
        'options': [
          {'id': 1, 'text': 'İyi'},
          {'id': 2, 'text': 'Kötü'},
        ],
        'results': [
          {'optionId': 1, 'count': 60, 'percent': 60},
          {'optionId': 2, 'count': 40, 'percent': 40},
        ],
      },
      // Menu puanlamasi ve kulup anketi widget'a girmez.
      {'id': 43, 'title': 'Menü', 'type': 'RATING', 'scope': 'MENU', 'options': []},
    ],
  });
  // Kisi adi iceren bildirimler: yalniz adet okunur.
  b.on('/notifications*', {
    'items': [
      {'id': 1, 'type': 'POST_LIKE', 'title': 'Ayşe Yılmaz gönderini beğendi', 'body': 'Ayşe Yılmaz'},
      {'id': 2, 'type': 'USER_FOLLOW', 'title': 'Mehmet seni takip etti'},
    ],
  });
  return b;
}

void main() {
  late MemoryWidgetStore store;
  late FakeBackend b;
  late Session s;

  setUp(() {
    store = MemoryWidgetStore();
    b = backend();
    s = makeSession(b);
    s.api.lang = 'tr';
    s.badges.chat.value = 3;
    s.badges.notifications.value = 5;
    WidgetSyncService.instance
      ..detach()
      ..store = store
      ..clock = (() => kNow)
      ..attach(s);
  });
  tearDown(() => WidgetSyncService.instance.detach());

  Map<String, dynamic> read(String key) => jsonDecode(store.data[key]!) as Map<String, dynamic>;

  test('oturum acikken 7 snapshot + meta yazilir, widgetlar yenilenir', () async {
    await WidgetSyncService.instance.syncNow();
    for (final slug in WidgetSlug.values) {
      expect(store.data.containsKey('bu_widget_${slug.slug}'), isTrue, reason: slug.slug);
    }
    final meta = read('bu_widget_meta');
    expect(meta['signedIn'], true);
    expect(meta['lang'], 'tr');
    expect(meta['schema'], 1);
    expect(store.reloads, isNotEmpty);
    expect(store.reloads.last.length, 7);

    final menu = read('bu_widget_menu');
    expect(menu['state'], 'ok');
    expect(menu['totalLine'], 'Toplam 530 kcal');
    final tt = read('bu_widget_timetable');
    expect(tt['count'], 1);
    expect(tt['lessons'][0]['room'], 'B-204');
    final ev = read('bu_widget_events');
    expect(ev['count'], 1); // yalniz ACTIVE + kulupsuz olmayan
    expect(ev['events'][0]['venue'], 'Amfi 2');
    expect(read('bu_widget_announcements')['items'][0]['dateLabel'], '05 Kas');
    final poll = read('bu_widget_poll');
    expect(poll['pollId'], 42);
    expect(poll['options'][0]['percent'], 60);
    expect(read('bu_widget_quickaccess')['items'].length, 8);
  });

  test('sosyal: sayaclar rozetlerden, begeni adedi bildirimlerden; kisi adi snapshota GIRMEZ', () async {
    await WidgetSyncService.instance.syncNow(only: {WidgetSlug.social});
    final soc = read('bu_widget_social');
    expect(soc['unreadMessages'], 3);
    expect(soc['newNotifications'], 5);
    expect(soc['newLikesAndFollowers'], 2);
    final raw = store.data['bu_widget_social']!;
    expect(raw.contains('Ayşe'), isFalse);
    expect(raw.contains('Mehmet'), isFalse);
    expect(raw.contains('beğendi'), isFalse);
    // Yalniz istenen widget yazildi.
    expect(store.data.containsKey('bu_widget_menu'), isFalse);
  });

  test('kaynak sitelere istek yok: yalniz kendi API yollari', () async {
    await WidgetSyncService.instance.syncNow();
    for (final r in b.requests) {
      expect(r.startsWith('GET /'), isTrue);
      expect(r.contains('bingol.edu.tr'), isFalse);
    }
    // Ek agir istek yok: menu 1 ay, diger her widget en cok 1 istek.
    expect(b.count('/menu'), 1);
    expect(b.count('/events'), 1);
    expect(b.count('/polls'), 1);
    expect(b.count('/news'), 1);
  });

  test('tek uc hata verirse o widgetin onceki snapshotu kalir, digerleri yazilir', () async {
    store.data['bu_widget_events'] = '{"old":true}';
    b.fail('/events*');
    await WidgetSyncService.instance.syncNow();
    expect(store.data['bu_widget_events'], '{"old":true}');
    expect(read('bu_widget_menu')['state'], 'ok');
  });

  test('anket yok (bos liste): bos durum snapshotu yazilir', () async {
    b.on('/polls*', {'items': <Object>[]});
    await WidgetSyncService.instance.syncNow(only: {WidgetSlug.poll});
    expect(read('bu_widget_poll')['state'], 'empty');
  });

  test('oturum yoksa tum snapshotlar silinir, meta signedIn=false + Giris yap metni', () async {
    await WidgetSyncService.instance.syncNow();
    expect(store.data.keys.where((k) => k != 'bu_widget_meta').length, 7);
    s.state = SessionState.signedOut;
    await WidgetSyncService.instance.syncNow();
    expect(store.data.keys.toSet(), {'bu_widget_meta'});
    final meta = read('bu_widget_meta');
    expect(meta['signedIn'], false);
    expect(meta['strings']['signedOutTitle'], 'Giriş yap');
    expect(store.reloads.last.length, 7);
  });

  test('oturum henuz yukleniyorsa (loading) hicbir sey silinmez ya da yazilmaz', () async {
    store.data['bu_widget_menu'] = '{"keep":1}';
    s.state = SessionState.loading;
    await WidgetSyncService.instance.syncNow();
    expect(store.data['bu_widget_menu'], '{"keep":1}');
    expect(store.reloads, isEmpty);
  });

  test('clearUserData (hesap degisimi/cikis kancasi) her seyi siler, dil korunur', () async {
    await WidgetSyncService.instance.syncNow();
    s.api.lang = 'ar';
    await WidgetSyncService.clearUserData();
    expect(store.data.keys.toSet(), {'bu_widget_meta'});
    final meta = read('bu_widget_meta');
    expect(meta['signedIn'], false);
    expect(meta['lang'], 'ar');
    expect(meta['rtl'], true);
  });

  test('kullanici verisi temizleyicileri widget temizligini icerir', () {
    final api = ApiClient(client: b.client, retryDelay: Duration.zero);
    registerUserDataCleaners(api);
    expect(api.onUserDataCleared.contains(WidgetSyncService.clearUserData), isTrue);
  });

  test('Arapca dilde metinler Arapca yazilir', () async {
    s.api.lang = 'ar';
    await WidgetSyncService.instance.syncNow(only: {WidgetSlug.menu});
    final menu = read('bu_widget_menu');
    expect(menu['lang'], 'ar');
    expect(menu['rtl'], true);
    expect(menu['meals'][0]['label'], 'الغداء');
  });

  test('push yuku: sosyal her zaman, etkinlik/anket turune gore ek widget; baglanmamissa no-op', () async {
    WidgetSyncService.instance.onPush({'targetType': 'EVENT_REMINDER', 'targetId': '9'});
    await Future<void>.delayed(WidgetSyncService.debounceDelay + const Duration(milliseconds: 300));
    expect(store.data.containsKey('bu_widget_social'), isTrue);
    expect(store.data.containsKey('bu_widget_events'), isTrue);
    expect(store.data.containsKey('bu_widget_menu'), isFalse);

    WidgetSyncService.instance.detach();
    store.data.clear();
    WidgetSyncService.instance.onPush({'targetType': 'EVENT'});
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(store.data, isEmpty);
  });
}
