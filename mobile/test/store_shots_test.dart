@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/nav.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:bu_kampus/features/events/etkinlik2_qr_page.dart';
import 'package:bu_kampus/features/menu/menu_page.dart';
import 'package:bu_kampus/features/polls/poll_detail_page.dart';
import 'package:bu_kampus/features/shell/app_shell.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'support/fake_app.dart';
import 'support/store_shots_images.dart';

/// Google Play mağaza ekran görüntüleri (IMG1): GERÇEK ekran widget'ları + sahte API/tohum veri, 1080x1920 PNG.
///
/// Varsayılan `flutter test` ile ÇALIŞMAZ (ortam değişkeni yoksa atlanır). Üretim (Git Bash, C:\bu_mobile içinde):
///   STORE_SHOTS_OUT='C:/.../store-assets' flutter test test/store_shots_test.dart
/// İsteğe bağlı: `STORE_SHOTS_LANG=tr|en` (varsayılan ikisi), `STORE_SHOTS_ONLY=01,05`.
/// Veri tamamen uydurmadır (gerçek kişi/e-posta/fotoğraf yok); görseller `store_shots_images.dart` ile üretilir.

// Tuval: mantıksal 405x720 @ 2.6667 = 1080x1920. Uygulama ekranı 360x600 (960x1600 piksel).
const _canvas = Size(405, 720);
const _screen = Size(345, 636); // çerçeve (çıktıda 960x1696 piksel)
const _appSize = Size(392, 723); // uygulamanın gördüğü mantıksal telefon boyutu; çerçeveye küçültülür
const _headerH = 66.0;
const _dpr = 1080 / 405;

class _Shot {
  const _Shot(this.file, this.titleTr, this.titleEn, this.build, {this.dark = false, this.tab, this.after});
  final String file; // örn. 01_ana_sayfa
  final String titleTr, titleEn;
  final Widget Function(_Ctx c) build;
  final bool dark;
  final int? tab; // AppShell sekmesi
  final Future<void> Function(WidgetTester t)? after; // çizimden sonra (kaydırma vb.)
}

class _Ctx {
  _Ctx(this.lang, this.b, this.session, this.theme);
  final String lang;
  final FakeBackend b;
  final Session session;
  final ThemeController theme;
  bool get tr => lang == 'tr';
}

String _iso(DateTime d) => d.toUtc().toIso8601String();

