@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/nav.dart';
import 'package:bu_kampus/core/permissions/permission_service.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/academic/academic_hub_page.dart';
import 'package:bu_kampus/features/academic/academic_models.dart';
import 'package:bu_kampus/features/academic/reminders.dart';
import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:bu_kampus/features/events/etkinlik2_qr_page.dart';
import 'package:bu_kampus/features/events/events_page.dart';
import 'package:bu_kampus/features/home/home_layout.dart';
import 'package:bu_kampus/features/menu/menu_page.dart';
import 'package:bu_kampus/features/polls/poll_detail_page.dart';
import 'package:bu_kampus/features/profile/profil2_delete_account_page.dart';
import 'package:bu_kampus/features/shell/app_shell.dart';
import 'package:bu_kampus/features/support/support_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_academic.dart';
import '../support/fake_app.dart';
import '../support/fake_media.dart';
import '../support/store_shots_images.dart';
import 'p00_support.dart';

/// Tanıtım sitesi (web/) telefon görselleri: GÜNCEL uygulama ekranları (gerçek widget'lar + uydurma veri), Türkçe, açık tema,
/// 390x844 mantıksal (iPhone 14 oranı, üst 47 / alt 34 dp güvenli alan) x devicePixelRatio 3 = 1170x2532 PNG.
/// Test ortamı sistem durum çubuğunu çizmez: 9:41 durum çubuğu ve ana ekran çubuğu elle yerleştirilir (kimlik/numara yok).
///
/// Varsayılan `flutter test` ile ÇALIŞMAZ (ortam değişkeni yoksa atlanır). Üretim (PowerShell, C:\bu_mobile içinde):
///   $env:SITE_SHOTS_OUT='C:\bu_qa\shots\site2'; flutter test test/redesign/site_shots_test.dart --tags store-shots
/// İsteğe bağlı: `SITE_SHOTS_ONLY=home,menu` (dosya adı öneki, virgüllü). Çıktı adları web/src/assets/site/app-<ad>.webp ile aynıdır.
/// Kişi adları uydurmadır ("Elif K." gibi); gerçek kişi/e-posta/telefon yoktur.
const _dpr = 3.0;
const _w = 390.0;
const _h = 844.0;
const _topInset = 47.0;
const _bottomInset = 34.0;

