import 'dart:convert';
import 'dart:io';

import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/pending_verification.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/widgets/bu_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Ortak widget test çerçevesi: sahte backend + oturum + tema sarmalayıcı.
///
/// Kullanım:
/// ```dart
/// final b = FakeBackend()..on('/news', {...});
/// final s = makeSession(b);
/// await tester.pumpWidget(buildApp(HomeTab(...), brightness: Brightness.dark, size: kPhoneSmall));
/// ```
const kPhoneSmall = Size(320, 640);
const kPhoneMedium = Size(390, 844);
const kPhoneLarge = Size(430, 932);
const kPhoneSizes = [kPhoneSmall, kPhoneMedium, kPhoneLarge];

/// Yol (ve sorgu) -> JSON eşlemesi. Anahtar `/news` ya da `/news?type=HABER` olabilir;
/// sonu `*` ile biten anahtarlar önek eşler. Önce tam (yol+sorgu), sonra yol, sonra önek, sonra varsayılan.
class FakeBackend {
  FakeBackend({this.delay = Duration.zero});

  /// Her yanıttan önceki bekleme (yükleniyor durumunu görmek için).
  Duration delay;

  final Map<String, _Reply> _routes = {};

  /// Gelen istekler: "GET /news?type=HABER" biçiminde.
  final List<String> requests = [];

  /// Gönderilen gövdeler (POST/PUT/PATCH): "POST /auth/login" -> son gövde.
  final Map<String, Object?> bodies = {};

  /// Aynı anahtarın tüm JSON gövdeleri (sırayla): "POST /conversations/1/messages" -> [..].
  final Map<String, List<Object?>> bodyLog = {};

  /// Tüm istekler ağ hatası verir (true iken).
  bool offline = false;

  /// Yönteme duyarlı dinamik işleyiciler (rotalardan ÖNCE sorulur; null = ilgilenmiyorum).
  final List<FakeHandler> handlers = [];

  /// Yol için JSON yanıtı (varsayılanı ezer).
  void on(String path, Object? json, {int status = 200, Map<String, String>? headers}) {
    _routes[path] = _Reply(status, json, headers ?? const {});
  }

  /// Yol için ikili yanıt. [once] true ise yalnız İLK istek 200 + bayt alır, sonrakiler 410
  /// `MEDIA_VIEW_ONCE_EXPIRED` döner (tek gösterimlik görsel).
  void onBytes(String path, List<int> bytes, {bool once = false}) {
    _routes[path] = _Reply(200, null, const {'content-type': 'image/png'}, raw: bytes, once: once);
  }

  /// Yol için hata yanıtı: `{code,message}`.
  void fail(String path, {int status = 500, String code = 'SERVER_ERROR', String message = ''}) {
    _routes[path] = _Reply(status, {'code': code, 'message': message}, const {});
  }

  /// Yol için ağ hatası.
  void network(String path) => _routes[path] = _Reply(-1, null, const {});

  /// Yol eşlemesini kaldırır (varsayılana döner).
  void reset(String path) => _routes.remove(path);

  int count(String needle) => requests.where((r) => r.contains(needle)).length;

