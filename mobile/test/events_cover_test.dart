import 'dart:typed_data';

import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/platform/image_service.dart';
import 'package:bu_kampus/features/events/event_cover.dart';
import 'package:bu_kampus/features/events/event_form_page.dart';
import 'package:bu_kampus/features/events/events_page.dart';
import 'package:bu_kampus/features/home/home_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// Geçerli JPEG imzalı küçük sahte görsel (önizleme çözülemese de hata fırlatmaz).
PreparedImage fakeImage() => PreparedImage(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 1, 2, 3]), 'image/jpeg');

Map<String, dynamic> featured({String? cover = '/files/events/9.jpg', String? source}) => {
      'id': 9,
      if (source != null) 'source': source,
      'title': 'Bahar Şenliği ' * 4,
      'startsAt': DateTime.now().add(const Duration(days: 2)).toUtc().toIso8601String(),
      'endsAt': DateTime.now().add(const Duration(days: 2, hours: 3)).toUtc().toIso8601String(),
      'location': 'Merkez Kampüs Konferans Salonu ' * 2,
      'goingCount': 42,
      'myRsvp': null,
      'coverUrl': cover,
      'communityName': 'Bilgisayar Kulübü',
      'attendeesPreview': [
        {'userId': 1, 'displayName': 'Ayşe Yılmaz', 'avatarUrl': null},
        {'userId': 2, 'displayName': 'Ali Veli', 'avatarUrl': null},
      ],
    };

/// Formu bir "başlat" düğmesinden açar (pop çalışsın diye).
Widget launcher(FakeBackend b, {Map<String, dynamic>? event, CoverPicker? pick, CoverUploader? up}) {
  final s = makeSession(b);
  return Builder(
    builder: (c) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.push(
            c,
            MaterialPageRoute(
              builder: (_) => EventFormPage(session: s, event: event, pickCover: pick, uploadCover: up),
            ),
          ),
          child: const Text('ac'),
        ),
      ),
    ),
  );
}

Future<void> openForm(WidgetTester tester) async {
  await tester.tap(find.text('ac'));
  await settle(tester, const Duration(milliseconds: 600));
}

Future<void> pickCoverFlow(WidgetTester tester) async {
  await tester.tap(find.text('Kapak fotoğrafı ekle'));
  await settle(tester, const Duration(milliseconds: 600));
  await tester.tap(find.text('Galeriden seç'));
  await settle(tester, const Duration(milliseconds: 600));
}

