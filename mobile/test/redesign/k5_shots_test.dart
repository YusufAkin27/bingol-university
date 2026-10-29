@Tags(['store-shots'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/chat/chat_tab.dart';
import 'package:bu_kampus/features/chat/message_bubble.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import '../support/store_shots_images.dart';

/// K5 ekran goruntuleri: sohbet listesi durumlari (referans 18) + mesaj baloncuklari (referans 19).
///
/// Varsayilan `flutter test` ile CALISMAZ (STORE_SHOTS_OUT yoksa atlanir). Uretim (C:\bu_mobile, Git Bash):
///   STORE_SHOTS_OUT='C:/Users/.../redesign/k5/uygulama' flutter test test/redesign/k5_shots_test.dart
/// Istege bagli: `K5_LANG=tr|en|ar`, `K5_ONLY=L01,B03`, `K5_MODES=light,dark,x13`.
const _dpr = 2.5;

String _lang = 'tr';
String s(String tr, String en, String ar) => switch (_lang) {
      'ar' => ar,
      'en' => en,
      _ => tr,
    };

enum _Img { ok, hang }

class _Board {
  const _Board(this.file, this.build, {this.height = 844, this.img = _Img.ok, this.after, this.settleMs = 1000, this.drainMs = 0});
  final String file;
  final Widget Function() build;
  final double height;
  final _Img img;
  final Future<void> Function(WidgetTester t)? after;
  final int settleMs;
  final int drainMs;
}

class _Variant {
  const _Variant(this.suffix, this.dark, this.scale);
  final String suffix;
  final bool dark;
  final double scale;
}

class _HangClient implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Future<HttpClientRequest> getUrl(Uri url) => Completer<HttpClientRequest>().future;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) => Completer<HttpClientRequest>().future;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
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
  if (!arabic) return loadTestFonts();
  final f = FontLoader('Inter');
  for (final n in ['arial.ttf', 'arialbd.ttf']) {
    final file = File('C:/Windows/Fonts/$n');
    if (file.existsSync()) f.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await f.load();
  await loadIconFonts();
}

// ---------------------------------------------------------------------------------------------------------------
// Sohbet listesi verisi

String _iso(Duration ago) => DateTime.now().subtract(ago).toUtc().toIso8601String();

Map<String, dynamic> _row(
  int id,
  String type,
  String title, {
  int unread = 0,
  bool muted = false,
  String text = '',
  String? sender,
  int senderId = 0,
  Duration ago = const Duration(minutes: 5),
  List<Map<String, dynamic>>? att,
  String? status,
  bool deleted = false,
  bool online = false,
  int avatar = 0,
}) =>
    {
      'id': id,
      'type': type,
      'title': title,
      'avatarUrl': type == 'DIRECT' ? null : (avatar == 0 ? null : '/files/g$avatar.jpg'),
      if (type == 'DIRECT') 'peer': {'id': 10 + id, 'displayName': title, 'online': online, 'avatarUrl': avatar == 0 ? null : '/files/p$avatar.jpg'},
      'unreadCount': unread,
      'muted': muted,
      'lastMessage': {
        'id': 100 + id,
        'conversationId': id,
        'senderId': senderId == 0 ? 10 + id : senderId,
        if (sender != null) 'senderName': sender,
        'text': text,
        'deleted': deleted,
        'removed': false,
        'attachments': att ?? const [],
        if (status != null) 'status': status,
        'createdAt': _iso(ago),
      },
    };

List<Map<String, dynamic>> _fullList() => [
      _row(1, 'DIRECT', 'Zeynep Demir', unread: 3, online: true, avatar: 1, text: s('Kütüphane 3. katta mısın, notlarım sende mi?', 'Are you on the 3rd floor of the library?', 'هل أنت في الطابق الثالث من المكتبة؟'), ago: const Duration(minutes: 3)),
      _row(2, 'CLUB', s('Fotoğrafçılık Kulübü', 'Photography Club', 'نادي التصوير'), unread: 12, muted: true, avatar: 2, sender: 'Ahmet Yılmaz', text: s('Toplantı 18.00\'de Teknoloji Merkezi\'nde', 'Meeting at 18.00 at the Tech Center', 'الاجتماع الساعة 18.00 في مركز التقنية'), ago: const Duration(minutes: 20)),
      _row(3, 'DIRECT', 'Emre Can', avatar: 3, senderId: 1, status: 'READ', text: s('Tamamdır, yarın görüşürüz', 'Sounds good, see you tomorrow', 'تمام، نراك غدًا'), ago: const Duration(hours: 30)),
      _row(4, 'EVENT', s('Kariyer Günleri Soru-Cevap', 'Career Days Q&A', 'أيام المهنة: أسئلة وأجوبة'), avatar: 4, sender: s('Moderatör', 'Moderator', 'المشرف'), text: s('CV hazırlama sunumu başlıyor', 'The CV workshop is starting', 'ورشة السيرة الذاتية تبدأ'), ago: const Duration(hours: 31)),
      _row(5, 'DIRECT', 'Selin Kaya', avatar: 5, online: true, att: [
        {'id': 1, 'kind': 'IMAGE', 'url': '/x.jpg'}
      ], ago: const Duration(days: 3)),
      _row(6, 'DIRECT', 'Berkan Yıldız', avatar: 6, deleted: true, text: 'Bu mesaj silindi', ago: const Duration(days: 3)),
      _row(7, 'DIRECT', 'Derya Aydın', avatar: 7, att: [
        {'id': 2, 'kind': 'IMAGE', 'viewOnce': true, 'url': null}
      ], ago: const Duration(days: 10)),
      _row(8, 'DIRECT', 'Can Demir', avatar: 8, att: [
        {'id': 3, 'kind': 'VIDEO', 'url': '/v.mp4', 'durationMs': 42000}
      ], ago: const Duration(days: 12)),
    ];

FakeBackend _listBackend({List<Map<String, dynamic>>? items, List<Map<String, dynamic>>? archived, bool network = false, Duration delay = Duration.zero}) {
  final be = FakeBackend(delay: delay)..on('/conversations/unread-count', {'total': 18});
  be.on('/conversations?size=30', {'items': items ?? _fullList(), 'nextCursor': null});
  be.on('/conversations?size=30&archived=true', {
    'items': archived ??
        [
          _row(21, 'DIRECT', 'Doğukan Şahin', avatar: 9, senderId: 1, status: 'DELIVERED', text: s('Projeyi teslim ettik hocam', 'We submitted the project', 'سلّمنا المشروع'), ago: const Duration(days: 3)),
          _row(22, 'CLUB', s('Fotoğrafçılık Kulübü', 'Photography Club', 'نادي التصوير'), avatar: 2, sender: 'Ayşe', text: s('Yeni sergi için afiş taslakları onay bekliyor', 'Poster drafts for the new show await approval', 'مسودات ملصق المعرض بانتظار الموافقة'), ago: const Duration(days: 8)),
        ],
    'nextCursor': null
  });
  if (network) {
    be.reset('/conversations?size=30');
    be.reset('/conversations?size=30&archived=true');
    be.network('/conversations*');
  }
  return be;
}

Widget _tab(FakeBackend be) => ChatTab(session: makeSession(be), connectRealtime: false);

// ---------------------------------------------------------------------------------------------------------------
// Baloncuk verisi

String _at(int minsAgo) => DateTime.now().subtract(Duration(minutes: minsAgo)).toUtc().toIso8601String();

Map<String, dynamic> _m(int id, String text, {Map<String, dynamic>? extra, int ago = 30}) => {
      'id': id,
      'conversationId': 1,
      'senderId': 11,
      'text': text,
      'createdAt': _at(ago),
      ...?extra,
    };

Map<String, dynamic> _img(int id, {int w = 800, int h = 600}) => {'id': id, 'kind': 'IMAGE', 'url': '/a$id', 'thumbUrl': '/a$id', 'width': w, 'height': h};

Map<String, dynamic> _vid(int id) => {
      'id': id,
      'kind': 'VIDEO',
      'url': '/api/conversations/1/media/$id',
      'thumbUrl': '/api/conversations/1/media/$id/poster$id',
      'durationMs': 42000,
      'width': 1280,
      'height': 720,
    };

Widget _bubble(Map<String, dynamic> m, {bool mine = false, String? sender, String? replyName, bool seen = false, bool tail = true}) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: MessageBubble(
        message: m,
        mine: mine,
        senderName: sender,
        replyName: replyName,
        seen: seen,
        tail: tail,
        authHeaders: const {},
        onMenu: () {},
        onRetry: () {},
        onOpenImage: (_) {},
        onReact: (_) {},
        onOpenViewOnce: (_) {},
        onOpenGallery: (a, i) {},
      ),
    );

