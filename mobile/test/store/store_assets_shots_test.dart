import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/clubs/clubs_tab.dart';
import 'package:bu_kampus/features/discover/discover_tab.dart';
import 'package:bu_kampus/features/events/events_page.dart';
import 'package:bu_kampus/features/home/home_tab.dart';
import 'package:bu_kampus/features/menu/menu_page.dart';
import 'package:bu_kampus/features/menu/menu_photo.dart';
import 'package:bu_kampus/features/shell/bukampus_bottom_navigation_bar.dart';
import 'package:bu_kampus/features/news/news_list_page.dart';
import 'package:bu_kampus/features/profile/settings_page.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import '../support/store_shots_images.dart';

/// Magaza gorselleri icin TEMIZ ekran goruntuleri (uydurma icerik, gercek kisi verisi yok), dil basina.
/// Uretim: STORE_OUT=C:/bu_store/raw STORE_LANG=tr flutter test test/store/store_assets_shots_test.dart
/// Cikti: <STORE_OUT>/<dil>/<home|news|events|menu|clubs|profile>.png  (393x852 dp x 3 = 1179x2556)
const _dpr = 3.0;
const _w = 393.0;
const _h = 852.0;
String _lang = 'tr';

String _l(String tr, String en, String ar) => _lang == 'tr' ? tr : (_lang == 'en' ? en : ar);