Map<String, dynamic> _backendFor(String lang, FakeBackend b) {
  final tr = lang == 'tr';
  String t(String a, String e) => tr ? a : e;
  final now = DateTime.now();

  b
    ..on('/me/summary', {
      'unreadNotifications': 2,
      'unreadMessages': 3,
      'communities': 3,
      'events': 4,
      'bookmarks': 6,
      'upcomingEvents': 2,
    })
    ..on('/users/me', {
      'id': 1,
      'displayName': 'Ayşe Kaya',
      'email': 'seed.ayse@bingol.edu.tr',
      'faculty': t('Mühendislik Fakültesi', 'Faculty of Engineering'),
      'department': t('Bilgisayar Mühendisliği', 'Computer Engineering'),
      'grade': '3',
      'bio': t('Yazılım, satranç ve kampüs etkinlikleri.', 'Software, chess and campus events.'),
      'showEmail': false,
      'language': lang,
    })
    ..on('/auth/me', {'id': 1, 'email': 'seed.ayse@bingol.edu.tr', 'displayName': 'Ayşe Kaya', 'role': 'USER'})
    ..on('/menu/today', {
      'date': now.toIso8601String().substring(0, 10),
      'items': tr
          ? ['Mercimek çorbası', 'Izgara tavuk', 'Bulgur pilavı', 'Cacık', 'Sütlaç']
          : ['Lentil soup', 'Grilled chicken', 'Bulgur pilaf', 'Tzatziki', 'Rice pudding'],
    })
    ..on('/news?type=DUYURU&page=0&size=3', {
      'items': [
        {
          'id': 1,
          'type': 'DUYURU',
          'title': t('Güz dönemi ders ekleme-bırakma tarihleri açıklandı', 'Add/drop dates for the fall term announced'),
          'publishedDate': now.subtract(const Duration(days: 1)).toIso8601String().substring(0, 10),
          'imageUrl': null,
        },
        {
          'id': 2,
          'type': 'DUYURU',
          'title': t('Kütüphane çalışma saatleri sınav haftasında uzatıldı', 'Library hours extended during exam week'),
          'publishedDate': now.subtract(const Duration(days: 2)).toIso8601String().substring(0, 10),
          'imageUrl': null,
        },
        {
          'id': 3,
          'type': 'DUYURU',
          'title': t('Kayıt yenileme işlemleri için son gün', 'Last day for registration renewal'),
          'publishedDate': now.subtract(const Duration(days: 3)).toIso8601String().substring(0, 10),
          'imageUrl': null,
        },
      ],
    })
    ..on('/events/featured', {
      'id': 9,
      'title': t('Bahar Şenliği: Açık Hava Konseri', 'Spring Fest: Open-Air Concert'),
      'startsAt': _iso(now.add(const Duration(days: 2, hours: 3))),
      'endsAt': _iso(now.add(const Duration(days: 2, hours: 6))),
      'location': t('Merkez Kampüs Amfi', 'Main Campus Amphitheater'),
      'goingCount': 128,
      'myRsvp': null,
      'coverUrl': '/files/events/7.jpg',
      'communityName': t('Müzik Topluluğu', 'Music Society'),
      'attendeesPreview': [
        for (final n in ['Mehmet Aksoy', 'Zeynep Çelik', 'Emre Yıldırım', 'Elif Şahin', 'Can Öztürk'])
          {'userId': 2, 'displayName': n, 'avatarUrl': null},
      ],
    })
    ..on('/status', {
      'NEWS': {'maintenance': false},
      'MENU': {'maintenance': false},
    });

  // --- Keşfet ---
  Map<String, dynamic> post(int id, String text, String author, String dept, int? media,
      {int likes = 12, int w = 1080, int h = 1350, bool liked = false, int ago = 2}) {
    final p = samplePost(
      id: id,
      text: text,
      media: media == null ? [] : [samplePostMedia(id: media, width: w, height: h)],
      likeCount: likes,
      commentCount: 0,
      liked: liked,
      authorId: 10 + id,
      authorName: author,
      createdAt: _iso(now.subtract(Duration(hours: ago))),
    );
    (p['author'] as Map)['department'] = dept;
    return p;
  }

  final posts = [
    post(1, t('Kampüste sonbahar güzelliği', 'Autumn colors on campus'), 'Selin Aydın', t('Peyzaj Mimarlığı', 'Landscape Architecture'), 8,
        likes: 48, h: 1350, liked: true, ago: 1),
    post(2, t('Kütüphanede final haftası', 'Finals week at the library'), 'Burak Koç', t('Makine Mühendisliği', 'Mechanical Engineering'), 11,
        likes: 31, h: 1080, ago: 3),
    post(3, t('Halı saha maçı bu akşam!', 'Pitch match tonight!'), 'Emre Tan', t('Spor Bilimleri', 'Sports Sciences'), 13,
        likes: 22, h: 1200, ago: 4),
    post(4, t('Satranç turnuvası başlıyor', 'Chess tournament begins'), 'Derya Polat', t('Matematik', 'Mathematics'), 14,
        likes: 57, h: 1350, ago: 5),
    post(5, t('Yarın sınav öncesi son tekrar', 'Last review before tomorrow\'s exam'), 'Can Öztürk', t('İşletme', 'Business'), null,
        likes: 9, ago: 6),
    post(6, t('Bahar şenliği hazırlıkları', 'Spring fest preparations'), 'Elif Şahin', t('Müzik Bilimleri', 'Music Studies'), 15,
        likes: 36, h: 1080, ago: 7),
    post(7, t('Gün batımı manzarası', 'Sunset view'), 'Zeynep Çelik', t('Fizik', 'Physics'), 10,
        likes: 64, h: 1350, ago: 9),
    post(8, t('Öğle yemeği bugün harika', 'Lunch was great today'), 'Mehmet Aksoy', t('Elektrik-Elektronik', 'Electrical Engineering'), 12,
        likes: 18, h: 1080, ago: 11),
  ];
  b
    ..on('/feed*', {'items': posts, 'nextCursor': null})
    ..on('/posts/mine*', {'items': [posts[0], posts[3], posts[6]], 'nextCursor': null});

  // --- Kulüpler ---
  Map<String, dynamic> club(int id, String name, String cat, String desc, int members,
          {String status = 'NONE', String policy = 'OPEN'}) =>
      {
        'id': id,
        'name': name,
        'category': cat,
        'description': desc,
        'shortDescription': desc,
        'memberCount': members,
        'myStatus': status,
        'joinPolicy': policy,
        'logoUrl': null,
      };
  final clubs = [
    club(1, t('Satranç Kulübü', 'Chess Club'), 'Spor', t('Haftalık turnuvalar ve eğitimler', 'Weekly tournaments and lessons'), 84, status: 'ACTIVE'),
    club(2, t('Robotik ve Yazılım Topluluğu', 'Robotics Society'), 'Teknoloji', t('Yarışmalar, atölyeler, hackathon', 'Contests, workshops, hackathons'), 212,
        status: 'ACTIVE'),
    club(3, t('Müzik Topluluğu', 'Music Society'), 'Sanat', t('Konserler ve açık sahne geceleri', 'Concerts and open-mic nights'), 156, status: 'ACTIVE'),
    club(4, t('Fotoğrafçılık Kulübü', 'Photography Club'), 'Sanat', t('Foto gezileri ve sergiler', 'Photo walks and exhibitions'), 97),
    club(5, t('Tiyatro Topluluğu', 'Theatre Society'), 'Sanat', t('Oyun provaları ve gösteriler', 'Play rehearsals and shows'), 73, policy: 'APPROVAL'),
    club(6, t('Doğa Sporları Kulübü', 'Outdoor Sports Club'), 'Spor', t('Kamp, trekking ve doğa yürüyüşleri', 'Camping, trekking and hikes'), 120),
  ];
  b
    ..on('/communities/categories', [
      {'key': 'Teknoloji', 'name': t('Teknoloji', 'Technology'), 'count': 1},
      {'key': 'Spor', 'name': t('Spor', 'Sports'), 'count': 2},
      {'key': 'Sanat', 'name': t('Sanat', 'Arts'), 'count': 3},
    ])
    ..on('/me/communities*', {'items': clubs.take(3).toList(), 'nextCursor': null})
    ..on('/communities*', {'items': clubs, 'nextCursor': null});

  // --- Sohbet ---
  Map<String, dynamic> row(int id, String type, String title, String text, int minAgo,
          {int unread = 0, bool photo = false, int sender = 0}) =>
      {
        'id': id,
        'type': type,
        'title': title,
        if (type == 'DIRECT') 'peer': {'id': 10 + id, 'displayName': title},
        'unreadCount': unread,
        'lastMessage': {
          'id': 100 + id,
          'conversationId': id,
          'senderId': sender == 0 ? 10 + id : sender,
          'text': text,
          'attachments': photo
              ? [
                  {'id': 1, 'kind': 'IMAGE', 'url': '/x.jpg'}
                ]
              : const [],
          'createdAt': _iso(now.subtract(Duration(minutes: minAgo))),
        },
      };
  b
    ..on('/conversations/unread-count', {'total': 3})
    ..on('/conversations?*', {
      'items': [
        row(1, 'DIRECT', 'Mehmet Aksoy', t('Yarınki ders notlarını atar mısın?', 'Can you send tomorrow\'s lecture notes?'), 4, unread: 2),
        row(2, 'CLUB', t('Satranç Kulübü', 'Chess Club'), t('Turnuva eşleşmeleri açıklandı', 'Tournament pairings are out'), 25, unread: 1),
        row(3, 'DIRECT', 'Zeynep Çelik', '', 70, photo: true),
        row(4, 'EVENT', t('Bahar Şenliği', 'Spring Fest'), t('Sahne düzeni yarın 10:00\'da', 'Stage setup tomorrow at 10:00'), 130),
        row(5, 'DIRECT', 'Elif Şahin', t('Teşekkürler, çok yardımcı oldu!', 'Thanks, that was really helpful!'), 300, sender: 1),
        row(6, 'GROUP', t('Proje Grubu', 'Project Group'), t('Sunum dosyasını güncelledim', 'I updated the slides'), 1500),
      ],
      'nextCursor': null,
    });

  // sohbet ayrıntısı
  Map<String, dynamic> msg(int id, int sender, String text, int minAgo, {Map<String, dynamic>? extra}) => {
        'id': id,
        'conversationId': 1,
        'senderId': sender,
        'text': text,
        'createdAt': _iso(now.subtract(Duration(minutes: minAgo))),
        ...?extra,
      };
  b
    ..on('/conversations/1/messages?size=30', {
      'items': [
        msg(8, 1, t('Harika, çok teşekkürler!', 'Great, thank you so much!'), 1, extra: {'status': 'READ'}),
        msg(7, 11, t('Hemen gönderiyorum, tahtadan çektim', 'Sending it now, I took it from the board'), 3, extra: {
          'attachments': [
            {'id': 21, 'kind': 'IMAGE', 'url': '/a3', 'thumbUrl': '/a3', 'width': 800, 'height': 600},
          ]
        }),
        msg(6, 1, t('Yarınki ders notlarını atar mısın?', 'Can you send tomorrow\'s lecture notes?'), 6, extra: {'status': 'READ'}),
        msg(5, 11, t('Akşam kütüphanede buluşalım mı?', 'Shall we meet at the library tonight?'), 14),
        msg(4, 1, t('Süper, saat kaçta?', 'Sounds good, what time?'), 12, extra: {'status': 'READ'}),
      ],
      'nextCursor': null,
    })
    ..on('/conversations/1', {
      'conversation': {'id': 1},
      'members': [
        {'userId': 1, 'displayName': 'Ayşe Kaya'},
        {'userId': 11, 'displayName': 'Mehmet Aksoy'},
      ],
    })
    ..on('/users/11/presence', {'online': true})
    ..on('/messages/reactions', {'emojis': <String>[]});

  // --- Yemek: ayın tüm günleri ---
  final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
  final menus = tr
      ? [
          ['Mercimek çorbası', 'Izgara tavuk', 'Bulgur pilavı', 'Cacık', 'Sütlaç'],
          ['Ezogelin çorbası', 'Kuru fasulye', 'Pirinç pilavı', 'Mevsim salata', 'Meyve'],
          ['Domates çorbası', 'Orman kebabı', 'Makarna', 'Ayran', 'Revani'],
          ['Yayla çorbası', 'Etli nohut', 'Şehriyeli pilav', 'Turşu', 'Kemalpaşa'],
        ]
      : [
          ['Lentil soup', 'Grilled chicken', 'Bulgur pilaf', 'Tzatziki', 'Rice pudding'],
          ['Ezogelin soup', 'White beans stew', 'Rice pilaf', 'Seasonal salad', 'Fruit'],
          ['Tomato soup', 'Forest kebab', 'Pasta', 'Ayran', 'Semolina cake'],
          ['Yogurt soup', 'Chickpeas with meat', 'Orzo pilaf', 'Pickles', 'Syrup dessert'],
        ];
  b.on('/menu*', [
    for (var d = 1; d <= daysInMonth; d++)
      {
        'date': '${now.year}-${now.month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}',
        'items': menus[d % menus.length],
        'imageUrl': '/files/menu/$d-4.jpg',
      },
  ]);
  // Bugünün menüsü yukarıdaki ile aynı olsun.
  b.on('/menu/today', {
    'date': now.toIso8601String().substring(0, 10),
    'items': menus[now.day % menus.length],
    'imageUrl': '/files/menu/${now.day}-4.jpg',
  });

  // --- QR yoklama ---
  b
    ..on('/events/9/attendance', [
      for (var i = 0; i < 24; i++)
        {'userId': 100 + i, 'displayName': 'Katılımcı $i', 'present': i < 17, 'method': 'QR', 'markedAt': _iso(now)},
    ])
    ..on('/events/9/checkin-code', {
      'code': '9.482.k7q2xm',
      'qrPayload': 'bingol-checkin:9.482.k7q2xm',
      'validForSeconds': 120,
      'expiresAt': _iso(now.add(const Duration(seconds: 120))),
    });

  // --- Anket ---
  final f = fakePolls(b, count: 1);
  final p = f.polls[0];
  p['title'] = t('Bahar Şenliği konseri hangi türde olsun?', 'Which genre for the Spring Fest concert?');
  p['communityName'] = t('Müzik Topluluğu', 'Music Society');
  p['anonymous'] = true;
  final opts = tr ? ['Pop', 'Rock', 'Türk halk müziği', 'Elektronik'] : ['Pop', 'Rock', 'Folk', 'Electronic'];
  p['options'] = [
    for (var i = 0; i < opts.length; i++) {'id': 101 + i, 'text': opts[i], 'position': i + 1},
  ];
  p['myVote'] = {'optionIds': [102], 'rating': null, 'votedAt': _iso(now)};
  f.others[1] = {101: 9, 102: 14, 103: 6, 104: 5};
  return {};
}