String _iso(DateTime d) => d.toUtc().toIso8601String();
String _day(int offset) {
  final n = DateTime.now().add(Duration(days: offset));
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

class _Scene {
  const _Scene(this.file, this.build, {this.setup, this.tab, this.after, this.now, this.height = _h});
  final String file; // web/src/assets/site/app-<file>.webp
  final Widget Function(FakeBackend b, Session s) build;
  final void Function(FakeBackend b)? setup;
  final int? tab;
  final Future<void> Function(WidgetTester t)? after;
  final DateTime? now; // akademik saat (UTC)
  final double height;
}

// ---------------------------------------------------------------------------------------------------------------
// Ortak çekirdek veri (AppShell'in her sekmesi için)

void _core(FakeBackend b) {
  final now = DateTime.now();
  b
    ..on('/me/summary', {'unreadNotifications': 3, 'unreadMessages': 2, 'communities': 3, 'events': 4, 'bookmarks': 6, 'upcomingEvents': 2})
    ..on('/users/me', {
      'id': 1,
      'displayName': 'Ayşe K.',
      'email': 'ayse@bingol.edu.tr',
      'faculty': 'Mühendislik Fakültesi',
      'department': 'Bilgisayar Mühendisliği',
      'grade': '3',
      'bio': 'Yazılım, satranç ve kampüs etkinlikleri.',
      'showEmail': false,
      'language': 'tr',
    })
    ..on('/users/1', {'id': 1, 'followerCount': 128, 'followingCount': 94, 'followedByMe': false})
    ..on('/auth/me', {'id': 1, 'email': 'ayse@bingol.edu.tr', 'displayName': 'Ayşe K.', 'role': 'USER'})
    ..on('/status', {'NEWS': {'maintenance': false}, 'MENU': {'maintenance': false}})
    ..on('/conversations/unread-count', {'total': 2})
    ..on('/menu/today', {
      'date': _day(0),
      'items': ['Süzme mercimek çorbası', 'Orman kebabı', 'Pirinç pilavı', 'Mevsim salata'],
      'dishes': [
        {'name': 'Süzme mercimek çorbası', 'kcal': 160},
        {'name': 'Orman kebabı', 'kcal': 380},
        {'name': 'Pirinç pilavı', 'kcal': 220},
        {'name': 'Mevsim salata', 'kcal': 100},
      ],
      'totalKcal': 860,
      'kcalComplete': true,
    })
    ..on('/events/featured', {
      'id': 12,
      'source': 'USER',
      'title': 'Yapay Zeka ve Kariyer Sohbeti',
      'startsAt': _iso(now.add(const Duration(days: 2, hours: 3))),
      'location': 'Merkez Kütüphane Önü',
      'communityName': 'Bilgisayar Topluluğu',
      'goingCount': 46,
      'attendeesPreview': [
        for (final n in ['Mehmet A.', 'Zeynep Ç.', 'Emre Y.', 'Elif K.']) {'userId': 2, 'displayName': n, 'avatarUrl': null},
      ],
    });
}

// ---------------------------------------------------------------------------------------------------------------
// 1) Ana Sayfa

void _homeData(FakeBackend b) {
  final wall = istanbulWall(academicClock());
  b
    ..on('/timetable', {
      'semester': null,
      'courses': [
        {
          'id': 1,
          'name': 'Veri Yapıları',
          'instructor': 'Prof. Dr. M. Kaya',
          'sessions': [
            {'dayOfWeek': wall.weekday, 'start': '10:00', 'end': '11:30', 'room': 'B-204'}
          ],
        },
        {
          'id': 2,
          'name': 'Veritabanı Sistemleri',
          'instructor': 'Doç. Dr. S. Demir',
          'sessions': [
            {'dayOfWeek': wall.weekday, 'start': '13:30', 'end': '15:00', 'room': 'Lab 3'}
          ],
        },
      ],
    })
    ..on('/timetable/exams/upcoming*', {
      'items': [
        {'id': 5, 'title': 'Vize', 'courseName': 'Algoritmalar', 'startsAt': _iso(DateTime.now().add(const Duration(days: 3)))},
      ]
    })
    ..on('/news?type=HABER*', {
      'items': [
        {'id': 1, 'type': 'HABER', 'title': 'Kütüphane vize dönemi çalışma saatleri güncellendi', 'publishedDate': _day(-3), 'imageUrl': null},
        {'id': 2, 'type': 'HABER', 'title': 'Güz dönemi festivali duyuruldu', 'publishedDate': _day(-5), 'imageUrl': null},
      ],
    })
    ..on('/news?type=DUYURU*', {
      'items': [
        {'id': 3, 'type': 'DUYURU', 'title': 'Erasmus+ bahar dönemi öğrenci hareketliliği başvuru sonuçları ilan edildi.', 'publishedDate': _day(-6)},
        {'id': 4, 'type': 'DUYURU', 'title': 'Merkezi yemekhanede tek kullanımlık plastik bardak uygulaması kaldırılmıştır.', 'publishedDate': _day(-8)},
        {'id': 5, 'type': 'DUYURU', 'title': 'Öğrenci kimlik kartı yenileme talepleri için son gün 15 Kasım.', 'publishedDate': _day(-11)},
      ],
    });
}

// ---------------------------------------------------------------------------------------------------------------
// 2) Keşfet

const _posts = [
  (1, 'Selin A.', 'Peyzaj Mimarlığı', 2, 284, true, (1080, 1440), 'Bahar geldi kampüse', 0),
  (2, 'Zeynep Ç.', 'Hemşirelik', 3, 142, false, (1080, 1080), 'Sessiz bir çalışma köşesi', 4),
  (3, 'Mert A.', 'İşletme', 4, 198, true, (1080, 1620), 'Yeni kütüphane binası', 1),
  (4, 'Elif K.', 'Hemşirelik', 5, 175, false, (1080, 1350), 'Sonbahar bisikleti', 2),
  (5, 'Can Ö.', 'İşletme', 26, 312, true, (1080, 1080), 'Ders çıkışı göl kenarında yürüyüş', 3),
  (6, 'Burak Ç.', 'Mimarlık', 30, 96, false, (1080, 1620), 'Kampüsün tembel sakini', 5),
  (7, 'Derya P.', 'Matematik', 31, 58, false, (1080, 1350), 'Satranç kulübü turnuvası', 6),
  (8, 'Emre T.', 'İktisat', 33, 77, false, (1080, 1350), 'Akşam konseri', 7),
];

Map<String, dynamic> _post(int i) {
  final r = _posts[i % _posts.length];
  final p = samplePost(
    id: 500 - i,
    media: [samplePostMedia(id: r.$9, width: r.$7.$1, height: r.$7.$2)],
    text: r.$8,
    likeCount: r.$5,
    liked: r.$6,
    authorId: 20 + i,
    authorName: r.$2,
    createdAt: _iso(DateTime.now().subtract(Duration(hours: r.$4))),
  );
  (p['author'] as Map)['department'] = r.$3;
  return p;
}

void _discoverData(FakeBackend b) {
  b
    ..on('/feed*', {'items': [for (var i = 0; i < 8; i++) _post(i)], 'nextCursor': null, 'hint': null})
    ..on('/users/me/follow-suggestions*', {'items': <Object>[]});
}

// ---------------------------------------------------------------------------------------------------------------
// 3) Sohbet konuşması

Map<String, dynamic> _m(int id, int sender, String text, int minAgo,
        {List<Map<String, dynamic>>? attachments, List<Map<String, dynamic>>? reactions, String? status}) =>
    {
      'id': id,
      'conversationId': 1,
      'senderId': sender,
      'text': text,
      'createdAt': _iso(DateTime.now().subtract(Duration(minutes: minAgo))),
      'attachments': attachments ?? const [],
      'reactions': reactions ?? const [],
      if (status != null) 'status': status,
    };

void _chatData(FakeBackend b) {
  b
    ..on('/conversations/1/messages*', {
      'items': [
        _m(10, 1, 'Süper, o zaman 14.00\'te kütüphanede görüşürüz.', 3, status: 'READ'),
        _m(9, 11, 'Ben de çıkmış sorularını yazıcıdan alırım.', 5),
        _m(8, 1, 'Harika, çok teşekkürler!', 7, status: 'READ'),
        _m(7, 11, 'Hemen gönderiyorum, tahtadan çektim.', 9, attachments: [
          {'id': 21, 'kind': 'IMAGE', 'url': '/a3', 'thumbUrl': '/a3', 'width': 800, 'height': 600},
        ]),
        _m(6, 1, 'Yarınki Veri Yapıları notlarını atar mısın?', 12, status: 'READ'),
        _m(5, 11, 'Akşam kütüphanede buluşup birlikte çalışalım mı?', 16, reactions: [
          {'emoji': '+', 'count': 1}
        ]),
        _m(4, 1, 'Süper, saat kaçta?', 18, status: 'READ'),
        _m(3, 11, 'Selam! Vize öncesi tekrar için grup kuruyoruz.', 40),
      ],
      'nextCursor': null,
    })
    ..on('/conversations/1', {
      'conversation': {'id': 1},
      'members': [
        {'userId': 1, 'displayName': 'Ayşe K.'},
        {'userId': 11, 'displayName': 'Mehmet A.'},
      ],
    })
    ..on('/users/11/presence', {'online': true})
    ..on('/messages/reactions', {'emojis': <String>[]});
}

// ---------------------------------------------------------------------------------------------------------------
// 4) Kulüpler

Map<String, dynamic> _club(int id, String name, String cat, String desc, int n, {String st = 'NONE', String? role, String policy = 'OPEN'}) => {
      'id': id,
      'name': name,
      'category': cat,
      'description': desc,
      'shortDescription': desc,
      'memberCount': n,
      'myStatus': st,
      'myRole': role,
      'joinPolicy': policy,
      'visibility': 'PUBLIC',
      'logoUrl': null,
    };

void _clubsData(FakeBackend b) {
  final discover = [
    _club(1, 'Fotoğraf Kulübü', 'Sanat', 'Foto gezileri, atölyeler ve dönem sonu sergisi', 128),
    _club(2, 'Müzik Kulübü', 'Müzik', 'Konserler ve açık sahne geceleri', 210, st: 'ACTIVE', role: 'MEMBER'),
    _club(3, 'Bilgisayar Topluluğu', 'Teknoloji', 'Yarışmalar, atölyeler, hackathon', 345),
    _club(4, 'Satranç Kulübü', 'Bilim', 'Haftalık turnuvalar ve eğitimler', 64, st: 'PENDING', policy: 'APPROVAL'),
    _club(5, 'Doğa Sporları Kulübü', 'Spor', 'Kamp, trekking ve doğa yürüyüşleri', 182),
    _club(6, 'Tiyatro Topluluğu', 'Sanat', 'Oyun provaları ve gösteriler', 73),
    _club(7, 'Girişimcilik Kulübü', 'Teknoloji', 'Fikirden ürüne söyleşiler ve mentorluk', 97),
  ];
  b
    ..on('/communities/categories', [
      {'category': 'Sanat', 'count': 2},
      {'category': 'Spor', 'count': 1},
      {'category': 'Bilim', 'count': 1},
      {'category': 'Müzik', 'count': 1},
      {'category': 'Teknoloji', 'count': 2},
    ])
    ..on('/me/communities*', {'items': discover.where((c) => c['myStatus'] != 'NONE').toList(), 'nextCursor': null})
    ..on('/communities*', {'items': discover, 'nextCursor': null});
}

// ---------------------------------------------------------------------------------------------------------------
// 5) Etkinlikler (liste) ve 6) QR yoklama

Map<String, dynamic> _ev(int id, String title, String club, int dayOff, int h, int dur, String place, {String? rsvp, int going = 64, int? cap}) {
  final n = DateTime.now();
  final s = DateTime(n.year, n.month, n.day + dayOff, h);
  return {
    'id': id,
    'source': 'USER',
    'title': title,
    'description': 'Bilgisayar Topluluğu olarak düzenlediğimiz buluşmada sektörden konuklarla bir araya geliyoruz.',
    'startsAt': _iso(s),
    'endsAt': _iso(s.add(Duration(hours: dur))),
    'location': place,
    'communityId': 7,
    'communityName': club,
    'goingCount': going,
    if (cap != null) 'capacity': cap,
    'myRsvp': rsvp,
    'status': 'ACTIVE',
    'joinPolicy': 'OPEN',
    'canManage': false,
    'createdBy': 2,
  };
}

void _eventsData(FakeBackend b) {
  b
    ..on('/me/events*', {'items': <Object>[], 'nextCursor': null})
    ..on('/me/communities*', {'items': <Object>[], 'nextCursor': null})
    ..on(
        '/events/calendar*',
        [
          _ev(1, 'Yapay Zeka ve Veri Bilimi Kariyer Günleri', 'Bilgisayar Topluluğu', 0, 15, 2, 'Konferans Salonu', going: 86),
          _ev(2, 'Sonbahar Kampüs Çekimi', 'Fotoğraf Kulübü', 1, 13, 3, 'Rektörlük Bahçesi', rsvp: 'GOING', going: 24),
          _ev(3, 'Akustik Dinleti ve Tanışma', 'Müzik Kulübü', 2, 18, 2, 'Amfi Tiyatro', going: 112),
          _ev(4, 'Satranç Turnuvası: Güz Kupası', 'Satranç Kulübü', 3, 14, 4, 'Öğrenci Merkezi', going: 38, cap: 48),
          _ev(5, 'Doğa Yürüyüşü: Göl Çevresi', 'Doğa Sporları Kulübü', 5, 9, 3, 'Kampüs Ana Kapı', going: 29),
          _ev(6, 'Girişimcilik Söyleşisi', 'Girişimcilik Kulübü', 6, 16, 2, 'Konferans Salonu', going: 51),
        ],
        headers: {'x-truncated': 'false'});
}

Map<String, dynamic> get _qrEvent => {
      'id': 5,
      'title': 'Yapay Zeka ve Veri Bilimi Kariyer Günleri',
      'communityName': 'Bilgisayar Topluluğu',
      'goingCount': 31,
      'capacity': 40,
      'createdBy': 2,
      'startsAt': _iso(DateTime.now().add(const Duration(hours: 1))),
      'location': 'Konferans Salonu',
    };

void _qrData(FakeBackend b) {
  final now = DateTime.now();
  b
    ..on('/events/5/checkin-code', {
      'code': '482913',
      'qrPayload': 'bingol-checkin:5.1.abc7q2xm',
      'validForSeconds': 30,
      'expiresAt': _iso(now.add(const Duration(seconds: 30))),
    })
    ..on('/events/5/attendance', [
      for (var i = 0; i < 31; i++)
        {'userId': 100 + i, 'displayName': 'Katılımcı ${i + 1}', 'present': i < 22, 'method': 'QR', if (i < 22) 'checkedInAt': _iso(now)},
    ])
    ..on('/events/5', {'id': 5, 'goingCount': 31, 'capacity': 40});
}

// ---------------------------------------------------------------------------------------------------------------
// 7) Yemek

void _menuData(FakeBackend b) {
  const menus = [
    ['Mercimek çorbası', 'Orman kebabı', 'Pirinç pilavı', 'Cacık'],
    ['Ezogelin çorbası', 'Kuru fasulye', 'Bulgur pilavı', 'Mevsim salata'],
    ['Domates çorbası', 'Tavuk sote', 'Makarna', 'Ayran'],
    ['Yayla çorbası', 'Etli nohut', 'Şehriyeli pilav', 'Turşu'],
  ];
  const kcal = {
    'Mercimek çorbası': 160, 'Orman kebabı': 420, 'Pirinç pilavı': 280, 'Cacık': 70,
    'Ezogelin çorbası': 150, 'Kuru fasulye': 290, 'Bulgur pilavı': 260, 'Mevsim salata': 90,
    'Domates çorbası': 140, 'Tavuk sote': 340, 'Makarna': 310, 'Ayran': 60,
    'Yayla çorbası': 170, 'Etli nohut': 330, 'Şehriyeli pilav': 270, 'Turşu': 25,
  };
  b.on('/menu', [
    for (var o = -2; o <= 6; o++)
      () {
        final items = menus[(DateTime.now().add(Duration(days: o)).day) % menus.length];
        return {
          'date': _day(o),
          'items': items,
          'dishes': [for (final i in items) {'name': i, 'kcal': kcal[i]}],
          'totalKcal': items.fold<int>(0, (a, i) => a + kcal[i]!),
          'kcalComplete': true,
        };
      }(),
  ]);
}

// ---------------------------------------------------------------------------------------------------------------
// 8) Anket

void _pollData(FakeBackend b) {
  final f = fakePolls(b, count: 0);
  final p = samplePoll(
    id: 1,
    title: 'Bahar şenliği konseri hangi türde olsun?',
    communityName: 'Müzik Kulübü',
    optionCount: 5,
    anonymous: true,
    showResults: 'AFTER_VOTE',
    closesAt: _iso(DateTime.now().add(const Duration(days: 2, hours: 3))),
  );
  p['description'] = 'Şenlik komitesi sahne programını hazırlıyor. Oyların toplamı kulüp temsilcilerine iletilecek.';
  const opts = ['Pop', 'Rock', 'Türk halk müziği', 'Elektronik', 'Caz'];
  p['options'] = [for (var i = 0; i < opts.length; i++) {'id': 101 + i, 'text': opts[i], 'position': i + 1}];
  f.polls.add(p);
  f.others[1] = {101: 34, 102: 51, 103: 22, 104: 18, 105: 9};
}

// ---------------------------------------------------------------------------------------------------------------
// 9) Akademik

final _reg = Expando<FakeAcademic>();

void _academicData(FakeBackend b) {
  final f = _reg[b] = fakeAcademic(b);
  f.semester = {'id': 3, 'name': '2026-2027 Güz', 'startDate': '2026-09-28', 'endDate': '2027-01-15', 'current': true};
  f.addCourse('Veri Tabanı Yönetimi', 4, '09:00', '10:45', room: 'A-102', code: 'BM-205');
  f.addCourse('Algoritma Analizi', 4, '11:00', '12:45', room: 'B-204', code: 'BM-201', instructor: 'Prof. Dr. M. Eren');
  f.addCourse('Nesne Yönelimli Programlama', 4, '13:30', '15:15', room: 'Laboratuvar 3', code: 'BM-203');
  f.addCourse('Ayrık Matematik', 4, '15:30', '17:15', room: 'Amfi 1', code: 'MAT-105');
  f.addCourse('İşletim Sistemleri', 2, '10:00', '11:45', room: 'B-101', code: 'BM-301');
  f.addExam('Veri Yapıları Vize', '2026-11-18T10:30:00+03:00');
  f.addExam('Algoritma Analizi Vize', '2026-11-21T14:00:00+03:00');
  f.exams.last['room'] = 'B-101';
  f.addExam('Ayrık Matematik Vize', '2026-11-24T09:30:00+03:00');
  f.exams.last['room'] = 'Amfi 2';
}

class _ReminderPlatform implements ReminderPlatform {
  @override
  Future<void> replaceAll(List<PlannedReminder> items) async {}

  @override
  Future<bool> shareText(String text, String subject) async => true;
}

// ---------------------------------------------------------------------------------------------------------------
// 10) Hesap silme ve 11) Destek

void _deleteData(FakeBackend b) {
  _core(b);
}

void _supportData(FakeBackend b) {
  b
    ..on('/faq', [
      {
        'category': 'Hesap',
        'items': [
          {
            'question': 'Şifremi nasıl değiştiririm?',
            'answer': 'Giriş ekranındaki "Şifremi unuttum" seçeneğiyle okul e-postana bir kod gönderilir; kodu girip yeni şifreni belirlersin.'
          },
          {'question': 'Hesabımı nasıl silerim?', 'answer': 'Profil > Ayarlar > Gizlilik ve veriler > Hesabımı sil yolunu izle.'},
          {'question': 'Etkinliğe nasıl katılırım?', 'answer': 'Etkinlik sayfasındaki Katıl düğmesine dokun; yoklama QR kodunu etkinlikte okutursun.'},
        ],
      },
    ])
    ..on('/support/tickets', {
      'items': [
        {'id': 3812, 'subject': 'Yemekhane puanı görünmüyor', 'status': 'ANSWERED', 'category': 'ACCOUNT', 'createdAt': DateTime.now().subtract(const Duration(days: 2)).toIso8601String()},
        {'id': 3790, 'subject': 'Kulüp listesinde eksiklik', 'status': 'OPEN', 'category': 'TECHNICAL', 'createdAt': DateTime.now().subtract(const Duration(days: 4)).toIso8601String()},
        {'id': 3411, 'subject': 'Derslik kodu güncellemesi', 'status': 'CLOSED', 'category': 'ACCOUNT', 'createdAt': DateTime.now().subtract(const Duration(days: 12)).toIso8601String()},
      ],
      'nextCursor': null,
    });
}

// ---------------------------------------------------------------------------------------------------------------

Future<void> _tapText(WidgetTester t, String text) async {
  await t.ensureVisible(find.text(text).first);
  await t.pump();
  await t.tap(find.text(text).first);
  await settle(t, const Duration(milliseconds: 700));
}

final _scenes = <_Scene>[
  _Scene('home', (b, s) => AppShell(session: s, themeController: ThemeController()), tab: AppTab.home, setup: (b) {
    _core(b);
    _homeData(b);
  }),
  _Scene('discover', (b, s) => AppShell(session: s, themeController: ThemeController()), tab: AppTab.discover, setup: (b) {
    _core(b);
    _discoverData(b);
  }),
  _Scene(
      'chat',
      (b, s) => ChatDetailPage(
            session: s,
            connectRealtime: false,
            mediaLibrary: FakeMediaLibrary.photos(8),
            ensureAccess: (c, p, {rationale}) async => true,
            conversation: const {
              'id': 1,
              'type': 'DIRECT',
              'title': 'Mehmet A.',
              'peer': {'id': 11, 'displayName': 'Mehmet A.'},
            },
          ),
      setup: _chatData),
  _Scene('clubs', (b, s) => AppShell(session: s, themeController: ThemeController()), tab: AppTab.clubs, setup: (b) {
    _core(b);
    _clubsData(b);
  }),
  _Scene('events', (b, s) => EventsPage(session: s), setup: _eventsData),
  _Scene('qr', (b, s) => Etkinlik2QrPage(session: s, event: _qrEvent), setup: _qrData),
  _Scene('menu', (b, s) => MenuPage(session: s), setup: (b) {
    _core(b);
    _menuData(b);
  }),
  _Scene('poll', (b, s) => PollDetailPage(session: s, pollId: 1), setup: _pollData, after: (t) => _tapText(t, 'Rock')),
  _Scene('academic', (b, s) => AcademicHubPage(session: s), setup: _academicData, now: DateTime.utc(2026, 11, 5, 6, 0)),
  _Scene('delete', (b, s) => DeleteAccountPage(session: s), setup: _deleteData),
  _Scene('support', (b, s) => SupportPage(session: s), setup: _supportData, after: (t) => _tapText(t, 'Şifremi nasıl değiştiririm?')),
];

// ---------------------------------------------------------------------------------------------------------------
// Sahte durum çubuğu + ana ekran çubuğu

class _StatusBar extends StatelessWidget {
  const _StatusBar();
  @override
  Widget build(BuildContext context) {
    const c = Color(0xFF111111);
    return IgnorePointer(
      child: Stack(children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: _topInset,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(36, 17, 28, 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('9:41',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700, color: c, decoration: TextDecoration.none)),
              const Spacer(),
              // sinyal çubukları
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (var i = 0; i < 4; i++)
                  Container(
                    margin: const EdgeInsets.only(right: 2),
                    width: 3.2,
                    height: 4.0 + i * 2.6,
                    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(1)),
                  ),
              ]),
              const SizedBox(width: 6),
              const Icon(Icons.wifi, size: 17, color: c),
              const SizedBox(width: 6),
              // pil
              Container(
                width: 25,
                height: 12,
                padding: const EdgeInsets.all(1.6),
                decoration: BoxDecoration(border: Border.all(color: c.withValues(alpha: 0.45)), borderRadius: BorderRadius.circular(3.6)),
                child: DecoratedBox(decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(1.8))),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

Widget _app(Widget home, GlobalKey key, double height) {
  const lang = 'tr';
  return RepaintBoundary(
    key: key,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: _w,
        height: height,
        child: Stack(children: [
          Positioned.fill(
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: BuTheme.forLocale(Brightness.light, lang),
              darkTheme: BuTheme.forLocale(Brightness.dark, lang),
              themeMode: ThemeMode.light,
              locale: const Locale(lang),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: home,
            ),
          ),
          const Positioned.fill(child: _StatusBar()),
        ]),
      ),
    ),
  );
}

