@Tags(['store-shots'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/home/home_tab.dart';
import 'package:bu_kampus/features/menu/menu_page.dart';
import 'package:bu_kampus/features/news/news_detail_page.dart';
import 'package:bu_kampus/features/news/news_list_page.dart';
import 'package:bu_kampus/features/profile/saved_news_page.dart';
import 'package:bu_kampus/features/notifications/notifications_page.dart';
import 'package:bu_kampus/features/search/search_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import '../support/store_shots_images.dart';

/// K3 (arama, ana sayfa/yemek/bildirim durumlari, haber detay varyantlari) referans karsilastirma goruntuleri.
///
/// Uretim (C:\bu_mobile, Git Bash):
///   STORE_SHOTS_OUT='C:/Users/.../redesign/k3/uygulama' flutter test test/redesign/k3_shots_test.dart
/// Istege bagli: `K3_LANG=tr|en|ar`, `K3_ONLY=y1,n2` (dosya adi oneki), `K3_MODES=light,dark,x13`.
const _dpr = 2.0;
const _w = 390.0;
const _h = 844.0;

String _lang = 'tr';

class _Shot {
  const _Shot(this.file, this.build, this.backend, {this.after, this.recent, this.slow = false, this.height = _h});
  final String file;
  final Widget Function(FakeBackend b) build;
  final FakeBackend Function() backend;
  final Future<void> Function(WidgetTester t, FakeBackend b)? after;
  final List<String>? recent;
  final bool slow;
  final double height;
}

String _today([int add = 0]) {
  final n = DateTime.now().add(Duration(days: add));
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

List<Map<String, dynamic>> _menuMonth(Map<String, dynamic> today) {
  final n = DateTime.now();
  final last = DateTime(n.year, n.month + 1, 0).day;
  return [
    for (var d = 1; d <= last; d++)
      if (d == n.day) {...today, 'date': _today()} else {'date': '${n.year}-${n.month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}', 'items': <String>[]},
  ];
}

Map<String, dynamic> _dish(String n, int? k) => {'name': n, 'kcal': k};

FakeBackend _menuBackend({required Map<String, dynamic> today, bool maintenance = false, bool rated = false, bool poll = true}) {
  final b = FakeBackend()
    ..on('/menu', _menuMonth(today))
    ..on('/status', {
      'NEWS': {'maintenance': false},
      'MENU': {'maintenance': maintenance},
    });
  if (poll) {
    b.on('/polls/menu/today', {
      'id': 9,
      'type': 'RATING',
      'scope': 'MENU',
      'title': 'Bugünün menüsü',
      'status': 'OPEN',
      'canVote': true,
      'voted': rated,
      if (rated) 'myRating': 4,
      if (rated) 'average': 4.2,
      'options': <Object>[],
      'menuItems': ['Kuru fasulye', 'Bulgur pilavı', 'Turşu'],
    });
  } else {
    b.on('/polls/menu/today', <String, dynamic>{}, status: 204);
  }
  return b;
}

final _fullMenu = <String, dynamic>{
  'items': ['MERCİMEK ÇORBASI', 'ETLİ NOHUT', 'PİRİNÇ PİLAVI', 'CACIK', 'MEYVE'],
  'imageUrl': 'https://img.invalid/menu.jpg',
  'dishes': [_dish('MERCİMEK ÇORBASI', 120), _dish('ETLİ NOHUT', 310), _dish('PİRİNÇ PİLAVI', 280), _dish('CACIK', 70), _dish('MEYVE', 60)],
  'totalKcal': 840,
  'kcalComplete': true,
};

final _partialMenu = <String, dynamic>{
  'items': ['Kuru fasulye', 'Bulgur pilavı', 'Turşu'],
  'dishes': [_dish('Kuru fasulye', 290), _dish('Bulgur pilavı', 260), _dish('Turşu', null)],
  'totalKcal': 550,
  'kcalComplete': false,
};

final _shots = <_Shot>[
  _Shot('y1_yemek_detay', (b) => MenuPage(session: makeSession(b)), () => _menuBackend(today: _fullMenu)),
  _Shot('y2_yemek_eksik_kalori', (b) => MenuPage(session: makeSession(b)), () => _menuBackend(today: _partialMenu, rated: true)),
  _Shot('y3_yemek_bos_bakim', (b) => MenuPage(session: makeSession(b)),
      () => _menuBackend(today: {'items': <String>[]}, maintenance: true, poll: false)),
  _Shot('y4_yemek_yukleniyor', (b) => MenuPage(session: makeSession(b)), () => _menuBackend(today: _fullMenu), slow: true),
  _Shot('y5_yemek_bos', (b) => MenuPage(session: makeSession(b)), () => _menuBackend(today: {'items': <String>[]}, poll: false)),
  _Shot('n1_bildirim_okunmamis_kaydir', (b) => NotificationsPage(session: makeSession(b)), () => _notifBackend(_notifItems), after: (t, b) async {
    await _tapText(t, lookupAppLocalizations(Locale(_lang)).bildirimFilterUnread);
    final g = await t.startGesture(t.getCenter(find.byKey(const ValueKey('notif-2'))));
    await g.moveBy(const Offset(-30, 0));
    await t.pump(const Duration(milliseconds: 100));
    await g.moveBy(const Offset(-130, 0));
    await t.pump(const Duration(milliseconds: 300));
  }),
  _Shot('n2_bildirim_bos', (b) => NotificationsPage(session: makeSession(b)), () => _notifBackend([])),
  _Shot('n3_bildirim_okunmamis_bos', (b) => NotificationsPage(session: makeSession(b)),
      () => _notifBackend([for (final n in _notifItems.take(3)) {...n, 'read': true}]), after: (t, b) async {
    await _tapText(t, lookupAppLocalizations(Locale(_lang)).bildirimFilterUnread);
  }),
  _Shot('n4_bildirim_hata', (b) => NotificationsPage(session: makeSession(b)), () => _notifBackend([])..fail('/notifications')),
  _Shot('n5_bildirim_liste_sonu', (b) => NotificationsPage(session: makeSession(b)), () => _notifBackend(_notifItems), after: (t, b) async {
    await t.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await t.pump(const Duration(milliseconds: 400));
  }),
  _Shot('n6_bildirim_daha_fazla', (b) => NotificationsPage(session: makeSession(b)), () => _notifBackend([..._notifItems, for (final n in _notifItems) {...n, 'id': 100 + (n['id'] as int)}], next: 20),
      after: (t, b) async {
    b.delay = const Duration(seconds: 4);
    await t.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await t.pump(const Duration(milliseconds: 400));
  }),
  _Shot('n7_bildirim_yukleniyor', (b) => NotificationsPage(session: makeSession(b)), () => _notifBackend(_notifItems), slow: true),
  _Shot('h1_ana_yukleniyor', (b) => Scaffold(body: HomeTab(session: makeSession(b), onOpenTab: (i, {newsType}) {})), () => FakeBackend(), slow: true),
  _Shot('h2_ana_bayat_bos', (b) => Scaffold(body: HomeTab(session: makeSession(b)..displayName = 'Elif', onOpenTab: (i, {newsType}) {})), () {
    final b = FakeBackend()
      ..on('/status', {
        'NEWS': {'maintenance': true},
        'MENU': {'maintenance': false},
      })
      ..on('/menu/today', <String, dynamic>{})
      ..fail('/news');
    return b;
  }, height: 1100),
  _Shot('d1_haber_etkinlik_kaydedildi', (b) => NewsDetailPage(session: makeSession(b), item: _newsItem(eventDate: '2026-11-14')), _detailBackend,
      after: (t, b) async {
    await t.tap(find.byKey(const ValueKey('news-share')));
    await t.pump(const Duration(milliseconds: 500));
  }),
  _Shot('d2_haber_duyuru_gorselsiz', (b) => NewsDetailPage(session: makeSession(b), item: _newsItem(type: 'DUYURU', img: false)),
      () => _detailBackend()..on('/bookmarks/news/ids', {'ids': <int>[]}), after: (t, b) async {
    await t.tap(find.byKey(const ValueKey('news-open-source')));
    await t.pump(const Duration(milliseconds: 500));
  }),
  _Shot('d3_haber_yukleniyor', (b) => NewsDetailPage(session: makeSession(b), item: _newsItem()), _detailBackend, slow: true),
  _Shot('d4_haber_hata', (b) => NewsDetailPage(session: makeSession(b), item: _newsItem(img: false)), () => _detailBackend()..fail('/news/1')),
  _Shot('s1_arama_bos', (b) => SearchPage(session: makeSession(b)), _searchBackend, recent: ['ders kayıt', 'robotik', 'yemek', 'Elif']),
  _Shot('s2_arama_tumu', (b) => SearchPage(session: makeSession(b)), () => _searchBackend(hits: _kulupHits, users: _people.take(1).toList()),
      height: 1500, after: (t, b) => _typeQ(t, 'kulüp')),
  _Shot('s3_arama_kulup', (b) => SearchPage(session: makeSession(b)), () => _searchBackend(hits: _clubTabHits), after: (t, b) async {
    await _typeQ(t, 'robot');
    await _pickTab(t, lookupAppLocalizations(Locale(_lang)).searchClub);
  }),
  _Shot('s4_arama_kisi', (b) => SearchPage(session: makeSession(b)), () => _searchBackend(users: _people), after: (t, b) async {
    await _typeQ(t, 'elif');
    await _pickTab(t, lookupAppLocalizations(Locale(_lang)).searchPerson);
  }),
  _Shot('s5_arama_gonderi', (b) => SearchPage(session: makeSession(b)), () => _searchBackend(hits: _postHits), height: 1200, after: (t, b) async {
    await _typeQ(t, 'kampüs');
    await _pickTab(t, lookupAppLocalizations(Locale(_lang)).searchPost);
  }),
  _Shot('s6a_arama_yukleniyor', (b) => SearchPage(session: makeSession(b)), () => _searchBackend(hits: _kulupHits), slow: true, after: (t, b) => _typeQ(t, 'xyz123')),
  _Shot('s6b_arama_sonuc_yok', (b) => SearchPage(session: makeSession(b)), _searchBackend, after: (t, b) => _typeQ(t, 'xyz123')),
  _Shot('s6c_arama_hata', (b) => SearchPage(session: makeSession(b)), () => _searchBackend(failStatus: 500), after: (t, b) => _typeQ(t, 'xyz123')),
  _Shot('s6d_arama_hiz_siniri', (b) => SearchPage(session: makeSession(b)), () => _searchBackend(failStatus: 429), after: (t, b) => _typeQ(t, 'xyz123')),
  _Shot('hb1_haber_liste', (b) => NewsListPage(session: makeSession(b)), () => _hbBackend('HABER', noImg: {1, 3})),
  _Shot('hb2_duyuru_liste', (b) => NewsListPage(session: makeSession(b), initialType: 'DUYURU'), () => _hbBackend('DUYURU', noImg: {0, 1, 3, 4})),
  _Shot('hb3_etkinlik_liste', (b) => NewsListPage(session: makeSession(b), initialType: 'ETKINLIK'), () => _hbBackend('ETKINLIK', noImg: {1, 3, 4})),
  _Shot('hb4_bakim_sayfalama', (b) => NewsListPage(session: makeSession(b)), () => _hbBackend('HABER', count: 5, maintenance: true, totalPages: 3),
      after: (t, b) async {
    b.delay = const Duration(seconds: 4);
    await t.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await t.pump(const Duration(milliseconds: 400));
  }),
  _Shot('hb5_favoriler', (b) => SavedNewsPage(session: makeSession(b)), _savedBackend),
  _Shot('hb6a_favori_bos', (b) => SavedNewsPage(session: makeSession(b)), () => _savedBackend(empty: true)),
  _Shot('hb6b_kategori_bos', (b) => NewsListPage(session: makeSession(b)), () => _hbBackend('HABER', empty: true)),
  _Shot('hb6c_liste_hata', (b) => NewsListPage(session: makeSession(b)), () => _hbBackend('HABER', fail: true)),
  _Shot('hb7_haber_yukleniyor', (b) => NewsListPage(session: makeSession(b)), () => _hbBackend('HABER'), slow: true),
];

String _ago(Duration d) => DateTime.now().subtract(d).toIso8601String();

Map<String, dynamic> _notif(int id, String type, String title, String body, Duration ago, {bool read = false}) =>
    {'id': id, 'type': type, 'title': title, 'body': body, 'read': read, 'createdAt': _ago(ago)};

FakeBackend _notifBackend(List<Map<String, dynamic>> items, {int? unread, int? next}) => FakeBackend()
  ..on('/notifications', {
    'items': items,
    'unreadCount': unread ?? items.where((e) => e['read'] != true).length,
    'nextCursor': next,
  });

List<Map<String, dynamic>> get _notifItems => [
      _notif(1, 'EVENT', 'Robotik Kulübü Yapay Zeka Çalıştayı', 'Yarın saat 14:00\'te Mühendislik Fakültesi B-102 amfisinde.', const Duration(minutes: 5)),
      _notif(2, 'MESSAGE', 'Ahmet Yılmaz', 'Yarınki ders notlarını paylaşabilir misin?', const Duration(minutes: 25)),
      _notif(3, 'COMMUNITY', 'Tiyatro Kulübü Prova Saati', 'Yeni dönem oyun seçmeleri için takvim güncellendi.', const Duration(hours: 2)),
      _notif(4, 'POLL', 'Yemekhane Memnuniyet Anketi', 'Ekim ayı menülerini değerlendirmek için 3 soruluk anketi doldurun.', const Duration(days: 1)),
      _notif(5, 'ANNOUNCEMENT', 'Güz Dönemi Ders Kayıtları', 'Danışman onayları için son gün 3 Kasım olarak belirlenmiştir.', const Duration(days: 3)),
    ];

Future<void> _tapText(WidgetTester t, String text) async {
  await t.tap(find.text(text).first);
  await t.pump(const Duration(milliseconds: 400));
}

Map<String, dynamic> _newsItem({String type = 'ETKINLIK', bool img = true, String? eventDate}) => {
      'id': 1,
      'title': type == 'ETKINLIK' ? 'Üniversitemizde Kariyer Günleri Düzenleniyor' : 'Güz Dönemi Çift Anadal ve Yandal Başvuru Sonuçları Açıklandı',
      'type': type,
      'imageUrl': img ? 'https://img.invalid/n1.jpg' : null,
      'publishedDate': '2026-10-26',
      'eventDate': eventDate,
    };

FakeBackend _detailBackend() => FakeBackend()
  ..on('/news/1', {
    'id': 1,
    'content': 'Bu yıl on sekizinci kez düzenlenecek olan geleneksel BU Kampüs Kariyer Fuarı, savunma sanayii, yazılım, otomotiv ve finans sektörlerinin öncü teknoloji devlerini öğrencilerimizle ve yeni mezunlarımızla bir araya getiriyor.\n'
        'Ana Kongre ve Sergi Sarayında tam gün sürecek etkinlik boyunca katılımcılar; insan kaynakları yöneticileriyle bire bir görüşme fırsatı bulacak ve vizyoner sunumları dinleyebilecektir.\n'
        'Katılım sertifikası almak ve ön mülakat randevusu oluşturmak isteyen tüm lisans ve lisansüstü öğrencilerimizin dijital öğrenci kartlarını yanlarında bulundurmaları önemle rica olunur.',
    'url': 'https://www.bingol.edu.tr/haber/1',
    'eventDate': null,
  })
  ..on('/bookmarks/news/ids', {'ids': <int>[1]});

Map<String, dynamic> _hit(String type, int id, String title, {String? snippet, String? date, String? img, Map<String, dynamic> extra = const {}}) =>
    {'type': type, 'targetId': id, 'title': title, 'snippet': snippet, 'date': date, 'imageUrl': img, ...extra};

FakeBackend _searchBackend({List<Map<String, dynamic>> hits = const [], List<Map<String, dynamic>> users = const [], int? failStatus}) {
  final b = FakeBackend();
  b.handlers.add((req, path) {
    if (failStatus != null && (path == '/search' || path == '/users/search')) {
      return FakeResult.json({'code': 'RATE_LIMITED', 'message': ''}, status: failStatus);
    }
    if (path == '/search') {
      final type = req.url.queryParameters['type'];
      final byType = <String, List<Map<String, dynamic>>>{};
      for (final h in hits) {
        if (type == null || type == h['type']) byType.putIfAbsent(h['type'] as String, () => []).add(h);
      }
      return FakeResult.json({
        'groups': [for (final e in byType.entries) {'type': e.key, 'items': e.value}],
        'nextCursor': null,
      });
    }
    if (path == '/users/search') return FakeResult.json({'items': users, 'nextCursor': null});
    return null;
  });
  return b;
}

Map<String, dynamic> _user(int id, String name, String dept, {int? year}) =>
    {'id': id, 'displayName': name, 'department': dept, if (year != null) 'classYear': year};

final _kulupHits = <Map<String, dynamic>>[
  _hit('NEWS', 1, 'Öğrenci Kulüpleri Tanıtım Günleri Başlıyor', date: '2026-10-24', img: 'https://img.invalid/n1.jpg'),
  _hit('NEWS', 2, 'Kulüp Etkinlik Başvuruları İçin Son Gün', date: '2026-10-20', img: 'https://img.invalid/n2.jpg'),
  _hit('ANNOUNCEMENT', 3, '2024-2025 Kulüp Tüzük Güncellemeleri Hakkında', date: '2026-10-18', snippet: 'Tüm aktif öğrenci topluluklarının yönergeleri...'),
  _hit('EVENT', 4, 'Robotik ve Yapay Zekâ Tanışma Günü', date: '2026-10-28T17:30:00', snippet: 'Robotik Kulübü · Mühendislik Fakültesi', extra: {'endsAt': '2026-10-28T19:00:00'}),
  _hit('COMMUNITY', 5, 'Robotik Kulübü', snippet: 'Otonom araçlar ve robot yarışmaları.', extra: {'memberCount': 128, 'category': 'Teknoloji'}),
  _hit('COMMUNITY', 6, 'Tiyatro ve Sahne Sanatları', snippet: 'Oyun atölyeleri.', extra: {'memberCount': 94, 'category': 'Kültür'}),
  _hit('POSTS', 7, 'Elif Yıldız', snippet: 'Kulüp standımızda yeni dönem kayıtları devam ediyor!', img: 'https://img.invalid/p7.jpg', extra: {'likeCount': 42}),
];

final _clubTabHits = <Map<String, dynamic>>[
  _hit('COMMUNITY', 5, 'Robotik Kulübü', snippet: 'Otonom araçlar, İHA ve robot yarışmaları üzerine projeler geliştiriyoruz.',
      extra: {'memberCount': 86, 'category': 'Mühendislik ve Teknoloji', 'myStatus': 'ACTIVE'}),
  _hit('COMMUNITY', 6, 'Robotik Kodlama ve Yapay Zekâ', snippet: 'Yapay zekâ ve gömülü sistemler atölyeleri.',
      extra: {'memberCount': 64, 'category': 'Yazılım ve Bilişim', 'myStatus': 'NONE'}),
  _hit('COMMUNITY', 8, 'Endüstriyel Otomasyon ve Robotik', snippet: 'Fabrika otomasyonu ve PLC yazılım projeleri.',
      extra: {'memberCount': 39, 'category': 'Mesleki Gelişim', 'myStatus': 'NONE'}),
];

final _people = <Map<String, dynamic>>[
  _user(1, 'Elif Yıldız', 'Bilgisayar Mühendisliği', year: 2),
  _user(2, 'Elif Kaya', 'Hemşirelik Bölümü', year: 3),
  _user(3, 'Elif Demir', 'İşletme', year: 4),
  _user(4, 'Elif Su Aksoy', 'İlahiyat Fakültesi', year: 1),
];

final _postHits = <Map<String, dynamic>>[
  for (var i = 0; i < 6; i++)
    _hit('POSTS', 10 + i, ['Selin', 'Mert', 'Burak', 'Can', 'Emre', 'Zeynep'][i],
        snippet: ['Sonbaharda merkez kütüphane önü harika.', 'Robotik kulübü atölyesinde yeni prototip.', 'Öğle arasında arkadaşlarla çay.', 'Fakülteler arası voleybol turnuvası.', 'Dağ manzarasına karşı sabah dersi.', 'Yeni dönem kulüp kayıt standı.'][i],
        img: 'https://img.invalid/p$i.jpg', extra: {'likeCount': 84 + i * 7}),
];

Future<void> _typeQ(WidgetTester t, String q) async {
  await t.enterText(find.byType(TextField).first, q);
  await t.pump(const Duration(milliseconds: 500));
}

Future<void> _pickTab(WidgetTester t, String label) async {
  await t.ensureVisible(find.text(label).first);
  await t.pump(const Duration(milliseconds: 300));
  await t.tap(find.text(label).first);
  await t.pump(const Duration(milliseconds: 600));
}

const _hbTitles = {
  'HABER': [
    'Mühendislik Fakültesi Yapay Zekâ ve İnovasyon Laboratuvarı Açıldı',
    'Merkez Kütüphane 7/24 Çalışma Düzenine Geçti',
    'TÜBİTAK 2209 Üniversite Öğrencileri Araştırma Projeleri Destek Programı',
    'Ziraat Fakültesi Arıcılık ve Bal Üretimi Semineri Tamamlandı',
    'Kariyer Geliştirme ve Mezunlarla İletişim Zirvesi Başlıyor',
  ],
  'DUYURU': [
    '2026-2027 Güz Dönemi Ders Kayıt Duyurusu ve Danışman Onayları',
    'Öğrenci İşleri Daire Başkanlığı Muafiyet Sınavı Takvimi',
    'Erasmus+ Öğrenci Öğrenim ve Staj Hareketliliği Başvuruları',
    'Yabancı Diller Yüksekokulu Muafiyet Sınav Yerleri Açıklandı',
    'Sağlık Kültür ve Spor Daire Başkanlığı Burs ve Yemek Başvuruları',
  ],
  'ETKINLIK': [
    'Yazılım Kulübü: Üniversite İçi Hackathon 2026',
    'Münazara Kulübü Güz Dönemi Açılış Turnuvası ve Tanışma Etkinliği',
    'Doğa Sporları ve Dağcılık: Çır Şelalesi Sonbahar Doğa Yürüyüşü',
    'Müzik Kulübü: Kampüs Akustik Konseri ve Enstrüman Dinletisi',
    'Tiyatro Kulübü Oyuncu Seçmeleri ve Doğaçlama Atölyesi',
  ],
};

List<Map<String, dynamic>> _hbItems(String type, {int count = 5, Set<int> noImg = const {}}) => [
      for (var i = 0; i < count; i++)
        newsItem(i + 1,
            type: type,
            title: _hbTitles[type]![i % 5],
            imageUrl: noImg.contains(i) ? null : 'https://img.invalid/n${i + 1}.jpg',
            eventDate: type == 'ETKINLIK' ? '2026-11-${14 + i * 4}' : null),
    ];

FakeBackend _hbBackend(String type,
        {int count = 5, Set<int> noImg = const {}, bool maintenance = false, int totalPages = 1, bool empty = false, bool fail = false}) {
  final b = FakeBackend()
    ..on('/news', {...newsPage(empty ? [] : _hbItems(type, count: count, noImg: noImg)), 'totalPages': totalPages})
    ..on('/status', {
      'NEWS': {'maintenance': maintenance},
      'MENU': {'maintenance': false},
    })
    ..on('/bookmarks/news/ids', {'ids': [2]});
  if (fail) b.fail('/news');
  return b;
}

FakeBackend _savedBackend({bool empty = false, bool fail = false}) {
  final b = FakeBackend()
    ..on('/bookmarks', {
      'items': empty
          ? <Object>[]
          : [
              {'news': newsItem(1, type: 'HABER', title: _hbTitles['HABER']![0], imageUrl: 'https://img.invalid/n1.jpg')},
              {'news': newsItem(2, type: 'DUYURU', title: _hbTitles['DUYURU']![2], imageUrl: null)},
              {'news': newsItem(3, type: 'ETKINLIK', title: _hbTitles['ETKINLIK']![1], imageUrl: null, eventDate: '2026-11-18')},
            ],
      'nextCursor': null,
    });
  if (fail) b.fail('/bookmarks');
  return b;
}

class _Variant {
  const _Variant(this.suffix, this.dark, this.scale);
  final String suffix;
  final bool dark;
  final double scale;
}

Widget _app(Widget home, bool dark, GlobalKey key, double scale) {
  final lang = _lang;
  return RepaintBoundary(
    key: key,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: BuTheme.forLocale(Brightness.light, lang),
      darkTheme: BuTheme.forLocale(Brightness.dark, lang),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(lang),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: home,
    ),
  );
}

Future<void> _loadFonts(bool arabic) async {
  await loadTestFonts();
  if (!arabic) return;
  final f = FontLoader('Inter');
  for (final n in ['arial.ttf', 'arialbd.ttf']) {
    final file = File('C:/Windows/Fonts/$n');
    if (file.existsSync()) f.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await f.load();
}

Future<void> _pumpImages(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  final out = Platform.environment['STORE_SHOTS_OUT'];
  final skip = out == null ? 'STORE_SHOTS_OUT tanimli degil (yalniz ekran goruntusu uretimi icin)' : null;
  _lang = Platform.environment['K3_LANG'] ?? 'tr';
  final only = (Platform.environment['K3_ONLY'] ?? '').split(',').where((e) => e.isNotEmpty).toList();
  final modes = (Platform.environment['K3_MODES'] ?? 'light').split(',');
  final variants = <_Variant>[
    if (modes.contains('light')) const _Variant('', false, 1),
    if (modes.contains('dark')) const _Variant('_koyu', true, 1),
    if (modes.contains('x13')) const _Variant('_x1.3', false, 1.3),
  ];

  setUpAll(() => _loadFonts(_lang == 'ar'));

  for (final v in variants) {
    for (final s in _shots) {
      if (only.isNotEmpty && !only.any((o) => s.file.startsWith(o))) continue;
      final name = '${s.file}${v.suffix}_$_lang';
      testWidgets('k3 $name', skip: skip != null, (tester) async {
        debugNetworkImageHttpClientProvider = () => StoreImageHttpClient();
        addTearDown(() => debugNetworkImageHttpClientProvider = null);
        tester.view.devicePixelRatio = _dpr;
        tester.view.physicalSize = Size(_w * _dpr, s.height * _dpr);
        tester.view.padding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        tester.view.viewPadding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        addTearDown(tester.view.reset);
        LocaleController.current = LocaleController(deviceLocales: () => [Locale(_lang)])..pref = _lang;
        addTearDown(() => LocaleController.current = null);

        final b = s.backend();
        if (s.slow) b.delay = const Duration(seconds: 3);
        final key = GlobalKey();
        final home = s.build(b);
        if (s.recent != null) {
          await const FlutterSecureStorage().write(key: 'recent_searches', value: jsonEncode(s.recent));
        } else {
          await const FlutterSecureStorage().delete(key: 'recent_searches');
        }
        await tester.pumpWidget(_app(home, v.dark, key, v.scale));
        await tester.pump(const Duration(milliseconds: 100));
        if (!s.slow) {
          await settle(tester, const Duration(milliseconds: 900));
          await _pumpImages(tester);
        }
        if (s.after != null) {
          await s.after!(tester, b);
          if (!s.slow) {
            await settle(tester, const Duration(milliseconds: 700));
            await _pumpImages(tester);
          } else {
            await tester.pump(const Duration(milliseconds: 600));
          }
        } else if (s.slow) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        final err = tester.takeException();
        if (err != null) fail('Istisna: $err');
        await tester.runAsync(() async {
          final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await ro.toImage(pixelRatio: _dpr);
          final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
          final dir = Directory(out!)..createSync(recursive: true);
          final f = File('${dir.path}/$name.png')..writeAsBytesSync(data.buffer.asUint8List());
          // ignore: avoid_print
          print('YAZILDI ${f.path} ${image.width}x${image.height}');
        });
        if (s.slow || (s.file.startsWith('n6') || s.file.startsWith('hb4'))) {
          for (var i = 0; i < 8; i++) {
            await tester.pump(const Duration(seconds: 2));
          }
        }
        await unmount(tester);
        await const FlutterSecureStorage().delete(key: 'recent_searches');
        debugNetworkImageHttpClientProvider = null;
      });
    }
  }
}