// ---------------------------------------------------------------------------------------------

final _shots = <_Shot>[
  _Shot('01_ana_sayfa', 'Kampüs bir arada', 'Campus in one place', (c) => _shell(c), tab: AppTab.home, after: (t) async {
    await t.drag(find.byType(Scrollable).first, const Offset(0, -228));
  }),
  _Shot('02_kesfet', 'Paylaş ve keşfet', 'Share and discover', (c) => _shell(c), tab: AppTab.discover),
  _Shot('03_sohbet', 'Anında mesajlaş', 'Chat in real time', (c) => ChatDetailPage(
        session: c.session,
        connectRealtime: false,
        conversation: const {
          'id': 1,
          'type': 'DIRECT',
          'title': 'Mehmet Aksoy',
          'peer': {'id': 11, 'displayName': 'Mehmet Aksoy'},
        },
      )),
  _Shot('04_kulupler', 'Kulüplere katıl', 'Join clubs', (c) => _shell(c), tab: AppTab.clubs),
  _Shot('05_etkinlik_qr', 'QR ile yoklama', 'Check in with QR', (c) => Etkinlik2QrPage(session: c.session, event: {
        'id': 9,
        'title': c.tr ? 'Bahar Şenliği: Açık Hava Konseri' : 'Spring Fest: Open-Air Concert',
        'startsAt': _iso(DateTime.now().add(const Duration(hours: 1))),
        'location': c.tr ? 'Merkez Kampüs Amfi' : 'Main Campus Amphitheater',
      })),
  _Shot('06_yemek', 'Günün menüsü', 'Today\'s menu', (c) => MenuPage(session: c.session)),
  _Shot('07_anket', 'Oy ver', 'Have your say', (c) => PollDetailPage(session: c.session, pollId: 1)),
  _Shot('08_profil', 'Üç dil, iki tema', 'Three languages, two themes', (c) => _shell(c), dark: true, tab: AppTab.profile, after: (t) async {
    await t.drag(find.byType(Scrollable).last, const Offset(0, -560));
  }),
];