  late final MockClient client = MockClient((req) async {
    final path = req.url.path.startsWith('/api') ? req.url.path.substring(4) : req.url.path;
    final full = req.url.hasQuery ? '$path?${req.url.query}' : path;
    requests.add('${req.method} $full');
    try {
      // Multipart (ikili) gövdeler çözülemeyebilir: yalnız JSON gövdeler kaydedilir.
      if (req.body.isNotEmpty) {
        final decoded = jsonDecode(req.body);
        bodies['${req.method} $path'] = decoded;
        (bodyLog['${req.method} $path'] ??= []).add(decoded);
      }
    } catch (_) {}
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (offline) throw http.ClientException('offline');
    for (final h in handlers) {
      final hr = h(req, path);
      if (hr == null) continue;
      if (hr.bytes != null) {
        return http.Response.bytes(hr.bytes!, hr.status, headers: {'content-type': hr.contentType});
      }
      if (hr.status == 204) return http.Response.bytes(const [], 204);
      return http.Response.bytes(utf8.encode(jsonEncode(hr.json)), hr.status,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }
    final r = _lookup(req.method, path, full);
    if (r.status == -1) throw http.ClientException('network down');
    if (r.raw != null) {
      if (r.once && r.served) {
        return http.Response.bytes(
            utf8.encode(jsonEncode({'code': 'MEDIA_VIEW_ONCE_EXPIRED', 'message': 'Süresi doldu.'})), 410,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }
      r.served = true;
      return http.Response.bytes(r.raw!, 200, headers: {'content-type': 'image/png'});
    }
    return http.Response.bytes(utf8.encode(jsonEncode(r.json)), r.status,
        headers: {'content-type': 'application/json; charset=utf-8', ...r.headers});
  });

  _Reply _lookup(String method, String path, String full) {
    final exact = _routes[full] ?? _routes[path];
    if (exact != null) return exact;
    for (final e in _routes.entries) {
      if (e.key.endsWith('*') && full.startsWith(e.key.substring(0, e.key.length - 1))) return e.value;
    }
    if (method != 'GET') return _Reply(200, <String, dynamic>{}, const {});
    return _defaults(path);
  }

  static _Reply _defaults(String path) {
    // Öne çıkan etkinlik yoksa sunucu 204 döner.
    if (path == '/events/featured') return _Reply(204, null, const {});
    Object? ok(Object? j) => j;
    final j = switch (path) {
      '/me/summary' => ok({
          'unreadNotifications': 0,
          'unreadMessages': 0,
          'communities': 0,
          'upcomingEvents': 0,
        }),
      '/app/info' => ok({'maintenance': {'enabled': false}, 'banner': null}),
      '/app/version' => ok({'updateRequired': false, 'updateAvailable': false}),
      '/status' => ok({
          'NEWS': {'maintenance': false},
          'MENU': {'maintenance': false},
        }),
      '/users/me' || '/auth/me' => ok({
          'id': 1,
          'email': 'ayse@bingol.edu.tr',
          'displayName': 'Ayşe Yılmaz',
          'role': 'USER',
        }),
      '/news' => ok(newsPage(const [])),
      '/bookmarks/news/ids' => ok({'ids': <int>[]}),
      '/bookmarks' => ok({'items': <Object>[], 'nextCursor': null}),
      '/events/calendar' => ok(<Object>[]),
      '/menu/today' => ok(<String, dynamic>{}),
      '/me/communities' => ok({'items': <Object>[], 'nextCursor': null}),
      _ => null,
    };
    if (j != null) return _Reply(200, j, const {});
    // Bilinen "liste" uçları için boş sayfa; geri kalan 404.
    if (path.startsWith('/news/')) {
      return _Reply(200, {'id': 1, 'content': ''}, const {});
    }
    if (path.endsWith('/messages') ||
        path == '/conversations' ||
        path == '/notifications' ||
        path == '/communities' ||
        path == '/events' ||
        path == '/blocks' ||
        path == '/search') {
      return _Reply(200, {'items': <Object>[], 'nextCursor': null}, const {});
    }
    return _Reply(404, {'code': 'NOT_FOUND', 'message': 'Bulunamadı.'}, const {});
  }
}

/// [FakeBackend.handlers] işleyicisi: `path` `/api` önekisiz yoldur.
typedef FakeHandler = FakeResult? Function(http.Request req, String path);

/// Dinamik işleyici yanıtı (JSON ya da bayt).
class FakeResult {
  const FakeResult.json(this.json, {this.status = 200})
      : bytes = null,
        contentType = 'application/json';
  const FakeResult.bytes(this.bytes, {this.contentType = 'image/png', this.status = 200}) : json = null;
  final Object? json;
  final List<int>? bytes;
  final String contentType;
  final int status;
}

class _Reply {
  _Reply(this.status, this.json, this.headers, {this.raw, this.once = false});
  final List<int>? raw;
  final bool once;
  bool served = false;
  final int status;
  final Object? json;
  final Map<String, String> headers;
}

/// `/news` sayfa yanıtı (backend biçimi).
Map<String, dynamic> newsPage(List<Map<String, dynamic>> items, {int totalPages = 1}) =>
    {'items': items, 'page': 0, 'size': 20, 'totalPages': items.isEmpty ? 0 : totalPages};

/// Örnek haber kaydı.
Map<String, dynamic> newsItem(int id,
        {String type = 'HABER', String? title, String? imageUrl, String? eventDate}) =>
    {
      'id': id,
      'type': type,
      'title': title ?? 'Haber başlığı $id',
      'summary': 'Özet $id',
      'imageUrl': imageUrl,
      'url': 'https://www.bingol.edu.tr/haber/$id',
      'publishedDate': '2026-10-2${id % 10}',
      'eventDate': eventDate,
    };

bool _channelMocked = false;

/// flutter_secure_storage kanalını boş bir depoyla taklit eder.
void mockSecureStorage() {
  if (_channelMocked) return;
  _channelMocked = true;
  TestWidgetsFlutterBinding.ensureInitialized();
  final store = <String, String>{};
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async {
      final args = (call.arguments as Map?) ?? const {};
      final key = args['key'] as String?;
      switch (call.method) {
        case 'read':
          return store[key];
        case 'write':
          store[key!] = args['value'] as String;
          return null;
        case 'delete':
          store.remove(key);
          return null;
        case 'readAll':
          return Map<String, String>.of(store);
        case 'deleteAll':
          store.clear();
          return null;
        case 'containsKey':
          return store.containsKey(key);
      }
      return null;
    },
  );
}

/// Sahte backend'e bağlı oturum. `signedIn` ise kimlik alanları doldurulur (token yok: WebSocket açılmaz).
Session makeSession(FakeBackend b, {bool signedIn = true}) {
  mockSecureStorage();
  final s = Session(ApiClient(client: b.client, retryDelay: Duration.zero))
    ..pending = PendingVerificationStore.memory();
  if (signedIn) {
    s.state = SessionState.signedIn;
    s.userId = 1;
    s.displayName = 'Ayşe Yılmaz';
    s.email = 'ayse@bingol.edu.tr';
  }
  return s;
}

/// Sayfayı gerçek tema + isteğe bağlı sabit ekran boyutuyla saran MaterialApp.
Widget buildApp(Widget home, {Brightness brightness = Brightness.light, Size? size}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: BuTheme.light(),
    darkTheme: BuTheme.dark(),
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    home: home,
    builder: size == null
        ? null
        : (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(size: size),
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(width: size.width, height: size.height, child: child),
              ),
            ),
  );
}

