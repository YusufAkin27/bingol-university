import 'dart:async';
import 'dart:typed_data';

import 'package:bu_kampus/core/platform/secure_view.dart';
import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:bu_kampus/features/chat/media_pick.dart';
import 'package:bu_kampus/features/chat/media_preview_page.dart';
import 'package:bu_kampus/features/chat/view_once_viewer.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsFlag;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';
import 'support/fake_media.dart';

// Medya gönderme önizlemesi (tek gönderimlik SİMGE düğmesi + genişleyen açıklama alanı), tek gönderimlik açıklamanın
// balonda gizlenip görüntüleyicide gösterilmesi ve iOS ekran koruması kanalı.

const _secret = 'Gizli açıklama metni';

final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, //
  0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0xF8, 0xFF, 0xFF, 0x3F, 0x00, 0x05, 0xFE, 0x02, 0xFE, 0xA7, 0x35, 0x81, 0x84, 0x00, 0x00, 0x00,
  0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

Map<String, dynamic> _msg(int id, int sender, String text, {Map<String, dynamic>? extra}) => {
      'id': id,
      'conversationId': 1,
      'senderId': sender,
      'text': text,
      'createdAt': DateTime.now().subtract(Duration(minutes: 600 - id)).toUtc().toIso8601String(),
      ...?extra,
    };

Map<String, dynamic> _once(int id, int sender, {bool viewed = false, bool withUrl = true}) => _msg(id, sender, _secret, extra: {
      'attachments': [
        {
          'id': 50 + id,
          'kind': 'IMAGE',
          'viewOnce': true,
          'viewed': viewed,
          'thumbUrl': null,
          'url': withUrl ? '/api/conversations/1/media/${50 + id}' : null,
        },
      ],
    });

FakeBackend _backend(List<Map<String, dynamic>> msgs) => FakeBackend()
  ..on('/conversations/1/messages?size=30', {'items': msgs, 'nextCursor': null})
  ..on('/conversations/1', {
    'conversation': {'id': 1},
    'members': [
      {'userId': 1, 'displayName': 'Ayşe Yılmaz'},
      {'userId': 11, 'displayName': 'Ali Veli'},
    ],
  })
  ..on('/users/11/presence', {'online': true})
  ..on('/messages/reactions', {'emojis': <String>[]});

ChatDetailPage _detail(Session s) => ChatDetailPage(
      session: s,
      connectRealtime: false,
      mediaLibrary: FakeMediaLibrary.photos(3),
      ensureAccess: (c, p, {rationale}) async => true,
      conversation: const {
        'id': 1,
        'type': 'DIRECT',
        'title': 'Ali Veli',
        'peer': {'id': 11, 'displayName': 'Ali Veli'},
      },
    );

void _ok(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('$e');
}

Future<void> _openPreview(WidgetTester tester, List<dynamic> picks,
    {Size size = kPhoneMedium, Brightness b = Brightness.light, TextDirection? dir, double scale = 1}) async {
  useScreen(tester, size);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  Widget page = MediaPreviewPage(picks: List.of(picks.cast()));
  if (dir != null) page = Directionality(textDirection: dir, child: page);
  await tester.pumpWidget(buildApp(page, brightness: b, size: size));
  await settle(tester, const Duration(milliseconds: 500));
}

/// Yerel kanal sahtesi: çağrıları kaydeder, `enable` için verilen durumu döner.
class _FakeNative {
  _FakeNative({this.captured = false, this.secureLayer = true, this.secureImage = false, bool missing = false}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (missing) throw MissingPluginException();
      if (call.method == 'enable') {
        return {'secureLayer': secureLayer, 'captured': captured, 'secureImage': secureImage};
      }
      return null;
    });
  }

  static const name = 'test/bu_secure';
  final channel = const MethodChannel(name);
  final calls = <String>[];
  bool captured;
  bool secureLayer;
  bool secureImage;

  /// [layerTrick]: null = derleme varsayılanı (KAPALI); true = BU_SECURE_LAYER=true derlemesi.
  /// Yerel güvenli fotoğraf görünümü testte işaretli bir kutuyla temsil edilir (UiKitView yalnız iOS'ta çalışır).
  ChatSecureView view({bool ios = true, bool? layerTrick}) => ChatSecureView(
      channel: channel,
      isIOS: ios,
      layerTrick: layerTrick,
      imageBuilder: (b) => SizedBox(key: const ValueKey('secureNativeImage'), width: 50, height: 50, child: Text('${b.length}')));

  /// Yerelden Dart'a olay (UIKit bildirimi karşılığı).
  Future<void> emit(String method, [Object? args]) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        name, const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)), (_) {});
  }

  void dispose() =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
}