class _Chat extends StatelessWidget {
  const _Chat(this.children);
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.bu.bg,
        body: ListView(physics: const NeverScrollableScrollPhysics(), padding: const EdgeInsets.only(top: 44, bottom: 20), children: children),
      );
}

Widget _b1() => _Chat([
      _bubble(_m(1, s('Yarın sınav kaçta? Hoca duyuru yaptı mı?', 'What time is the exam tomorrow? Did the professor announce it?', 'متى الامتحان غدًا؟ هل أعلن الأستاذ؟'), ago: 60)),
      _bubble(
          _m(2, s('Saat 10.00\'da Mühendislik Binası 204\'te.', 'At 10.00 in Engineering Building 204.', 'الساعة 10.00 في مبنى الهندسة 204.'),
              extra: {'status': 'READ', 'senderId': 1, 'replyTo': {'id': 1, 'senderId': 11, 'text': s('Yarın sınav kaçta?', 'What time is the exam tomorrow?', 'متى الامتحان غدًا؟')}}, ago: 58),
          mine: true,
          seen: true,
          replyName: 'Mehmet'),
      _bubble(_m(3, s('Notları getirebilir misin?', 'Can you bring the notes?', 'هل يمكنك إحضار الملاحظات؟'), extra: {'edited': true}, ago: 55)),
      _bubble(_m(4, s('Kütüphaneden aldığım özetleri de getiriyorum.', 'I am also bringing the summaries from the library.', 'سأحضر أيضًا الملخصات من المكتبة.'), extra: {'status': 'DELIVERED', 'senderId': 1}, ago: 50), mine: true),
      _bubble(_m(5, s('Girişte buluşuruz o halde.', 'See you at the entrance then.', 'نلتقي عند المدخل إذن.'), extra: {'status': 'SENT', 'senderId': 1}, ago: 45), mine: true),
      _bubble(_m(6, s('Ben şimdi yola çıkıyorum.', 'I am heading out now.', 'أنا في الطريق الآن.'), extra: {'_state': 'pending', 'senderId': 1, 'id': null}, ago: 1), mine: true),
    ]);

