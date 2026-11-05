import 'package:bu_kampus/core/push/push_privacy.dart';
import 'package:bu_kampus/features/profile/notification_prefs_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';
import 'support/fake_notif_prefs.dart';

/// Bildirim ayarları (P-DT): sosyal alt türler, akademik, önizleme, sistem ayarı satırı, eski sunucu uyumu.
void main() {
  setUpAll(loadTestFonts);

  const tall = Size(390, 2600);

  Future<void> open(WidgetTester tester, FakeBackend b, {Size size = tall, Future<bool> Function()? openSystem, Brightness br = Brightness.light, bool rtl = false}) async {
    useScreen(tester, size);
    Widget app = buildApp(NotificationPrefsPage(session: makeSession(b), openSystemSettings: openSystem), size: size, brightness: br);
    if (rtl) app = Directionality(textDirection: TextDirection.rtl, child: app);
    await tester.pumpWidget(app);
    await settle(tester);
  }

  /// Satırdaki (başlık metni) anahtar.
  Switch sw(WidgetTester tester, String label) {
    final row = find.ancestor(of: find.text(label), matching: find.byType(Row)).first;
    return tester.widget<Switch>(find.descendant(of: row, matching: find.byType(Switch)));
  }

  Finder swFinder(String label) {
    final row = find.ancestor(of: find.text(label), matching: find.byType(Row)).first;
    return find.descendant(of: row, matching: find.byType(Switch));
  }

  const social = ['Gönderi beğenileri', 'Gönderi yorumları', 'Yorum yanıtları', 'Etiketlenmeler', 'Yeni takipçiler', 'Takip istekleri', 'Kabul edilen istekler'];

  group('sunucu alt türlerinden satırlar', () {
    testWidgets('sosyal alt türler, akademik, önizleme ve sistem ayarı satırı görünür', (tester) async {
      final b = FakeBackend();
      FakeNotifPrefs(b);
      await open(tester, b);
      for (final s in social) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
      expect(find.text('Akademik duyurular'), findsOneWidget);
      expect(find.text('Önizleme'), findsOneWidget);
      expect(find.text('Mesaj içeriğini gizle'), findsOneWidget);
      expect(find.text('Sistem bildirim ayarları'), findsOneWidget);
      expect(find.textContaining('her zaman gelir'), findsOneWidget); // güvenlik bildirimleri tercihten bağımsız notu
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('sunucu bir alt türü göndermediyse o satır çizilmez (bilinmeyen anahtar gönderilmez)', (tester) async {
      final b = FakeBackend();
      FakeNotifPrefs(b, subtypes: {...FakeNotifPrefs.defaultSubtypes()}..remove('FOLLOW_REQUEST'));
      await open(tester, b);
      expect(find.text('Takip istekleri'), findsNothing);
      expect(find.text('Yeni takipçiler'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('sosyal alt tür anahtarları', () {
    testWidgets('dokunuş iyimser uygulanır; PUT yalnız o alt türü gönderir; sunucu durumu korunur', (tester) async {
      final b = FakeBackend(delay: const Duration(milliseconds: 400));
      final p = FakeNotifPrefs(b);
      await open(tester, b);
      expect(sw(tester, 'Gönderi beğenileri').value, isTrue);
      await tester.tap(swFinder('Gönderi beğenileri'));
      await tester.pump(const Duration(milliseconds: 60));
      expect(sw(tester, 'Gönderi beğenileri').value, isFalse); // sunucu yanıtı gelmeden anında
      await settle(tester, const Duration(seconds: 2));
      expect(p.puts, [
        {
          'subtypes': {'POST_LIKE': false}
        }
      ]);
      expect(sw(tester, 'Gönderi beğenileri').value, isFalse);
      expect(sw(tester, 'Gönderi yorumları').value, isTrue); // diğerleri etkilenmez
      await unmount(tester);
    });

    testWidgets('satır metnine dokunmak da anahtarı çevirir', (tester) async {
      final b = FakeBackend();
      final p = FakeNotifPrefs(b);
      await open(tester, b);
      await tester.tap(find.text('Etiketlenmeler'));
      await settle(tester);
      expect(p.puts.single, {
        'subtypes': {'POST_MENTION': false}
      });
      await unmount(tester);
    });

    testWidgets('kayıt hatasında anahtar eski değere döner ve hata bildirilir', (tester) async {
      final b = FakeBackend();
      final p = FakeNotifPrefs(b)..failPut = true;
      await open(tester, b);
      await tester.tap(swFinder('Yorum yanıtları'));
      await settle(tester);
      expect(p.puts, hasLength(1));
      expect(sw(tester, 'Yorum yanıtları').value, isTrue); // geri alındı
      expect(find.byType(SnackBar), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('hızlı ardışık dokunuşlar sırayla gider; son durum ikisini de içerir', (tester) async {
      final b = FakeBackend(delay: const Duration(milliseconds: 300));
      final p = FakeNotifPrefs(b);
      await open(tester, b);
      await tester.tap(swFinder('Gönderi beğenileri'));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.tap(swFinder('Gönderi yorumları'));
      await settle(tester, const Duration(seconds: 3));
      expect(p.puts, hasLength(2));
      expect(sw(tester, 'Gönderi beğenileri').value, isFalse);
      expect(sw(tester, 'Gönderi yorumları').value, isFalse);
      expect(p.state['subtypes']['POST_LIKE'], isFalse);
      expect(p.state['subtypes']['POST_COMMENT'], isFalse);
      await unmount(tester);
    });

    testWidgets('Kulüpler (communities) kapalıyken sosyal satırlar kapalı görünür', (tester) async {
      final b = FakeBackend();
      FakeNotifPrefs(b, communities: false);
      await open(tester, b);
      for (final s in social) {
        expect(sw(tester, s).value, isFalse, reason: s);
      }
      await unmount(tester);
    });

    testWidgets('communities kapalıyken sosyal tür açmak: communities açılır, saklı diğer alt türler aynı istekte kapatılır', (tester) async {
      final b = FakeBackend();
      final p = FakeNotifPrefs(b, communities: false, subtypes: {...FakeNotifPrefs.defaultSubtypes(), 'POST_COMMENT': false});
      await open(tester, b);
      await tester.tap(swFinder('Gönderi beğenileri'));
      await settle(tester);
      final body = p.puts.single;
      expect(body['communities'], isTrue);
      final subs = (body['subtypes'] as Map).cast<String, dynamic>();
      expect(subs['POST_LIKE'], isTrue);
      // Fiilen kapalı olanlar (kulüp + diğer sosyal) bu açışla açılmasın.
      for (final k in ['COMMUNITY_POST', 'COMMUNITY_ROLE', 'COMMUNITY_JOIN', 'COMMENT_REPLY', 'POST_MENTION', 'USER_FOLLOW', 'FOLLOW_REQUEST', 'FOLLOW_ACCEPTED']) {
        expect(subs[k], isFalse, reason: k);
      }
      expect(subs.containsKey('POST_COMMENT'), isFalse); // zaten kapalıydı
      expect(sw(tester, 'Gönderi beğenileri').value, isTrue);
      expect(sw(tester, 'Yorum yanıtları').value, isFalse);
      await unmount(tester);
    });
  });

  group('akademik duyurular', () {
    testWidgets('anahtar PUT academicAnnouncements gönderir', (tester) async {
      final b = FakeBackend();
      final p = FakeNotifPrefs(b);
      await open(tester, b);
      await tester.tap(swFinder('Akademik duyurular'));
      await settle(tester);
      expect(p.puts.single, {'academicAnnouncements': false});
      await unmount(tester);
    });

    testWidgets('Duyurular kapalıyken akademik satır pasif ve notlu', (tester) async {
      final b = FakeBackend();
      final p = FakeNotifPrefs(b, announcements: false);
      await open(tester, b);
      expect(sw(tester, 'Akademik duyurular').onChanged, isNull);
      expect(find.text('Duyurular kapalıysa akademik bildirimler gelmez'), findsOneWidget);
      await tester.tap(find.text('Akademik duyurular'));
      await settle(tester);
      expect(p.puts, isEmpty);
      await unmount(tester);
    });

    testWidgets('sunucu alanı göndermediyse satır yok', (tester) async {
      final b = FakeBackend();
      final p = FakeNotifPrefs(b);
      p.state.remove('academicAnnouncements');
      await open(tester, b);
      expect(find.text('Akademik duyurular'), findsNothing);
      await unmount(tester);
    });
  });

  group('önizleme (mesaj içeriğini gizle)', () {
    testWidgets('anahtar PUT hideMessagePreview gönderir ve değeri yerel koda iletir', (tester) async {
      final sent = <bool>[];
      final old = PushPrivacy.sink;
      PushPrivacy.sink = (v) async => sent.add(v);
      addTearDown(() => PushPrivacy.sink = old);
      final b = FakeBackend();
      final p = FakeNotifPrefs(b);
      await open(tester, b);
      expect(sent, [false]); // yüklemede sunucu değeri yerel koda taşınır
      expect(sw(tester, 'Mesaj içeriğini gizle').value, isFalse);
      await tester.tap(swFinder('Mesaj içeriğini gizle'));
      await settle(tester);
      expect(p.puts.single, {'hideMessagePreview': true});
      expect(sw(tester, 'Mesaj içeriğini gizle').value, isTrue);
      expect(sent.last, isTrue);
      await unmount(tester);
    });

    testWidgets('kayıt hatasında geri alınır ve yerel koda yanlış değer gitmez', (tester) async {
      final sent = <bool>[];
      final old = PushPrivacy.sink;
      PushPrivacy.sink = (v) async => sent.add(v);
      addTearDown(() => PushPrivacy.sink = old);
      final b = FakeBackend();
      final p = FakeNotifPrefs(b);
      await open(tester, b);
      p.failPut = true;
      await tester.tap(swFinder('Mesaj içeriğini gizle'));
      await settle(tester);
      expect(sw(tester, 'Mesaj içeriğini gizle').value, isFalse);
      expect(sent, [false]);
      await unmount(tester);
    });

    testWidgets('eski sunucuda alan yoksa satır çizilmez, çökmez', (tester) async {
      final b = FakeBackend();
      FakeNotifPrefs(b, withHidePreview: false);
      await open(tester, b);
      expect(find.text('Mesaj içeriğini gizle'), findsNothing);
      expect(find.text('Önizleme'), findsNothing);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });

  testWidgets('eski sunucu (yalnız 5 bayrak): çökmez; sosyal/akademik/sessiz saat/önizleme yok, sistem satırı var', (tester) async {
    final b = FakeBackend();
    FakeNotifPrefs(b, legacy: true);
    await open(tester, b);
    expect(find.text('Haberler'), findsOneWidget);
    expect(find.text('Gönderi beğenileri'), findsNothing);
    expect(find.text('Akademik duyurular'), findsNothing);
    expect(find.text('Sessiz saatler'), findsNothing);
    expect(find.text('Mesaj içeriğini gizle'), findsNothing);
    expect(find.text('Sistem bildirim ayarları'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('"Sistem bildirim ayarları" satırı sistem ayarını açar', (tester) async {
    var opened = 0;
    final b = FakeBackend();
    FakeNotifPrefs(b);
    await open(tester, b, openSystem: () async {
      opened++;
      return true;
    });
    await tester.tap(find.text('Sistem bildirim ayarları'));
    await settle(tester);
    expect(opened, 1);
    await unmount(tester);
  });

  group('yükleme durumları', () {
    testWidgets('yükleme hatası: yeniden dene satırı; dokununca yüklenir', (tester) async {
      final b = FakeBackend();
      final p = FakeNotifPrefs(b)..failGet = true;
      await open(tester, b);
      expect(find.text('Yüklenemedi'), findsOneWidget);
      p.failGet = false;
      await tester.tap(find.text('Yüklenemedi'));
      await settle(tester);
      expect(find.text('Yüklenemedi'), findsNothing);
      expect(find.text('Gönderi beğenileri'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('çevrimdışı: hata satırı çıkar, çökmez', (tester) async {
      final b = FakeBackend()..offline = true;
      FakeNotifPrefs(b);
      await open(tester, b);
      expect(find.text('Yüklenemedi'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });

  group('sessiz saatler', () {
    testWidgets('aç/kapat anahtarı ve saat seçici kısmi gövde gönderir', (tester) async {
      final b = FakeBackend();
      final p = FakeNotifPrefs(b);
      await open(tester, b);
      await tester.tap(find.text('Sessiz saatler'));
      await settle(tester);
      await tester.tap(find.text('Sessiz saatleri aç'));
      await settle(tester);
      expect(p.puts.last, {
        'quietHours': {'enabled': true}
      });
      expect(p.state['quietHours']['enabled'], isTrue);
      await tester.tap(find.text('Başlangıç'));
      await settle(tester);
      expect(find.text('Saat seçin'), findsOneWidget);
      await tester.tap(find.text('Seç'));
      await settle(tester);
      expect(p.puts.last, {
        'quietHours': {'enabled': true, 'start': '22:00'}
      });
      await unmount(tester);
    });

    testWidgets('kayıt hatasında sessiz saat anahtarı geri alınır', (tester) async {
      final b = FakeBackend();
      final p = FakeNotifPrefs(b);
      await open(tester, b);
      await tester.tap(find.text('Sessiz saatler'));
      await settle(tester);
      p.failPut = true;
      await tester.tap(find.text('Sessiz saatleri aç'));
      await settle(tester);
      expect(sw(tester, 'Sessiz saatleri aç').value, isFalse);
      await unmount(tester);
    });
  });

  for (final br in Brightness.values) {
    for (final rtl in [false, true]) {
      testWidgets('320 dp ${br.name}${rtl ? ' rtl' : ''}: tüm bölümler taşmadan uçtan uca kaydırılır', (tester) async {
        final b = FakeBackend();
        FakeNotifPrefs(b);
        await open(tester, b, size: kPhoneSmall, br: br, rtl: rtl);
        for (final label in [...social, 'Akademik duyurular', 'Mesaj içeriğini gizle', 'Sistem bildirim ayarları']) {
          await tester.scrollUntilVisible(find.text(label), 200, scrollable: find.byType(Scrollable).first);
          expect(find.text(label), findsOneWidget);
          expect(tester.takeException(), isNull, reason: label);
        }
        await unmount(tester);
      });
    }
  }
}