void main() {
  final out = Platform.environment['SITE_SHOTS_OUT'];
  final skip = out == null ? 'SITE_SHOTS_OUT tanimli degil (yalniz site gorseli uretimi icin)' : null;
  final only = (Platform.environment['SITE_SHOTS_ONLY'] ?? '').split(',').where((e) => e.isNotEmpty).toList();

  setUpAll(loadTestFonts);
  tearDown(() {
    academicClock = DateTime.now;
    ReminderService.platform = const ChannelReminderPlatform();
    ReminderService.store = const SecureReminderStore();
    PermissionService.instance = SystemPermissionService();
  });

  for (final sc in _scenes) {
    if (only.isNotEmpty && !only.contains(sc.file)) continue;
    testWidgets('site gorseli ${sc.file}', skip: skip != null, (tester) async {
      debugNetworkImageHttpClientProvider = () => StoreImageHttpClient();
      addTearDown(() => debugNetworkImageHttpClientProvider = null);
      academicClock = () => sc.now ?? DateTime.now();
      ReminderService.platform = _ReminderPlatform();
      ReminderService.store = MemoryReminderStore(const ReminderSettings());
      PermissionService.instance = FakePermissionService(initial: {AppPermission.notifications: PermState.granted});
      tester.view.devicePixelRatio = _dpr;
      tester.view.physicalSize = Size(_w * _dpr, sc.height * _dpr);
      tester.view.padding = const FakeViewPadding(top: _topInset * _dpr, bottom: _bottomInset * _dpr);
      tester.view.viewPadding = const FakeViewPadding(top: _topInset * _dpr, bottom: _bottomInset * _dpr);
      addTearDown(tester.view.reset);

      mockSecureStorage();
      await HomeLayoutStore.clear();
      final b = FakeBackend();
      sc.setup?.call(b);
      final session = makeSession(b)..displayName = 'Ayşe K.';
      LocaleController.current = LocaleController(deviceLocales: () => [const Locale('tr')])..pref = 'tr';
      addTearDown(() => LocaleController.current = null);
      if (sc.tab != null) shellTabRequest.value = sc.tab;

      final key = GlobalKey();
      await tester.pumpWidget(_app(sc.build(b, session), key, sc.height));
      await tester.runAsync(() async {
        final ctx = tester.element(find.byType(Scaffold).first);
        await precacheImage(const AssetImage('assets/branding/default_avatar.png'), ctx);
      });
      await settle(tester, const Duration(milliseconds: 1500));
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
        await tester.pump(const Duration(milliseconds: 150));
      }
      if (sc.after != null) {
        await sc.after!(tester);
        await settle(tester, const Duration(milliseconds: 500));
      }
      final err = tester.takeException();
      if (err != null) fail('Istisna: $err');
      await tester.runAsync(() async {
        final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await ro.toImage(pixelRatio: _dpr);
        final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        final dir = Directory(out!)..createSync(recursive: true);
        final f = File('${dir.path}/${sc.file}.png')..writeAsBytesSync(data.buffer.asUint8List());
        // ignore: avoid_print
        print('YAZILDI ${f.path} ${image.width}x${image.height} ${f.lengthSync()} bayt');
      });
      await HomeLayoutStore.clear();
      await unmount(tester);
      debugNetworkImageHttpClientProvider = null;
    });
  }
}