Widget _b2() => _Chat([
      _bubble(
          _m(1, s('Sunum slaytlarını tamamladım, drive klasörüne yükledim.', 'I finished the slides and uploaded them to the drive.', 'أنهيت الشرائح ورفعتها إلى المجلد.'), extra: {
            'reactions': [
              {'emoji': '👍', 'count': 3},
              {'emoji': '❤️', 'count': 1}
            ],
            'myReaction': '👍',
          }, ago: 90),
          sender: 'Ahmet Demir'),
      const SizedBox(height: 10),
      _bubble(_m(2, s('Harika olmuş, eline sağlık! 3. slayttaki grafiği güncelledim.', 'Great work! I updated the chart on slide 3.', 'عمل رائع! حدّثت الرسم في الشريحة 3.'), extra: {
        'reactions': [
          {'emoji': '👏', 'count': 2}
        ],
      }, ago: 80), sender: 'Zeynep Arslan'),
      const SizedBox(height: 10),
      _bubble(_m(3, 'Bu mesaj silindi', extra: {'deleted': true}, ago: 70), sender: 'Ahmet Demir'),
      _bubble(_m(4, 'Bu mesaj yönetici tarafından kaldırıldı', extra: {'removed': true}, ago: 65)),
      _bubble(_m(5, s('Ben de kod reposunu inceledim, birleştirme isteğini onaylıyorum.', 'I reviewed the repo too and approve the merge request.', 'راجعت المستودع أيضًا وأوافق على طلب الدمج.'), extra: {'status': 'READ', 'senderId': 1}, ago: 60), mine: true, seen: true),
    ]);