String _day(int offset) {
  final n = DateTime.now().add(Duration(days: offset));
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

String _iso(int days, int hour) {
  final n = DateTime.now().add(Duration(days: days));
  return DateTime(n.year, n.month, n.day, hour).toUtc().toIso8601String();
}

Map<String, dynamic> _user() => {
      'id': 1,
      'email': 'elif.demir@example.com',
      'displayName': _l('Elif Demir', 'Emily Carter', 'ليلى حداد'),
      'faculty': _l('Mühendislik-Mimarlık Fakültesi', 'Faculty of Engineering and Architecture', 'كلية الهندسة والعمارة'),
      'department': _l('Bilgisayar Mühendisliği', 'Computer Engineering', 'هندسة الحاسوب'),
      'classYear': 3,
      'bio': _l('Yazılım kulübünde ve kampüs etkinliklerinde yer alıyorum.', 'Into software, clubs and campus events.',
          'أحب البرمجة والأندية وفعاليات الحرم الجامعي.'),
      if (_lang != 'ar') 'username': _l('elif.demir', 'emily.carter', 'layla.haddad'),
      'postCount': 0,
      'showEmail': false,
      'language': _lang,
    };

List<String> _dishes() => [
      _l('Osmanlı çorbası', 'Ottoman soup', 'شوربة عثمانية'),
      _l('Garnitürlü pirinç pilavı', 'Rice pilaf with vegetables', 'أرز بالخضار'),
      _l('Etli güveç', 'Beef casserole', 'طاجن اللحم'),
      _l('Havuçlu kırmızı lahana salatası', 'Carrot and red cabbage salad', 'سلطة الجزر والملفوف الأحمر'),
    ];

Map<String, dynamic> _menuDay(int d) => {
      'date': _day(d),
      'items': _dishes(),
      'imageUrl': '/files/menu/today.jpg',
      'dishes': [
        {'name': _dishes()[0], 'kcal': 170},
        {'name': _dishes()[1], 'kcal': 280},
        {'name': _dishes()[2], 'kcal': 390},
        {'name': _dishes()[3], 'kcal': 80},
      ],
      'totalKcal': 920,
      'kcalComplete': true,
    };

List<Map<String, dynamic>> _news(String type) {
  final t = type == 'HABER'
      ? [
          _l('Bahar Dönemi Kayıt Takvimi Açıklandı', 'Spring Semester Registration Calendar Announced', 'الإعلان عن جدول التسجيل للفصل الربيعي'),
          _l('Girişimcilik Buluşması Kampüste', 'Entrepreneurship Meetup on Campus', 'لقاء ريادة الأعمال في الحرم الجامعي'),
          _l('Kütüphane Sınav Haftası Saatleri', 'Library Hours for Exam Week', 'ساعات المكتبة في أسبوع الامتحانات'),
          _l('Öğrenci Takımından Büyük Başarı', 'Great Success for the Student Team', 'نجاح كبير لفريق الطلاب'),
          _l('Kampüs Yeşil Alan Projesi Başladı', 'Campus Green Space Project Begins', 'انطلاق مشروع المساحات الخضراء'),
          _l('Kariyer Merkezi Staj Görüşmeleri', 'Career Center Internship Interviews', 'مقابلات التدريب في مركز المسار المهني'),
          _l('Kütüphane Hafta Sonu da Açık', 'Library Now Open on Weekends', 'المكتبة مفتوحة الآن في عطلات الأسبوع'),
        ]
      : [
          _l('Ders Ekleme-Bırakma Tarihleri', 'Add/Drop Dates', 'مواعيد إضافة وحذف المقررات'),
          _l('Burs Başvuruları Başladı', 'Scholarship Applications Open', 'بدء التقديم على المنح'),
        ];
  return [
    for (var i = 0; i < t.length; i++)
      {
        'id': 10 + i,
        'type': type,
        'title': t[i],
        'publishedDate': _day(-1 - i),
        'imageUrl': null,
        'summary': null,
      },
  ];
}

Map<String, dynamic> _ev(int id, String title, String club, int days, int hour, int going, {String? rsvp}) => {
      'id': id,
      'source': 'USER',
      'title': title,
      'description': '',
      'startsAt': _iso(days, hour),
      'endsAt': _iso(days, hour + 2),
      'location': _l('Merkez Kütüphane', 'Central Library', 'المكتبة المركزية'),
      'communityName': club,
      'goingCount': going,
      'capacity': 60,
      'myRsvp': rsvp,
      'canManage': false,
      'registrationClosed': false,
      'status': 'ACTIVE',
      'coverUrl': null,
    };

List<Map<String, dynamic>> _events() => [
      _ev(1, _l('Sonbahar Fotoğraf Yürüyüşü', 'Autumn Photo Walk', 'جولة التصوير الخريفية'), _l('Fotoğraf Kulübü', 'Photography Club', 'نادي التصوير'), 1, 15, 24, rsvp: 'GOING'),
      _ev(2, _l('Yazılım ve Girişimcilik Günü', 'Software and Startup Day', 'يوم البرمجة وريادة الأعمال'), _l('Yazılım Kulübü', 'Software Club', 'نادي البرمجة'), 2, 13, 41),
      _ev(3, _l('Satranç Turnuvası', 'Chess Tournament', 'بطولة الشطرنج'), _l('Satranç Kulübü', 'Chess Club', 'نادي الشطرنج'), 3, 17, 18),
      _ev(4, _l('Kariyer Günleri', 'Career Days', 'أيام التوظيف'), _l('Kariyer Topluluğu', 'Career Society', 'جمعية المسار المهني'), 5, 10, 76),
      _ev(5, _l('Açık Hava Sineması', 'Open-Air Cinema', 'سينما الهواء الطلق'), _l('Sinema Kulübü', 'Film Club', 'نادي السينما'), 6, 20, 52),
    ];

Map<String, dynamic> _club(int id, String name, String cat, String desc, int members, {String status = 'NONE'}) => {
      'id': id,
      'name': name,
      'category': cat,
      'description': desc,
      'memberCount': members,
      'myStatus': status,
      'joinPolicy': 'OPEN',
      'logoUrl': null,
    };

void _seed(FakeBackend b, String screen) {
  final tech = _l('Teknoloji', 'Technology', 'التقنية');
  final art = _l('Sanat', 'Arts', 'الفنون');
  final sport = _l('Spor', 'Sports', 'الرياضة');
  final clubs = [
    _club(1, _l('Yazılım Kulübü', 'Software Club', 'نادي البرمجة'), tech, _l('Birlikte kod yazıyor, proje geliştiriyoruz.', 'We code and build projects together.', 'نبرمج ونطوّر المشاريع معاً.'), 214, status: 'ACTIVE'),
    _club(2, _l('Fotoğraf Kulübü', 'Photography Club', 'نادي التصوير'), art, _l('Kampüsü kadraja alıyoruz.', 'Framing life on campus.', 'نلتقط الحياة في الحرم الجامعي.'), 168),
    _club(3, _l('Satranç Kulübü', 'Chess Club', 'نادي الشطرنج'), sport, _l('Haftalık turnuvalar ve eğitimler.', 'Weekly tournaments and lessons.', 'بطولات ودروس أسبوعية.'), 97, status: 'ACTIVE'),
    _club(4, _l('Müzik Kulübü', 'Music Club', 'نادي الموسيقى'), art, _l('Sahne, prova ve konserler.', 'Stage, rehearsals and concerts.', 'مسرح وبروفات وحفلات.'), 143),
    _club(5, _l('Robotik Topluluğu', 'Robotics Society', 'جمعية الروبوتات'), tech, _l('Robot yarışmalarına hazırlanıyoruz.', 'Preparing for robotics contests.', 'نستعد لمسابقات الروبوتات.'), 121),
    _club(6, _l('Tiyatro Kulübü', 'Theatre Club', 'نادي المسرح'), art, _l('Her dönem yeni bir oyun.', 'A new play every term.', 'مسرحية جديدة كل فصل.'), 88),
  ];
  b
    ..on('/users/me', _user())
    ..on('/auth/me', _user())
    ..on('/me/summary', {'unreadNotifications': 3, 'unreadMessages': 2, 'communities': 2, 'upcomingEvents': 2, 'events': 3, 'bookmarks': 4})
    ..on('/menu/today', _menuDay(0))
    ..on('/menu', [for (var d = -1; d <= 6; d++) _menuDay(d)])
    ..on('/events/featured', _events().first)
    ..on('/news?type=HABER*', {'items': _news('HABER'), 'totalPages': 1})
    ..on('/news?type=DUYURU*', {'items': _news('DUYURU'), 'totalPages': 1})
    ..on('/news?type=ETKINLIK*', {'items': <Object>[], 'totalPages': 1})
    ..on('/events/calendar*', _events(), headers: {'x-truncated': 'false'})
    ..on('/me/events*', {'items': _events().take(2).toList(), 'nextCursor': null})
    ..on('/me/communities*', {'items': clubs.where((c) => c['myStatus'] == 'ACTIVE').toList(), 'nextCursor': null})
    ..on('/communities/categories', [
      {'category': tech},
      {'category': art},
      {'category': sport},
    ])
    ..on('/communities*', {'items': clubs, 'nextCursor': null})
    ..on('/posts/mine*', {'items': <Object>[], 'nextCursor': null})
    ..on('/users/1/reels*', {'items': <Object>[], 'nextCursor': null})
    ..on('/notifications/preferences', {'news': true, 'announcements': true, 'events': true, 'communities': true, 'messages': true})
    ..on('/feed*', {'items': _feed(), 'nextCursor': null})
    ..on('/feed/seen', null, status: 204)
    ..on('/users/me/follow-suggestions*', {'items': <Object>[]})
    ..on('/users/me/privacy', {'showEmail': false, 'showFaculty': true, 'showDepartment': true, 'showBio': true});
}

List<Map<String, dynamic>> _feed() {
  const heights = [1350, 1080, 1620, 1350, 1080, 1480, 1350, 1620, 1080, 1350, 1480, 1080];
  const names = ['Elif D.', 'Mert K.', 'Selin A.', 'Can Y.', 'Derya T.', 'Emre S.'];
  return [
    for (var i = 0; i < heights.length; i++)
      samplePost(
        id: 500 - i,
        text: null,
        media: [samplePostMedia(id: 800 + i, height: heights[i])],
        likeCount: 12 + (i * 17) % 90,
        commentCount: 2 + i % 6,
        authorName: names[i % 6],
      ),
  ];
}

Session _session(FakeBackend b) {
  final s = makeSession(b);
  s.displayName = '${_user()['displayName']}';
  s.email = '${_user()['email']}';
  return s;
}

Widget _app(Widget home, GlobalKey key) {
  final lang = _lang;
  return RepaintBoundary(
    key: key,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: BuTheme.forLocale(Brightness.light, lang),
      darkTheme: BuTheme.forLocale(Brightness.dark, lang),
      themeMode: ThemeMode.light,
      locale: Locale(lang),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    ),
  );
}