Widget _shell(_Ctx c) => AppShell(session: c.session, themeController: c.theme);

/// Sahte durum çubuğu (9:41, tam şarj): gerçek cihaz çubuğu ekran görüntüsünde yok.
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.dark});
  final bool dark;
  @override
  Widget build(BuildContext context) {
    final color = dark ? Colors.white : const Color(0xFF111111);
    final bg = (dark ? BuTheme.dark() : BuTheme.light()).extension<BuTokens>()!.bg;
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      height: 28,
      child: IgnorePointer(
        child: ColoredBox(
          color: bg,
          child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 6, 18, 0),
          child: Row(children: [
            Text('9:41', style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
            const Spacer(),
            Icon(LucideIcons.signal, size: 13, color: color),
            const SizedBox(width: 5),
            Icon(LucideIcons.wifi, size: 13, color: color),
            const SizedBox(width: 5),
            Icon(LucideIcons.batteryFull, size: 16, color: color),
          ]),
          ),
        ),
      ),
    );
  }
}

Widget _canvasWidget(Widget app, String title, bool dark, GlobalKey boundary) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: RepaintBoundary(
      key: boundary,
      child: SizedBox(
        width: _canvas.width,
        height: _canvas.height,
        child: Stack(children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0F2446), Color(0xFF0A1830)]),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: _headerH,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(title,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 29,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            decoration: TextDecoration.none)),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: (_canvas.width - _screen.width) / 2,
            top: _headerH,
            width: _screen.width,
            height: _screen.height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0x33FFFFFF), width: 1.2),
                boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 8))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: Stack(children: [
                  Positioned.fill(
                    child: FittedBox(
                      fit: BoxFit.fill,
                      child: SizedBox(
                        width: _appSize.width,
                        height: _appSize.height,
                        child: Stack(children: [Positioned.fill(child: app), _StatusBar(dark: dark)]),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 4,
            child: ColoredBox(color: Color(0xFFFF3B30)),
          ),
        ]),
      ),
    ),
  );
}