Widget _b3() {
  final progress = ValueNotifier<double>(.65);
  return _Chat([
    _bubble(_m(1, s('Kampüs atölyesinde hazırladığımız prototip hazır!', 'The prototype we built at the campus workshop is ready!', 'النموذج الذي أعددناه في ورشة الحرم جاهز!'), extra: {'attachments': [_img(1, w: 900, h: 700)]}, ago: 60), sender: 'Alp Kaya'),
    const SizedBox(height: 10),
    _bubble(_m(2, '', extra: {'attachments': [_vid(90)]}, ago: 50), sender: 'Selin Deniz'),
    const SizedBox(height: 10),
    _bubble(_m(3, '', extra: {'_state': 'pending', 'senderId': 1, 'id': null, '_bytes': storeImageBytes(2), '_progress': progress}, ago: 1), mine: true),
  ]);
}

Widget _b3b() => _Chat([
      _bubble(_m(1, '', extra: {'attachments': [_img(1, w: 900, h: 700)]}, ago: 60), sender: 'Mert Aksoy'),
      _bubble(_m(2, '', extra: {'attachments': [_img(2, w: 900, h: 700)]}, ago: 50), sender: 'Mert Aksoy'),
    ]);

Widget _b4() => _Chat([
      _bubble(_m(1, '', extra: {'attachments': [{'id': 82, 'viewOnce': true, 'viewed': false, 'url': '/api/conversations/1/media/82'}]}, ago: 20), sender: 'Elif Yıldız'),
      const SizedBox(height: 10),
      _bubble(_m(2, '', extra: {'attachments': [{'id': 81, 'viewOnce': true, 'viewed': true, 'url': null}]}, ago: 18)),
      const SizedBox(height: 10),
      _bubble(_m(3, '', extra: {'status': 'READ', 'senderId': 1, 'attachments': [{'id': 80, 'viewOnce': true, 'viewed': false, 'url': null}]}, ago: 10), mine: true, seen: true),
      _bubble(_m(4, s('Ders notu sayfasını gördüm, teşekkürler!', 'I saw the lecture notes page, thanks!', 'رأيت صفحة ملاحظات الدرس، شكرًا!'), extra: {'status': 'READ', 'senderId': 1}, ago: 8), mine: true, seen: true),
    ]);

Widget _b5() => _Chat([
      _bubble(_m(1, s('Kütüphane 3. katta mısın? Kitapları getirdim.', 'Are you on the 3rd floor? I brought the books.', 'هل أنت في الطابق الثالث؟ أحضرت الكتب.'), ago: 40)),
      _bubble(_m(2, s('Evet, masa 14\'teyim bekliyorum.', 'Yes, I am at table 14 waiting.', 'نعم، أنا عند الطاولة 14 أنتظر.'), extra: {'_state': 'failed', 'senderId': 1, 'id': null, '_error': s('Gönderilemedi', 'Not sent', 'تعذّر الإرسال')}, ago: 35), mine: true),
      _bubble(_m(3, s('Ayrıca kahve aldım sana da getireyim mi?', 'I also got coffee, shall I bring you one?', 'اشتريت قهوة أيضًا، هل أحضر لك؟'), extra: {'_state': 'pending', '_queued': true, 'senderId': 1, 'id': null}, ago: 30), mine: true),
      _bubble(_m(4, s('Kütüphane 3. kat açık mı?', 'Is the 3rd floor open?', 'هل الطابق الثالث مفتوح؟'), ago: 5)),
    ]);