/// Gercek kabuk gorunumu: alt gezinti cubugu + durum cubugu (saat/sinyal/pil); icerik cubugun ustunde biter.
Widget _framed(Widget page, int navIndex, Session s) {
  final badge = ValueNotifier<int>(0);
  return Builder(builder: (context) {
    final mq = MediaQuery.of(context);
    return Stack(children: [
      Column(children: [
        Expanded(child: MediaQuery.removePadding(context: context, removeBottom: true, child: page)),
        ColoredBox(
          color: context.bu.bg,
          child: BukampusBottomNavigationBar(index: navIndex, onChanged: (_) {}, chatBadge: badge, onPublish: () {}),
        ),
      ]),
      Positioned(
        top: 0, left: 0, right: 0, height: mq.padding.top,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: ColoredBox(
            color: context.bu.bg,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(34, 14, 30, 0),
              child: Row(children: [
                Text('09:41', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.bu.ink)),
                const Spacer(),
                Icon(Icons.signal_cellular_alt, size: 18, color: context.bu.ink),
                const SizedBox(width: 5),
                Icon(Icons.wifi, size: 18, color: context.bu.ink),
                const SizedBox(width: 5),
                Icon(Icons.battery_full, size: 20, color: context.bu.ink),
              ]),
            ),
          ),
        ),
      ),
    ]);
  });
}