void main() {
  setUpAll(loadTestFonts);

  group('Onizleme: tek gonderimlik simge dugmesi + genis aciklama alani', () {
    testWidgets('yazi yok, tek simge; aciklama alani simgenin hemen yanina kadar uzar (8 dp)', (tester) async {
      await _openPreview(tester, [fakePhotoPick('a'), fakePhotoPick('b')]);
      expect(find.text('Tek gönderimlik'), findsNothing); // eski uzun hap yazisi yok
      expect(find.byTooltip('Tek gönderimlik'), findsOneWidget);
      final once = tester.getRect(find.byKey(const ValueKey('onceButton_0')));
      expect(once.width, greaterThanOrEqualTo(44));
      expect(once.height, greaterThanOrEqualTo(44));
      // En sağa yaklaşır: sağ kenar boşluğu 16 dp.
      expect(390 - once.right, closeTo(16, .5));
      final box = tester.getRect(find
          .ancestor(of: find.byKey(const ValueKey('previewCaption')), matching: find.byType(Container))
          .first);
      expect(once.left - box.right, closeTo(8, .5)); // alan ile simge arasi yalniz 8 dp
      expect(box.left, closeTo(16, .5));
      expect(box.height, greaterThanOrEqualTo(48));
      _ok(tester);
    });

    testWidgets('videoda simge yok, aciklama alani tam genislik', (tester) async {
      await _openPreview(tester, [fakeVideoPick('v')]);
      expect(find.byKey(const ValueKey('onceButton_0')), findsNothing);
      final box = tester.getRect(find
          .ancestor(of: find.byKey(const ValueKey('previewCaption')), matching: find.byType(Container))
          .first);
      expect(box.right, closeTo(390 - 16, .5));
      _ok(tester);
    });

    testWidgets('secili/kapali durum: anlamsal etiket + toggled; simge isaretlenince plan once tasir', (tester) async {
      final handle = tester.ensureSemantics();
      Object? res;
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(
        Builder(
            builder: (c) => Scaffold(
                    body: Center(
                  child: ElevatedButton(
                    onPressed: () async => res = await Navigator.push<Object?>(
                        c, MaterialPageRoute(builder: (_) => MediaPreviewPage(picks: [fakePhotoPick('a')]))),
                    child: const Text('aç'),
                  ),
                ))),
        size: kPhoneMedium,
      ));
      await tester.tap(find.text('aç'));
      await settle(tester, const Duration(milliseconds: 500));
      final node = tester.getSemantics(find.byKey(const ValueKey('onceButton_0')));
      expect(node.label, 'Tek gönderimlik');
      expect(node.hasFlag(SemanticsFlag.hasToggledState), isTrue);
      expect(node.hasFlag(SemanticsFlag.isToggled), isFalse);
      await tester.tap(find.byKey(const ValueKey('onceButton_0')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getSemantics(find.byKey(const ValueKey('onceButton_0'))).hasFlag(SemanticsFlag.isToggled), isTrue);
      await tester.enterText(find.byKey(const ValueKey('previewCaption')), 'Merhaba');
      await tester.tap(find.byKey(const ValueKey('previewSend')));
      await settle(tester, const Duration(milliseconds: 500));
      final plan = res as MediaSendPlan;
      expect(plan.items.single.once, isTrue);
      expect(plan.caption, 'Merhaba');
      handle.dispose();
      _ok(tester);
    });

    for (final size in [kPhoneSmall, kPhoneMedium]) {
      for (final b in [Brightness.light, Brightness.dark]) {
        testWidgets('tasma yok ${size.width.toInt()} dp x1.3 $b, uzun metin + klavye acik', (tester) async {
          await _openPreview(tester, [fakePhotoPick('a'), fakePhotoPick('b'), fakePhotoPick('c')],
              size: size, b: b, scale: 1.3);
          await tester.enterText(find.byKey(const ValueKey('previewCaption')), 'Çok uzun bir açıklama metni ' * 6);
          await tester.pump(const Duration(milliseconds: 200));
          _ok(tester);
          // Klavye: alt kenardan 300 dp.
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          addTearDown(tester.view.resetViewInsets);
          await tester.pump(const Duration(milliseconds: 300));
          _ok(tester);
          expect(find.byKey(const ValueKey('onceButton_0')), findsOneWidget);
          final once = tester.getRect(find.byKey(const ValueKey('onceButton_0')));
          expect(once.right, lessThanOrEqualTo(size.width));
          expect(once.bottom, lessThanOrEqualTo(size.height - 300 + 1));
        });
      }
    }

    testWidgets('RTL: simge sol uca, alan sagdan sola dolar', (tester) async {
      await _openPreview(tester, [fakePhotoPick('a')], dir: TextDirection.rtl);
      final once = tester.getRect(find.byKey(const ValueKey('onceButton_0')));
      expect(once.left, closeTo(16, .5));
      final box = tester.getRect(find
          .ancestor(of: find.byKey(const ValueKey('previewCaption')), matching: find.byType(Container))
          .first);
      expect(box.left - once.right, closeTo(8, .5));
      _ok(tester);
    });
  });

  group('Tek gonderimlik aciklama: balonda/listede yok', () {
    testWidgets('alici ve gonderen kartinda aciklama cizilmez; normal medyada cizilir', (tester) async {
      final be = _backend([
        _msg(9, 11, 'Normal açıklama', extra: {
          'attachments': [
            {'id': 1, 'kind': 'IMAGE', 'url': '/a1', 'thumbUrl': '/a1', 'width': 800, 'height': 600}
          ]
        }),
        _once(8, 1),
        _once(7, 11),
        _once(6, 11, viewed: true, withUrl: false),
      ]);
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(_detail(makeSession(be)), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.text(_secret), findsNothing);
      expect(find.text('Normal açıklama'), findsOneWidget);
      expect(find.text('Fotoğraf · Açmak için dokun'), findsOneWidget);
      expect(find.text('Fotoğraf · Gönderildi'), findsOneWidget);
      expect(find.text('Fotoğraf · Açıldı'), findsOneWidget);
      _ok(tester);
      await unmount(tester);
    });

    testWidgets('mesaj menusunde tek gonderimlikte kopyala/duzenle yok; arama aciklamayi bulmaz', (tester) async {
      final be = _backend([_once(8, 1)]);
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(_detail(makeSession(be)), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 700));
      await tester.longPress(find.text('Fotoğraf · Gönderildi'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Kopyala'), findsNothing);
      expect(find.text('Düzenle'), findsNothing);
      _ok(tester);
      await unmount(tester);
    });

    testWidgets('alici acinca aciklama fotografin altinda gorunur', (tester) async {
      final be = _backend([_once(7, 11)])..onBytes('/conversations/1/media/57', _png, once: true);
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(_detail(makeSession(be)), size: kPhoneMedium));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.text(_secret), findsNothing);
      await tester.tap(find.byKey(const ValueKey('viewOnceCard')));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.text(_secret), findsOneWidget);
      expect(find.byKey(const ValueKey('onceCaption')), findsOneWidget);
      await tester.tap(find.byTooltip('Kapat'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text(_secret), findsNothing); // kapaninca da balonda yok
      _ok(tester);
      await unmount(tester);
    });

    testWidgets('goruntuleyici: uzun aciklama kaydirilabilir, tasma yok (320 dp x1.3)', (tester) async {
      final be = FakeBackend()..onBytes('/conversations/1/media/50', _png, once: true);
      final s = makeSession(be);
      useScreen(tester, kPhoneSmall);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final long = List.filled(40, 'uzun açıklama').join(' ');
      await tester.pumpWidget(buildApp(
          ViewOnceViewer(api: s.api, conversationId: 1, attachmentId: 50, caption: long, secureView: ChatSecureView(isIOS: false)),
          size: kPhoneSmall));
      await settle(tester, const Duration(milliseconds: 700));
      expect(find.byKey(const ValueKey('onceCaption')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('onceCaption')), matching: find.byType(SingleChildScrollView)),
          findsOneWidget);
      _ok(tester);
      await unmount(tester);
    });
  });

  group('Ekran korumasi (iOS kanal sarmalayicisi + goruntuleyici)', () {
    late _FakeNative native;
    tearDown(() => native.dispose());

    Future<FakeBackend> open(WidgetTester tester, ChatSecureView view,
        {String? caption, VoidCallback? onConsumed, Size size = kPhoneMedium, Brightness b = Brightness.light}) async {
      final be = FakeBackend()..onBytes('/conversations/1/media/50', _png, once: true);
      useScreen(tester, size);
      await tester.pumpWidget(buildApp(
          ViewOnceViewer(
              api: makeSession(be).api,
              conversationId: 1,
              attachmentId: 50,
              caption: caption,
              senderName: 'Ali Veli',
              onConsumed: onConsumed,
              secureView: view),
          brightness: b,
          size: size));
      await settle(tester, const Duration(milliseconds: 700));
      return be;
    }

    testWidgets('acilinca enable, kapaninca disable (iOS: 600 ms ertelenir, ekran goruntusu islemi bitsin)', (tester) async {
      native = _FakeNative();
      await open(tester, native.view());
      expect(native.calls, ['enable']);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 300));
      expect(native.calls, ['enable']); // henuz sokulmedi
      await tester.pump(const Duration(milliseconds: 400));
      expect(native.calls, ['enable', 'disable']);
    });

    testWidgets('iOS yerel guvenli gorunum: foto Flutter Image ile CIZILMEZ, yerel gorunume verilir', (tester) async {
      native = _FakeNative(secureLayer: false, secureImage: true);
      var consumed = 0;
      final be = await open(tester, native.view(), onConsumed: () => consumed++);
      expect(be.count('GET /conversations/1/media/50'), 1);
      expect(consumed, 1);
      expect(find.byKey(const ValueKey('onceUnsupported')), findsNothing);
      // Ekran goruntusune acik Flutter Image YOK; piksel yalniz yerel guvenli gorunumde.
      expect(find.byType(Image), findsNothing);
      expect(find.byKey(const ValueKey('secureNativeImage')), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.byKey(const ValueKey('onceCover')), findsOneWidget);
      expect(find.text('Bu fotoğraf yalnızca bir kez görüntülenebilir ve korunmaktadır.'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await unmount(tester);
    });

    testWidgets('iOS guvenli gorunum kurulamadi (ne katman ne gorunum): bayt ISTENMEZ, hak tuketilmez', (tester) async {
      native = _FakeNative(secureLayer: false, secureImage: false);
      var consumed = 0;
      final be = await open(tester, native.view(), onConsumed: () => consumed++);
      expect(be.count('GET /conversations/1/media/50'), 0);
      expect(consumed, 0);
      expect(find.byKey(const ValueKey('onceUnsupported')), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(find.byKey(const ValueKey('secureNativeImage')), findsNothing);
      await unmount(tester);
    });

    testWidgets('bayrak ACIK + katman kurulamadi: bayt ISTENMEZ, hak tuketilmez, guvenli acilamiyor karti', (tester) async {
      native = _FakeNative(secureLayer: false);
      var consumed = 0;
      final be = await open(tester, native.view(layerTrick: true), onConsumed: () => consumed++);
      expect(be.count('GET /conversations/1/media/50'), 0);
      expect(consumed, 0); // mesaj karti "acilmamis" kalir
      expect(find.byKey(const ValueKey('onceUnsupported')), findsOneWidget);
      expect(find.text('Bu cihazda güvenli açılamıyor'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(find.text('Ali Veli'), findsOneWidget);
      // Kapat dugmesi calisir.
      expect(find.byTooltip('Kapat'), findsOneWidget);
      _ok(tester);
      await unmount(tester);
    });

    testWidgets('bayrak ACIK + yerel kopru yok (MissingPlugin): acilis engelli', (tester) async {
      native = _FakeNative(missing: true);
      final be = await open(tester, native.view(layerTrick: true));
      expect(be.count('GET /conversations/1/media/50'), 0);
      expect(find.byKey(const ValueKey('onceUnsupported')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('bayrak ACIK + katman kuruldu: normal acilis, enable layerTrick=true, korumali ortu metni', (tester) async {
      native = _FakeNative(secureLayer: true);
      final be = await open(tester, native.view(layerTrick: true));
      expect(be.count('GET /conversations/1/media/50'), 1);
      expect(find.byKey(const ValueKey('onceUnsupported')), findsNothing);
      expect(find.byType(Image), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.text('Ekran yakalama koruması'), findsOneWidget);
      expect(find.text('Bu fotoğraf yalnızca bir kez görüntülenebilir ve korunmaktadır.'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await unmount(tester);
    });

    testWidgets('onLayerRevoked: goruntu HEMEN duser, guvenli acilamiyor karti', (tester) async {
      native = _FakeNative(secureLayer: true);
      await open(tester, native.view(layerTrick: true), caption: _secret);
      expect(find.byType(Image), findsOneWidget);
      await native.emit('onLayerRevoked');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(Image), findsNothing);
      expect(find.byKey(const ValueKey('onceCaption')), findsNothing);
      expect(find.byKey(const ValueKey('onceUnsupported')), findsOneWidget);
      expect(find.text('Ekran yakalama koruması devre dışı kaldığı için fotoğraf kapatıldı.'), findsOneWidget);
      _ok(tester);
      await unmount(tester);
    });

    for (final size in [kPhoneSmall, kPhoneMedium]) {
      for (final b in [Brightness.light, Brightness.dark]) {
        testWidgets('guvenli acilamiyor karti: tasma yok ${size.width.toInt()} dp x1.3 $b', (tester) async {
          native = _FakeNative(secureLayer: false);
          tester.platformDispatcher.textScaleFactorTestValue = 1.3;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await open(tester, native.view(layerTrick: true), size: size, b: b);
          expect(find.byKey(const ValueKey('onceUnsupported')), findsOneWidget);
          _ok(tester);
          await unmount(tester);
        });
      }
    }

    testWidgets('Android: kanal cagrisi yok (FLAG_SECURE zaten pencere genelinde)', (tester) async {
      native = _FakeNative();
      final be = await open(tester, native.view(ios: false));
      expect(native.calls, isEmpty);
      expect(be.count('GET /conversations/1/media/50'), 1);
      await unmount(tester);
    });

    testWidgets('yerel kopru yoksa (MissingPlugin) iOS: FAIL-CLOSED, foto istenmez', (tester) async {
      native = _FakeNative(missing: true);
      final be = await open(tester, native.view());
      expect(be.count('GET /conversations/1/media/50'), 0);
      expect(find.byKey(const ValueKey('onceUnsupported')), findsOneWidget);
      _ok(tester);
      await unmount(tester);
    });

    testWidgets('ekran kaydi sirasinda acilirsa icerik istenmez; kayit bitince yuklenir', (tester) async {
      native = _FakeNative(captured: true);
      final be = await open(tester, native.view());
      expect(find.text('Ekran kaydı sırasında bu içerik görüntülenemez.'), findsOneWidget);
      expect(be.count('GET /conversations/1/media/50'), 0); // tek gosterim tuketilmedi
      await native.emit('onCaptured', {'captured': false});
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.text('Ekran kaydı sırasında bu içerik görüntülenemez.'), findsNothing);
      expect(be.count('GET /conversations/1/media/50'), 1);
      await unmount(tester);
    });

    testWidgets('gorunturken kayit baslarsa opak ortu cikar, bitince kalkar', (tester) async {
      native = _FakeNative();
      await open(tester, native.view());
      expect(find.byKey(const ValueKey('onceCover')), findsNothing);
      await native.emit('onCaptured', {'captured': true});
      await tester.pump();
      expect(find.byKey(const ValueKey('onceCover')), findsOneWidget);
      expect(find.text('Ekran kaydı sırasında bu içerik görüntülenemez.'), findsOneWidget);
      await native.emit('onCaptured', {'captured': false});
      await tester.pump();
      expect(find.byKey(const ValueKey('onceCover')), findsNothing);
      await unmount(tester);
    });

    testWidgets('ekran goruntusu algilanirsa goruntu kapanir ve uyari cikar', (tester) async {
      native = _FakeNative();
      await open(tester, native.view(), caption: _secret);
      expect(find.byKey(const ValueKey('onceCaption')), findsOneWidget);
      await native.emit('onScreenshot');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('onceScreenshot')), findsOneWidget);
      expect(find.text('Ekran görüntüsü algılandı. Görüntü kapatıldı.'), findsOneWidget);
      expect(find.byKey(const ValueKey('onceCaption')), findsNothing);
      expect(find.byType(Image), findsNothing);
      await unmount(tester);
    });

    testWidgets('uygulama etkin degilken (uygulama degistirici) ortu, donunce kalkar', (tester) async {
      native = _FakeNative();
      await open(tester, native.view());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.byKey(const ValueKey('onceCover')), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.byKey(const ValueKey('onceCover')), findsNothing);
      await unmount(tester);
    });
  });
}