void main() {
  setUpAll(loadTestFonts);

  group('kapak yukleme formu', () {
    testWidgets('olusturma: once POST /events, sonra PUT /events/{id}/cover', (tester) async {
      useScreen(tester, const Size(390, 1600));
      final b = FakeBackend()..on('/events', {'id': 55, 'title': 'Test'});
      final calls = <String>[];
      ImageSource? src;
      await tester.pumpWidget(buildApp(launcher(b,
          pick: (s) async {
            src = s;
            return fakeImage();
          },
          up: (path, img) async {
            calls.add(path);
            // POST önce gitmiş olmalı
            expect(b.requests.any((r) => r.startsWith('POST /events')), isTrue);
            return {};
          })));
      await openForm(tester);
      expect(find.text('Kapak fotoğrafı ekle'), findsOneWidget);
      await pickCoverFlow(tester);
      expect(src, ImageSource.gallery);
      expect(find.text('Kapak fotoğrafı ekle'), findsNothing);
      expect(find.byTooltip('Kapağı değiştir'), findsOneWidget);
      expect(find.byTooltip('Kapağı kaldır'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Bahar Şenliği');
      await tester.ensureVisible(find.text('Etkinliği oluştur'));
      await tester.tap(find.text('Etkinliği oluştur'));
      await settle(tester, const Duration(seconds: 1));
      expect(calls, ['/events/55/cover']);
      expect((b.bodies['POST /events'] as Map)['title'], 'Bahar Şenliği');
      expect(find.text('ac'), findsOneWidget); // form kapandı
      await unmount(tester);
    });

    testWidgets('kapak secilmezse yukleme cagrilmaz', (tester) async {
      useScreen(tester, const Size(390, 1600));
      final b = FakeBackend()..on('/events', {'id': 55});
      var n = 0;
      await tester.pumpWidget(buildApp(launcher(b, up: (p, i) async => n++)));
      await openForm(tester);
      await tester.enterText(find.byType(TextField).first, 'Bahar Şenliği');
      await tester.ensureVisible(find.text('Etkinliği oluştur'));
      await tester.tap(find.text('Etkinliği oluştur'));
      await settle(tester, const Duration(seconds: 1));
      expect(n, 0);
      expect(b.requests.where((r) => r.startsWith('POST /events')).length, 1);
      await unmount(tester);
    });

    testWidgets('kapak yuklenemezse bildirim + Tekrar dene (sunucu mesaji gosterilir)', (tester) async {
      useScreen(tester, const Size(390, 1600));
      final b = FakeBackend()..on('/events', {'id': 55});
      var n = 0;
      await tester.pumpWidget(buildApp(launcher(b,
          pick: (s) async => fakeImage(),
          up: (p, i) async {
            n++;
            if (n == 1) throw ApiError(413, 'TOO_LARGE', 'Dosya çok büyük.');
            return {};
          })));
      await openForm(tester);
      await pickCoverFlow(tester);
      await tester.enterText(find.byType(TextField).first, 'Bahar Şenliği');
      await tester.ensureVisible(find.text('Etkinliği oluştur'));
      await tester.tap(find.text('Etkinliği oluştur'));
      await settle(tester, const Duration(seconds: 1));
      expect(n, 1);
      expect(find.textContaining('Etkinlik oluşturuldu, kapak yüklenemedi'), findsOneWidget);
      expect(find.textContaining('Dosya çok büyük.'), findsOneWidget);
      await tester.tap(find.text('Tekrar dene'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(n, 2);
      await unmount(tester);
    });

    testWidgets('kisa baslik dogrulanir, istek gitmez', (tester) async {
      useScreen(tester, const Size(390, 1600));
      final b = FakeBackend();
      await tester.pumpWidget(buildApp(launcher(b)));
      await openForm(tester);
      await tester.enterText(find.byType(TextField).first, 'ab');
      await tester.ensureVisible(find.text('Etkinliği oluştur'));
      await tester.tap(find.text('Etkinliği oluştur'));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('Başlık en az 3 karakter olmalı.'), findsOneWidget);
      expect(b.requests.where((r) => r.startsWith('POST')), isEmpty);
      await unmount(tester);
    });

    testWidgets('duzenleme: mevcut kapak gosterilir, kaldirinca DELETE', (tester) async {
      useScreen(tester, const Size(390, 1600));
      final b = FakeBackend();
      final ev = featured();
      await tester.pumpWidget(buildApp(launcher(b, event: ev)));
      await openForm(tester);
      expect(find.byType(EventCoverImage), findsOneWidget);
      await tester.tap(find.byTooltip('Kapağı kaldır'));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.byType(EventCoverImage), findsNothing);
      expect(find.text('Kapak fotoğrafı ekle'), findsOneWidget);
      await tester.ensureVisible(find.text('Kaydet'));
      await tester.tap(find.text('Kaydet'));
      await settle(tester, const Duration(seconds: 1));
      expect(b.requests, contains('PATCH /events/9'));
      expect(b.requests, contains('DELETE /events/9/cover'));
      await unmount(tester);
    });

    testWidgets('duzenleme: yeni kapak secilirse PATCH sonrasi yuklenir', (tester) async {
      useScreen(tester, const Size(390, 1600));
      final b = FakeBackend();
      final calls = <String>[];
      await tester.pumpWidget(buildApp(launcher(b,
          event: featured(),
          pick: (s) async => fakeImage(),
          up: (p, i) async {
            calls.add(p);
            return {};
          })));
      await openForm(tester);
      await tester.tap(find.byTooltip('Kapağı değiştir'));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.tap(find.text('Galeriden seç'));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.ensureVisible(find.text('Kaydet'));
      await tester.tap(find.text('Kaydet'));
      await settle(tester, const Duration(seconds: 1));
      expect(calls, ['/events/9/cover']);
      expect(b.requests.where((r) => r.startsWith('DELETE')), isEmpty);
      await unmount(tester);
    });
  });

  group('ana sayfa one cikan etkinlik', () {
    Widget home(FakeBackend b) =>
        Scaffold(body: HomeTab(session: makeSession(b), onOpenTab: (i, {newsType}) {}));

    testWidgets('200: kapak, etiket, katilimci sayisi, RSVP', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()
        ..on('/events/featured', featured())
        ..on('/events/9/rsvp', {'myRsvp': 'GOING', 'goingCount': 43});
      await tester.pumpWidget(buildApp(home(b)));
      await settle(tester, const Duration(seconds: 1));
      expect(b.requests, contains('GET /events/featured'));
      expect(find.text('En çok katılım'), findsOneWidget);
      expect(find.text('42 kişi katılıyor'), findsOneWidget);
      expect(find.byType(EventCoverImage), findsOneWidget);
      expect(find.text('Katılıyorum'), findsNothing);
      await tester.tap(find.text('Katıl'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(b.requests, contains('PUT /events/9/rsvp'));
      expect(find.text('43 kişi katılıyor'), findsOneWidget);
      // Durum: "Etkinliklerimde"; geri alma yok, kısa onay + kısayol.
      expect(find.text('Etkinliklerimde'), findsOneWidget);
      expect(find.text('Etkinliklerime eklendi'), findsOneWidget);
      await tester.tap(find.text('Etkinliklerimde'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byType(EventsPage), findsOneWidget);
      expect(b.requests.any((r) => r.startsWith('DELETE')), isFalse);
      await unmount(tester);
    });

    testWidgets('kapaksiz featured: hero kart, kapak widget yok', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()..on('/events/featured', featured(cover: null));
      await tester.pumpWidget(buildApp(home(b)));
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('En çok katılım'), findsOneWidget);
      expect(find.byType(EventCoverImage), findsNothing);
      await unmount(tester);
    });

    testWidgets('204: bos durum', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()..on('/events/featured', null, status: 204);
      await tester.pumpWidget(buildApp(home(b)));
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Yaklaşan etkinlik yok'), findsOneWidget);
      expect(find.text('En çok katılım'), findsNothing);
      await unmount(tester);
    });

    testWidgets('hata: bolum ici Tekrar dene, sayfa calismaya devam eder', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()
        ..fail('/events/featured')
        ..on('/menu/today', {'date': '2026-10-26', 'items': ['Pilav'], 'meals': ['Pilav']});
      await tester.pumpWidget(buildApp(home(b)));
      await settle(tester, const Duration(seconds: 2));
      expect(find.text('Etkinlik yüklenemedi'), findsOneWidget);
      expect(find.text('Yeniden dene'), findsNothing); // tüm sayfa çökmedi
      b.on('/events/featured', featured());
      await tester.tap(find.text('Tekrar dene'));
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Etkinlik yüklenemedi'), findsNothing);
      expect(find.text('En çok katılım'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('etkinlik karti kapagi', () {
    testWidgets('liste karti coverUrl gosterir', (tester) async {
      useScreen(tester, kPhoneMedium);
      final ev = featured();
      final b = FakeBackend()..on('/events/calendar*', [ev]);
      await tester.pumpWidget(buildApp(EventsPage(session: makeSession(b))));
      await settle(tester, const Duration(seconds: 1));
      expect(find.byType(EventCoverImage), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('liste karti kapaksiz: kapak widget yok', (tester) async {
      useScreen(tester, kPhoneMedium);
      final b = FakeBackend()..on('/events/calendar*', [featured(cover: null)]);
      await tester.pumpWidget(buildApp(EventsPage(session: makeSession(b))));
      await settle(tester, const Duration(seconds: 1));
      expect(find.byType(EventCoverImage), findsNothing);
      await unmount(tester);
    });
  });

  group('tema x ekran: tasma yok', () {
    for (final br in Brightness.values) {
      for (final size in kPhoneSizes) {
        final tag = '${br.name} ${size.width.toInt()}';
        Future<void> run(WidgetTester tester, FakeBackend b, Widget page) async {
          useScreen(tester, size);
          await tester.pumpWidget(buildApp(page, brightness: br, size: size));
          await settle(tester, const Duration(seconds: 1));
          expect(tester.takeException(), isNull);
          await unmount(tester);
        }

        testWidgets('ana sayfa featured | $tag', (tester) async {
          final b = FakeBackend()..on('/events/featured', featured());
          await run(tester, b, Scaffold(body: HomeTab(session: makeSession(b), onOpenTab: (i, {newsType}) {})));
        });
        testWidgets('etkinlikler listesi | $tag', (tester) async {
          final b = FakeBackend()..on('/events/calendar*', [featured()]);
          await run(tester, b, EventsPage(session: makeSession(b)));
        });
        testWidgets('form bos | $tag', (tester) async {
          final b = FakeBackend();
          await run(tester, b, EventFormPage(session: makeSession(b)));
        });
        testWidgets('form dolu/duzenleme | $tag', (tester) async {
          final b = FakeBackend();
          await run(tester, b, EventFormPage(session: makeSession(b), event: featured()));
        });
      }
    }
  });
}
