import 'dart:convert';
import 'dart:io';

import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme.dart';
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

  /// Tüm istekler ağ hatası verir (true iken).
  bool offline = false;

  /// Yol için JSON yanıtı (varsayılanı ezer).
  void on(String path, Object? json, {int status = 200, Map<String, String>? headers}) {
    _routes[path] = _Reply(status, json, headers ?? const {});
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
    if (req.body.isNotEmpty) {
      try {
        bodies['${req.method} $path'] = jsonDecode(req.body);
      } catch (_) {}
    }
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (offline) throw http.ClientException('offline');
    final r = _lookup(req.method, path, full);
    if (r.status == -1) throw http.ClientException('network down');
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

class _Reply {
  _Reply(this.status, this.json, this.headers);
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
  final s = Session(ApiClient(client: b.client, retryDelay: Duration.zero));
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
}