Future<void> _loadFonts(bool arabic) async {
  if (!arabic) return loadTestFonts();
  final f = FontLoader('Inter');
  for (final n in ['arial.ttf', 'arialbd.ttf']) {
    final file = File('C:/Windows/Fonts/$n');
    if (file.existsSync()) f.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await f.load();
  await loadIconFonts();
}

void main() {
  final out = Platform.environment['STORE_OUT'];
  final skip = out == null ? 'STORE_OUT tanimli degil' : null;
  _lang = Platform.environment['STORE_LANG'] ?? 'tr';
  final only = (Platform.environment['STORE_ONLY'] ?? '').split(',').where((e) => e.isNotEmpty).toList();

  setUpAll(() => _loadFonts(_lang == 'ar'));

  final shots = <String, Widget Function(FakeBackend b)>{
    'home': (b) => _framed(HomeTab(session: _session(b), onOpenTab: (i, {newsType}) {}), 0, _session(b)),
    'discover': (b) => _framed(DiscoverTab(session: _session(b), typeRequest: ValueNotifier<String?>(null)), 1, _session(b)),
    'news': (b) => _framed(NewsListPage(session: _session(b)), 0, _session(b)),
    'events': (b) => _framed(EventsPage(session: _session(b)), 0, _session(b)),
    'menu': (b) => _framed(MenuPage(session: _session(b)), 0, _session(b)),
    'clubs': (b) => _framed(ClubsTab(session: _session(b)), 3, _session(b)),
    'profile': (b) => _framed(SettingsPage(session: _session(b), themeController: ThemeController()), 4, _session(b)),
  };

  for (final e in shots.entries) {
    if (only.isNotEmpty && !only.contains(e.key)) continue;
    testWidgets('store ${e.key} $_lang', skip: skip != null, (tester) async {
      debugNetworkImageHttpClientProvider = () => StoreImageHttpClient();
      storePhotos = [
        for (var i = 1; i <= 8; i++) File('C:/bu_store/photos/p$i.jpg').readAsBytesSync(),
      ];
      addTearDown(() => storePhotos = null);
      final menuBytes = File('C:/bu_store/photos/menu_today.jpg').readAsBytesSync();
      MenuPhotoGate.debugProvider = (_) => MemoryImage(menuBytes);
      addTearDown(() => MenuPhotoGate.debugProvider = null);
      tester.view.devicePixelRatio = _dpr;
      tester.view.physicalSize = const Size(_w * _dpr, _h * _dpr);
      tester.view.padding = const FakeViewPadding(top: 48 * _dpr, bottom: 14 * _dpr);
      tester.view.viewPadding = const FakeViewPadding(top: 48 * _dpr, bottom: 14 * _dpr);
      addTearDown(tester.view.reset);

      final b = FakeBackend();
      _seed(b, e.key);
      LocaleController.current = LocaleController(deviceLocales: () => [Locale(_lang)])..pref = _lang;
      addTearDown(() => LocaleController.current = null);

      final key = GlobalKey();
      await tester.pumpWidget(_app(Scaffold(body: e.value(b)), key));
      await settle(tester, const Duration(milliseconds: 1500));
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
        await tester.pump(const Duration(milliseconds: 400));
      }
      final err = tester.takeException();
      if (err != null) fail('Istisna: $err');
      await tester.runAsync(() async {
        final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await ro.toImage(pixelRatio: _dpr);
        final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        final dir = Directory('$out/$_lang')..createSync(recursive: true);
        final f = File('${dir.path}/${e.key}.png')..writeAsBytesSync(data.buffer.asUint8List());
        // ignore: avoid_print
        print('YAZILDI ${f.path} ${image.width}x${image.height}');
      });
      await unmount(tester);
      debugNetworkImageHttpClientProvider = null;
    });
  }
}