/// Test görünümünü verilen mantıksal boyuta (dpr 1) ayarlar; test sonunda geri alınır.
void useScreen(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Zamanlayıcılı sayfalar için pumpAndSettle yerine sınırlı pump.
Future<void> settle(WidgetTester tester, [Duration total = const Duration(seconds: 1)]) async {
  const step = Duration(milliseconds: 100);
  var t = Duration.zero;
  await tester.pump();
  while (t < total) {
    await tester.pump(step);
    t += step;
  }
}

/// Sayfayı ağaçtan kaldırır (dispose + zamanlayıcı temizliği) ve kalan çerçeveleri işler.
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

/// Testte varsayılan "Ahem" yazı tipi her harfi kare çizer ve sahte taşma üretir.
/// Flutter SDK'sındaki gerçek Roboto yüklenir; `setUpAll(loadTestFonts)` ile çağırın.
Future<void> loadTestFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? 'C:/src/flutter';
  final dir = '$root/bin/cache/artifacts/material_fonts';
  final loader = FontLoader('Roboto');
  var any = false;
  for (final f in ['regular', 'medium', 'bold', 'black', 'light']) {
    final file = File('$dir/roboto-$f.ttf');
    if (!file.existsSync()) continue;
    any = true;
    loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  if (any) await loader.load();

  // Uygulamanin tek yazi tipi Inter: testte de gercek dosyalar yuklenir (yoksa Ahem'e dusmesin diye Roboto yedegi).
  final inter = FontLoader('Inter');
  var haveInter = false;
  for (final f in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    final file = File('assets/fonts/Inter-$f.ttf');
    if (!file.existsSync()) continue;
    haveInter = true;
    inter.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  if (haveInter) await inter.load();
}

/// Akademik katalog için küçük sahte veri (`GET /catalog/academic`).
const kFakeAcademic = <String, dynamic>{
  'version': 1,
  'faculties': [
    {
      'id': 'muhendislik',
      'name': 'Mühendislik Fakültesi',
      'departments': [
        {'id': 'bilgisayar-muhendisligi', 'name': 'Bilgisayar Mühendisliği'},
        {'id': 'elektrik-muhendisligi', 'name': 'Elektrik-Elektronik Mühendisliği'},
      ],
    },
    {
      'id': 'fen-edebiyat',
      'name': 'Fen-Edebiyat Fakültesi',
      'departments': [
        {'id': 'biyoloji', 'name': 'Biyoloji'},
        {'id': 'turk-dili', 'name': 'Türk Dili ve Edebiyatı'},
      ],
    },
  ],
  'grades': [
    {'id': 'PREP', 'name': 'Hazırlık'},
    {'id': '1', 'name': '1. sınıf'},
    {'id': '2', 'name': '2. sınıf'},
    {'id': '3', 'name': '3. sınıf'},
    {'id': '4', 'name': '4. sınıf'},
    {'id': 'MASTER', 'name': 'Yüksek lisans'},
    {'id': 'PHD', 'name': 'Doktora'},
  ],
};

/// Sahte backend'e katalog yanıtını ekler.
void fakeCatalog(FakeBackend b) => b.on('/catalog/academic', kFakeAcademic);

/// Seçici ekranında arama yapıp (isteğe bağlı) ilk eşleşen satırı seçer.
Future<void> pickFromSearch(WidgetTester tester, String query, String rowText) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.enterText(find.descendant(of: find.byType(BuSearchField), matching: find.byType(TextField)), query);
  await tester.pump();
  await tester.tap(find.text(rowText).last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}
/// Kayıt formunda bölümü (fakülte otomatik gelir) ve sınıfı arayüzden seçer.
Future<void> fillAcademic(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Bölüm seçin'));
  await tester.tap(find.text('Bölüm seçin'));
  await pickFromSearch(tester, 'bilg', 'Bilgisayar Mühendisliği');
  await tester.ensureVisible(find.text('3. sınıf'));
  await tester.tap(find.text('3. sınıf'));
  await tester.pump();
}
/// Varsayılan avatar/grup görselleri hariç, içerik görselleri (ağ/bellek) için bulucu.
Finder contentImages() => find.byWidgetPredicate((w) {
      if (w is! Image) return false;
      final i = w.image;
      return !(i is AssetImage && i.assetName.contains('default_'));
    });

// ---------------------------------------------------------------------------------------------
// Gönderiler (docs/POSTS_DESIGN.md) sahte uçları
// ---------------------------------------------------------------------------------------------

/// 1x1 PNG (medya bayt yanıtı).
final List<int> kFakePng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

/// Küçük sahte MP4 başlığı (ftyp).
final List<int> kFakeMp4 = [0, 0, 0, 24, 0x66, 0x74, 0x79, 0x70, 0x69, 0x73, 0x6f, 0x6d, 0, 0, 2, 0, ...List.filled(8, 0)];

Map<String, dynamic> samplePostAuthor({int id = 12, String name = 'Ayşe Yılmaz', String? department = 'Bilgisayar Mühendisliği'}) =>
    {'id': id, 'displayName': name, 'avatarUrl': null, 'department': department};

/// Sözleşmedeki medya haritası.
Map<String, dynamic> samplePostMedia(
        {int id = 5, bool video = false, int width = 1080, int height = 1350, int? durationMs}) =>
    {
      'id': id,
      'kind': video ? 'VIDEO' : 'IMAGE',
      'url': '/api/posts/media/$id',
      'thumbUrl': '/api/posts/media/$id?thumb=true',
      'width': width,
      'height': height,
      'durationMs': video ? (durationMs ?? 12000) : null,
    };

/// Sözleşmedeki PostView haritası.
Map<String, dynamic> samplePost({
  int id = 91,
  String? text,
  List<Map<String, dynamic>> media = const [],
  bool liked = false,
  int likeCount = 4,
  int commentCount = 2,
  bool mine = false,
  int authorId = 12,
  String authorName = 'Ayşe Yılmaz',
  String createdAt = '2026-10-26T09:00:00Z',
}) =>
    {
      'id': id,
      'author': samplePostAuthor(id: authorId, name: authorName),
      'text': text ?? (media.isEmpty ? 'Gönderi metni $id' : null),
      'media': media,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'likedByMe': liked,
      'mine': mine,
      'canEdit': mine,
      'canDelete': mine,
      'createdAt': createdAt,
      'editedAt': null,
    };

/// Sözleşmedeki CommentView haritası.
Map<String, dynamic> sampleComment({
  int id = 77,
  int postId = 91,
  int? parentId,
  int? rootId,
  int depth = 0,
  String text = 'Yorum',
  bool deleted = false,
  int replyCount = 0,
  bool mine = false,
  int authorId = 13,
  String authorName = 'Mehmet Kaya',
  Map<String, dynamic>? replyToUser,
  List<Map<String, dynamic>>? previewReplies,
  String createdAt = '2026-10-26T10:00:00Z',
}) =>
    {
      'id': id,
      'postId': postId,
      'parentId': parentId,
      'rootId': rootId ?? id,
      'depth': depth,
      'author': {'id': authorId, 'displayName': authorName, 'avatarUrl': null},
      'replyToUser': replyToUser,
      'text': deleted ? null : text,
      'deleted': deleted,
      'replyCount': replyCount,
      'mine': mine,
      'canEdit': mine && !deleted,
      'canDelete': mine,
      'createdAt': createdAt,
      'editedAt': null,
      'previewReplies': previewReplies,
    };

/// [fakePosts] durumu: testler gönderi/yorum listelerini okuyup değiştirebilir.
class FakePosts {
  FakePosts(this.backend, {int count = 12, this.pageSize = 10, bool withMedia = true}) {
    for (var i = 0; i < count; i++) {
      final id = 1000 - i;
      final media = !withMedia
          ? <Map<String, dynamic>>[]
          : switch (i % 4) {
              1 => [samplePostMedia(id: id * 10)],
              2 => [samplePostMedia(id: id * 10), samplePostMedia(id: id * 10 + 1, video: true)],
              _ => <Map<String, dynamic>>[],
            };
      posts.add(samplePost(
          id: id,
          media: media,
          likeCount: i % 5,
          commentCount: 0,
          text: i % 4 == 1 ? null : 'Gönderi $id',
          createdAt: DateTime.utc(2026, 10, 26, 12).subtract(Duration(hours: i)).toIso8601String()));
    }
  }

  final FakeBackend backend;

  /// Sayfa boyutu (istekteki `size` verilmediyse).
  final int pageSize;

  /// En yeni başta.
  final List<Map<String, dynamic>> posts = [];

  /// Gönderi id -> düz yorum listesi (kök + yanıtlar, eskiden yeniye).
  final Map<int, List<Map<String, dynamic>>> comments = {};

  /// Yüklenen (henüz bağlanmamış) medya.
  final Map<int, Map<String, dynamic>> uploadedMedia = {};

  /// Boş akış (`/feed` ve kullanıcı gönderileri).
  bool emptyFeed = false;

  /// true iken `/feed` 500 döner.
  bool failFeed = false;

  /// Yüklemede hata kodu (örn. `VIDEO_TOO_LARGE`); null = başarılı.
  String? uploadError;

  /// Tüm beğeniler: id kümesi.
  final Set<int> likedIds = {};

  int _nextPost = 2000;
  int _nextComment = 5000;
  int _nextMedia = 9000;

  Map<String, dynamic>? postById(int id) {
    for (final p in posts) {
      if (p['id'] == id) return p;
    }
    return null;
  }

  /// Sahte gönderiye `n` kök yorum (ilk birinin 3 yanıtı var) ekler.
  void seedComments(int postId, {int roots = 3}) {
    final list = comments.putIfAbsent(postId, () => []);
    for (var i = 0; i < roots; i++) {
      final id = _nextComment++;
      list.add(sampleComment(id: id, postId: postId, text: 'Kök yorum $i', replyCount: i == 0 ? 3 : 0));
      if (i == 0) {
        for (var r = 0; r < 3; r++) {
          list.add(sampleComment(
              id: _nextComment++,
              postId: postId,
              parentId: id,
              rootId: id,
              depth: 1,
              text: 'Yanıt $r',
              authorId: 14,
              authorName: 'Zeynep Demir',
              replyToUser: {'id': 13, 'displayName': 'Mehmet Kaya'}));
        }
      }
    }
    _sync(postId);
  }

  void _sync(int postId) {
    final p = postById(postId);
    if (p == null) return;
    p['commentCount'] = (comments[postId] ?? []).where((c) => c['deleted'] != true).length;
  }

  Map<String, dynamic> _page(List<Map<String, dynamic>> all, Uri uri, {Object? total}) {
    final size = int.tryParse(uri.queryParameters['size'] ?? '') ?? pageSize;
    final cursor = uri.queryParameters['cursor'];
    final page = cursor == null || cursor.isEmpty ? 1 : int.tryParse(cursor.replaceFirst('p', '')) ?? 1;
    final from = (page - 1) * size;
    final slice = emptyFeed || from >= all.length ? <Map<String, dynamic>>[] : all.skip(from).take(size).toList();
    final more = !emptyFeed && from + size < all.length;
    return {'items': slice, 'nextCursor': more ? 'p${page + 1}' : null, if (total != null) 'total': total};
  }

  Map<String, dynamic> _withCounts(Map<String, dynamic> p) => {...p, 'likedByMe': likedIds.contains(p['id'])};

  List<Map<String, dynamic>> _rootsWithPreview(int postId) {
    final all = comments[postId] ?? [];
    final roots = all.where((c) => c['parentId'] == null && !(c['deleted'] == true && c['replyCount'] == 0)).toList();
    return [
      for (final r in roots)
        {
          ...r,
          'previewReplies': all.where((c) => c['parentId'] == r['id']).take(2).toList(),
        }
    ];
  }

  FakeResult? handle(http.Request req, String path) {
    final m = req.method;
    final uri = req.url;
    Object? body() {
      try {
        return req.body.isEmpty ? null : jsonDecode(req.body);
      } catch (_) {
        return null;
      }
    }

    FakeResult notFound() =>
        const FakeResult.json({'code': 'POST_NOT_FOUND', 'message': 'Gönderi bulunamadı.'}, status: 404);

    if (path == '/feed' && m == 'GET') {
      if (failFeed) return const FakeResult.json({'code': 'SERVER_ERROR', 'message': 'Hata'}, status: 500);
      var list = [for (final p in posts) _withCounts(p)];
      if (uri.queryParameters['scope'] == 'popular') {
        list = [...list]..sort((a, b) => (b['likeCount'] as int).compareTo(a['likeCount'] as int));
      }
      return FakeResult.json(_page(list, uri));
    }
    if ((path == '/posts/mine' || RegExp(r'^/users/\d+/posts$').hasMatch(path)) && m == 'GET') {
      final mine = path == '/posts/mine';
      final list = [
        for (final p in posts)
          if (mine ? p['mine'] == true : true) _withCounts(p)
      ];
      return FakeResult.json(_page(list, uri));
    }
    if (path == '/posts/media' && m == 'POST') {
      if (uploadError != null) {
        return FakeResult.json({'code': uploadError, 'message': 'Yüklenemedi.'}, status: uploadError == 'VIDEO_TOO_LARGE' ? 413 : 400);
      }
      var isVideo = false;
      try {
        isVideo = String.fromCharCodes(req.bodyBytes).contains('video/');
      } catch (_) {}
      final id = _nextMedia++;
      final mm = samplePostMedia(id: id, video: isVideo);
      uploadedMedia[id] = mm;
      return FakeResult.json({...mm, 'bytes': 1234}, status: 201);
    }
    final media = RegExp(r'^/posts/media/(\d+)$').firstMatch(path);
    if (media != null && m == 'GET') {
      final id = int.parse(media.group(1)!);
      final isVideo = !uri.queryParameters.containsKey('thumb') &&
          (posts.any((p) => (p['media'] as List).any((x) => x['id'] == id && x['kind'] == 'VIDEO')) ||
              (uploadedMedia[id]?['kind'] == 'VIDEO'));
      return isVideo ? FakeResult.bytes(kFakeMp4, contentType: 'video/mp4') : FakeResult.bytes(kFakePng);
    }
    if (path == '/posts' && m == 'POST') {
      final b = body();
      final map = b is Map ? b : const {};
      final ids = [for (final x in (map['mediaIds'] as List? ?? const [])) (x as num).toInt()];
      final text = map['text'] as String?;
      if ((text == null || text.trim().isEmpty) && ids.isEmpty) {
        return const FakeResult.json({'code': 'POST_EMPTY', 'message': 'Boş gönderi.'}, status: 400);
      }
      final p = samplePost(
          id: _nextPost++,
          text: text,
          media: [for (final id in ids) uploadedMedia[id] ?? samplePostMedia(id: id)],
          likeCount: 0,
          commentCount: 0,
          mine: true,
          authorId: 1,
          authorName: 'Ayşe Yılmaz',
          createdAt: DateTime.now().toUtc().toIso8601String());
      posts.insert(0, p);
      return FakeResult.json(p, status: 201);
    }
    final like = RegExp(r'^/posts/(\d+)/like$').firstMatch(path);
    if (like != null && (m == 'PUT' || m == 'DELETE')) {
      final p = postById(int.parse(like.group(1)!));
      if (p == null) return notFound();
      final id = p['id'] as int;
      final want = m == 'PUT';
      if (want && likedIds.add(id)) p['likeCount'] = (p['likeCount'] as int) + 1;
      if (!want && likedIds.remove(id)) p['likeCount'] = ((p['likeCount'] as int) - 1).clamp(0, 1 << 30);
      return FakeResult.json({'liked': want, 'likeCount': p['likeCount']});
    }
    final likes = RegExp(r'^/posts/(\d+)/likes$').firstMatch(path);
    if (likes != null && m == 'GET') {
      final users = [
        for (var i = 0; i < 5; i++)
          {'id': 20 + i, 'displayName': 'Kullanıcı $i', 'avatarUrl': null, 'likedAt': '2026-10-26T11:0$i:00Z'}
      ];
      return FakeResult.json(_page(users, uri, total: users.length));
    }
    final cl = RegExp(r'^/posts/(\d+)/comments$').firstMatch(path);
    if (cl != null) {
      final pid = int.parse(cl.group(1)!);
      final p = postById(pid);
      if (p == null) return notFound();
      if (m == 'GET') {
        var roots = _rootsWithPreview(pid);
        if (uri.queryParameters['sort'] == 'top') {
          roots = [...roots]..sort((a, b) => (b['replyCount'] as int).compareTo(a['replyCount'] as int));
        } else {
          roots = roots.reversed.toList();
        }
        return FakeResult.json(_page(roots, uri, total: (comments[pid] ?? []).where((c) => c['deleted'] != true).length));
      }
      if (m == 'POST') {
        final b = body() as Map? ?? const {};
        final parentId = (b['parentId'] as num?)?.toInt();
        final list = comments.putIfAbsent(pid, () => []);
        Map<String, dynamic>? parent;
        for (final c in list) {
          if (c['id'] == parentId) parent = c;
        }
        final depth = parent == null ? 0 : (((parent['depth'] as int) + 1).clamp(0, 3));
        final c = sampleComment(
            id: _nextComment++,
            postId: pid,
            parentId: parentId,
            rootId: parent == null ? null : (parent['rootId'] as int),
            depth: depth,
            text: '${b['text'] ?? ''}',
            mine: true,
            authorId: 1,
            authorName: 'Ayşe Yılmaz',
            replyToUser: parent == null ? null : {'id': (parent['author'] as Map)['id'], 'displayName': (parent['author'] as Map)['displayName']},
            createdAt: DateTime.now().toUtc().toIso8601String());
        list.add(c);
        if (parent != null) parent['replyCount'] = (parent['replyCount'] as int) + 1;
        _sync(pid);
        return FakeResult.json(c, status: 201);
      }
    }
    final rep = RegExp(r'^/comments/(\d+)/replies$').firstMatch(path);
    if (rep != null && m == 'GET') {
      final cid = int.parse(rep.group(1)!);
      final out = <Map<String, dynamic>>[];
      for (final l in comments.values) {
        out.addAll(l.where((c) => c['parentId'] == cid));
      }
      return FakeResult.json(_page(out, uri));
    }
    final cm = RegExp(r'^/comments/(\d+)$').firstMatch(path);
    if (cm != null && (m == 'PATCH' || m == 'DELETE')) {
      final cid = int.parse(cm.group(1)!);
      for (final e in comments.entries) {
        final i = e.value.indexWhere((c) => c['id'] == cid);
        if (i < 0) continue;
        final c = e.value[i];
        if (m == 'PATCH') {
          final b = body() as Map? ?? const {};
          c['text'] = '${b['text'] ?? ''}';
          c['editedAt'] = DateTime.now().toUtc().toIso8601String();
          return FakeResult.json(c);
        }
        if ((c['replyCount'] as int) > 0) {
          c['deleted'] = true;
          c['text'] = null;
        } else {
          e.value.removeAt(i);
          final pid = c['parentId'];
          for (final x in e.value) {
            if (x['id'] == pid) x['replyCount'] = ((x['replyCount'] as int) - 1).clamp(0, 1 << 30);
          }
        }
        _sync(e.key);
        return const FakeResult.json(null, status: 204);
      }
      return const FakeResult.json({'code': 'COMMENT_NOT_FOUND', 'message': 'Yorum yok.'}, status: 404);
    }
    final one = RegExp(r'^/posts/(\d+)$').firstMatch(path);
    if (one != null) {
      final p = postById(int.parse(one.group(1)!));
      if (p == null) return notFound();
      if (m == 'GET') return FakeResult.json(_withCounts(p));
      if (m == 'PATCH') {
        final b = body() as Map? ?? const {};
        p['text'] = b['text'];
        p['editedAt'] = DateTime.now().toUtc().toIso8601String();
        return FakeResult.json(_withCounts(p));
      }
      if (m == 'DELETE') {
        posts.remove(p);
        return const FakeResult.json(null, status: 204);
      }
    }
    return null;
  }
}

/// Gönderi uçlarını durumlu sahte olarak kurar (bkz. [FakePosts]). Dönen nesneyle test verisi değiştirilir.
/// Not: `/feed?scope=latest|popular` imleci `p2`, `p3` ... biçimindedir.
FakePosts fakePosts(FakeBackend b, {int count = 12, int pageSize = 10, bool withMedia = true, bool empty = false}) {
  final f = FakePosts(b, count: count, pageSize: pageSize, withMedia: withMedia)..emptyFeed = empty;
  b.handlers.add(f.handle);
  return f;
}