final _boards = <_Board>[
  _Board('L01_liste_dolu', () => _tab(_listBackend())),
  _Board('L02_liste_kaydir', () => _tab(_listBackend()), after: (t) async {
    final g = await t.startGesture(t.getCenter(find.text('Emre Can')));
    await g.moveBy(const Offset(-120, 0));
    await t.pump(const Duration(milliseconds: 100));
    await g.moveBy(const Offset(-40, 0));
    await t.pump(const Duration(milliseconds: 100));
  }),
  _Board('L03_liste_uzun_basma', () => _tab(_listBackend()), after: (t) async {
    await t.longPress(find.text('Zeynep Demir'));
  }),
  _Board('L04_arsiv', () => _tab(_listBackend()), after: (t) async {
    await t.tap(find.byIcon(LucideIcons.archive).first);
    await settle(t, const Duration(milliseconds: 800));
  }),
  _Board('L04b_arsiv_bos', () => _tab(_listBackend(archived: [])), after: (t) async {
    await t.tap(find.byIcon(LucideIcons.archive).first);
    await settle(t, const Duration(milliseconds: 800));
  }),
  _Board('L05_bos', () => _tab(_listBackend(items: [])), height: 844),
  _Board('L05b_arama_yok', () => _tab(_listBackend()), after: (t) async {
    await t.enterText(find.byType(TextField), 'zzz');
    await settle(t, const Duration(milliseconds: 400));
  }),
  _Board('L06_yukleniyor', () => _tab(_listBackend(delay: const Duration(seconds: 2))), settleMs: 300, drainMs: 2500),
  _Board('L06b_hata_cevrimdisi', () => _tab(_listBackend(network: true))),
  _Board('B1_balon_metin', _b1, height: 700),
  _Board('B2_balon_grup', _b2, height: 700),
  _Board('B3_balon_medya', _b3, height: 1000),
  _Board('B3b_balon_gorsel_yukleniyor', _b3b, height: 700, img: _Img.hang, settleMs: 700),
  _Board('B4_balon_tek_gosterimlik', _b4, height: 520),
  _Board('B5_balon_hata_kuyruk', _b5, height: 560),
];

Future<void> _pumpImages(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump(const Duration(milliseconds: 120));
  }
  await settle(tester, const Duration(milliseconds: 500));
}

void main() {
  final out = Platform.environment['STORE_SHOTS_OUT'];
  final skip = out == null ? 'STORE_SHOTS_OUT tanimli degil (yalniz ekran goruntusu uretimi icin)' : null;
  _lang = (Platform.environment['K5_LANG'] ?? 'tr');
  final only = (Platform.environment['K5_ONLY'] ?? '').split(',').where((e) => e.isNotEmpty).toList();
  final modes = (Platform.environment['K5_MODES'] ?? 'light').split(',');
  final variants = <_Variant>[
    if (modes.contains('light')) const _Variant('', false, 1),
    if (modes.contains('dark')) const _Variant('_koyu', true, 1),
    if (modes.contains('x13')) const _Variant('_x1.3', false, 1.3),
  ];

  setUpAll(() => _loadFonts(_lang == 'ar'));

  for (final v in variants) {
    for (final b in _boards) {
      if (only.isNotEmpty && !only.any((o) => b.file.startsWith(o))) continue;
      final name = '${b.file}${v.suffix}_$_lang';
      testWidgets('k5 $name', skip: skip != null, (tester) async {
        tester.view.devicePixelRatio = _dpr;
        tester.view.physicalSize = Size(390 * _dpr, b.height * _dpr);
        tester.view.padding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        tester.view.viewPadding = const FakeViewPadding(top: 28 * _dpr, bottom: 16 * _dpr);
        addTearDown(tester.view.reset);

        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        debugNetworkImageHttpClientProvider = switch (b.img) {
          _Img.ok => () => StoreImageHttpClient(),
          _Img.hang => () => _HangClient(),
        };

        final key = GlobalKey();
        await tester.pumpWidget(_app(b.build(), v.dark, key, v.scale));
        await settle(tester, Duration(milliseconds: b.settleMs));
        if (b.img == _Img.ok) await _pumpImages(tester);
        if (b.after != null) {
          await b.after!(tester);
          await settle(tester, const Duration(milliseconds: 600));
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
        if (b.drainMs > 0) await settle(tester, Duration(milliseconds: b.drainMs));
        await unmount(tester);
        debugNetworkImageHttpClientProvider = null;
      });
    }
  }
}