Widget _appFor(Widget home, String lang, bool dark) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: BuTheme.light(),
    darkTheme: BuTheme.dark(),
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
      data: MediaQuery.of(context).copyWith(
        size: _appSize,
        devicePixelRatio: _dpr,
        padding: const EdgeInsets.only(top: 30, bottom: 8),
        viewPadding: const EdgeInsets.only(top: 30, bottom: 8),
        textScaler: TextScaler.noScaling,
      ),
      child: child!,
    ),
    home: home,
  );
}

Future<void> _pumpImages(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  final out = Platform.environment['STORE_SHOTS_OUT'];
  final skip = out == null ? 'STORE_SHOTS_OUT tanımlı değil (yalnız mağaza görseli üretimi için)' : null;
  final langs = (Platform.environment['STORE_SHOTS_LANG'] ?? 'tr,en').split(',');
  final only = (Platform.environment['STORE_SHOTS_ONLY'] ?? '').split(',').where((e) => e.isNotEmpty).toList();

  setUpAll(() async {
    await loadTestFonts();
  });

  for (final lang in langs) {
    for (final shot in _shots) {
      if (only.isNotEmpty && !only.any((o) => shot.file.startsWith(o))) continue;
      testWidgets('mağaza görseli ${shot.file}_$lang', skip: skip != null, (tester) async {
        debugNetworkImageHttpClientProvider = () => StoreImageHttpClient();
        addTearDown(() => debugNetworkImageHttpClientProvider = null);
        tester.view.devicePixelRatio = _dpr;
        tester.view.physicalSize = Size(_canvas.width * _dpr, _canvas.height * _dpr);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final b = FakeBackend();
        _backendFor(lang, b);
        final session = makeSession(b)..api.lang = lang;
        final theme = ThemeController()..mode = shot.dark ? ThemeMode.dark : ThemeMode.light;
        final ctx = _Ctx(lang, b, session, theme);
        LocaleController.current = LocaleController(deviceLocales: () => [Locale(lang)])..pref = lang;
        addTearDown(() => LocaleController.current = null);
        final boundary = GlobalKey();
        final tab = shot.tab;
        if (tab != null) shellTabRequest.value = tab;
        await tester.pumpWidget(_canvasWidget(
            _appFor(shot.build(ctx), lang, shot.dark), lang == 'tr' ? shot.titleTr : shot.titleEn, shot.dark, boundary));
        await settle(tester, const Duration(milliseconds: 800));
        await _pumpImages(tester);
        await settle(tester, const Duration(milliseconds: 300));

        if (shot.after != null) {
          await shot.after!(tester);
          await settle(tester, const Duration(milliseconds: 500));
          await _pumpImages(tester);
        }
        final err = tester.takeException();
        if (err != null) fail('Istisna: $err');

        await tester.runAsync(() async {
          final ro = boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await ro.toImage(pixelRatio: _dpr);
          final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
          final dir = Directory(out!)..createSync(recursive: true);
          final f = File('${dir.path}/${shot.file}_$lang.png')..writeAsBytesSync(data.buffer.asUint8List());
          // ignore: avoid_print
          print('YAZILDI ${f.path} ${image.width}x${image.height} ${f.lengthSync()} bayt');
        });
        await unmount(tester);
        // Boyama hata ayıklama değişkeni test sonu denetiminden ÖNCE sıfırlanmalı (addTearDown geç kalır).
        debugNetworkImageHttpClientProvider = null;
      });
    }
  }
}
