import 'dart:typed_data';

import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/platform/image_service.dart';
import 'package:bu_kampus/features/events/event_cover.dart';
import 'package:bu_kampus/features/events/event_detail_page.dart';
import 'package:bu_kampus/features/events/event_form_page.dart';
import 'package:bu_kampus/features/events/events_page.dart';
import 'package:bu_kampus/features/media_crop/media_crop.dart';
import 'package:bu_kampus/features/home/home_tab.dart';
import 'package:flutter/material.dart';
import 'package:bu_kampus/features/events/etkinlik_parts.dart';
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
Widget launcher(FakeBackend b, {Map<String, dynamic>? event, CoverPicker? pick, CoverUploader? up, CoverCropper? crop}) {
  // Oluşturma yalnız bir kulüp adına yapılır: tek yönetilen kulüp otomatik seçilir.
  if (event == null) b.on('/me/communities*', {'items': [{'id': 7, 'name': 'Robotik Topluluğu', 'myRole': 'OWNER', 'myStatus': 'ACTIVE'}]});
  final s = makeSession(b);
  return Builder(
    builder: (c) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.push(
            c,
            MaterialPageRoute(
              builder: (_) => EventFormPage(
                session: s,
                event: event,
                pickCover: pick,
                uploadCover: up,
                // Varsayılan: kırpma sayfası atlanır, görsel olduğu gibi kabul edilir.
                cropCover: crop ?? (c, bytes, spec) async => CropOutcome.cropped(bytes),
              ),
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
      await tester.enterText(find.byType(TextField).first, 'Bahar Şenliği');
      await tester.ensureVisible(find.text('Etkinliği oluştur'));
      await tester.pump();
      await tester.tap(find.text('Etkinliği oluştur'));
      await settle(tester, const Duration(seconds: 1));
      expect(calls, ['/events/55/cover']);
      expect((b.bodies['POST /events'] as Map)['title'], 'Bahar Şenliği');
      expect(find.text('ac'), findsOneWidget); // form kapandı
      await unmount(tester);
    });

    testWidgets('kapak 16:9 kirpma ile secilir: kirpici cover biciminde cagrilir, ciktisi yuklenir', (tester) async {
      useScreen(tester, const Size(390, 1600));
      final b = FakeBackend()..on('/events', {'id': 55});
      CropSpec? seen;
      final cropped = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 9, 9]);
      final uploaded = <int>[];
      await tester.pumpWidget(buildApp(launcher(b,
          pick: (s) async => fakeImage(),
          crop: (c, bytes, spec) async {
            seen = spec;
            return CropOutcome.cropped(cropped);
          },
          up: (path, img) async {
            uploaded.addAll(img.bytes);
            return {};
          })));
      await openForm(tester);
      await tester.enterText(find.byKey(const ValueKey('evc-title')), 'Bahar Şenliği');
      await pickCoverFlow(tester);
      expect(seen, isNotNull);
      expect(seen!.kind, CropKind.cover);
      expect(seen!.previewTitle, 'Bahar Şenliği');
      expect(seen!.previewSubtitle, 'Robotik Topluluğu');
      await tester.ensureVisible(find.text('Etkinliği oluştur'));
      await tester.pump();
      await tester.tap(find.text('Etkinliği oluştur'));
      await settle(tester, const Duration(seconds: 1));
      expect(uploaded, cropped); // yüklenen bayt = kırpma çıktısı
      await unmount(tester);
    });

    testWidgets('kirpmadan vazgecmek kapagi degistirmez', (tester) async {
      useScreen(tester, const Size(390, 1600));
      final b = FakeBackend();
      await tester.pumpWidget(buildApp(launcher(b, pick: (s) async => fakeImage(), crop: (c, bytes, spec) async => null)));
      await openForm(tester);
      await pickCoverFlow(tester);
      expect(find.text('Kapak fotoğrafı ekle'), findsOneWidget); // hâlâ boş
      await unmount(tester);
    });

    testWidgets('kirpmada "Fotografi degistir": secici yeniden acilir', (tester) async {
      useScreen(tester, const Size(390, 1600));
      final b = FakeBackend();
      var picks = 0;
      var crops = 0;
      await tester.pumpWidget(buildApp(launcher(b,
          pick: (s) async {
            picks++;
            return fakeImage();
          },
          crop: (c, bytes, spec) async => ++crops == 1 ? const CropOutcome.change() : CropOutcome.cropped(bytes))));
      await openForm(tester);
      await pickCoverFlow(tester);
      expect(picks, 2);
      expect(find.byTooltip('Kapağı değiştir'), findsOneWidget);
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
      await tester.pump();
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
      await tester.pump();
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
      await tester.pump();
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
      await tester.tap(find.byTooltip('Kapağı değiştir'));
      await settle(tester, const Duration(milliseconds: 600));
      await tester.tap(find.text('Kapağı kaldır'));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.byType(EventCoverImage), findsNothing);
      expect(find.text('Kapak fotoğrafı ekle'), findsOneWidget);
      await tester.ensureVisible(find.text('Kaydet'));
      await tester.pump();
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
      await tester.pump();
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

    testWidgets('200: satir (ay + gun, baslik, kulup · saat), kapak yok, RSVP yok', (tester) async {
      useScreen(tester, const Size(390, 2400));
      final b = FakeBackend()..on('/events/featured', featured());
      await tester.pumpWidget(buildApp(home(b)));
      await settle(tester, const Duration(seconds: 1));
      expect(b.requests, contains('GET /events/featured'));
      expect(find.text('Yaklaşan etkinlikler'), findsOneWidget);
      expect(find.text('Bahar Şenliği ' * 4), findsOneWidget);
      expect(find.textContaining('Bilgisayar Kulübü'), findsOneWidget);
      // Stitch v3: kapak görseli ve katılım düğmesi yok (katılma etkinlik detayında).
      expect(find.byType(EventCoverImage), findsNothing);
      expect(find.text('Katıl'), findsNothing);
      expect(find.text('42 kişi katılıyor'), findsNothing);
      await tester.tap(find.text('Bahar Şenliği ' * 4));
      await settle(tester, const Duration(milliseconds: 600));
      expect(find.byType(EventDetailPage), findsOneWidget);
      expect(b.requests.any((r) => r.startsWith('PUT') || r.startsWith('DELETE')), isFalse);
      await unmount(tester);
    });

    testWidgets('kapaksiz featured: kapak widget yok', (tester) async {
      useScreen(tester, const Size(390, 2400));
      final b = FakeBackend()..on('/events/featured', featured(cover: null));
      await tester.pumpWidget(buildApp(home(b)));
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Bahar Şenliği ' * 4), findsOneWidget);
      expect(find.byType(EventCoverImage), findsNothing);
      await unmount(tester);
    });

    testWidgets('204: bos durum', (tester) async {
      useScreen(tester, const Size(390, 2400));
      final b = FakeBackend()..on('/events/featured', null, status: 204);
      await tester.pumpWidget(buildApp(home(b)));
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Yaklaşan etkinlik yok'), findsOneWidget);
      expect(find.text('Etkinliklere göz at'), findsOneWidget);
      expect(find.text('En çok katılım'), findsNothing);
      await unmount(tester);
    });

    testWidgets('hata: bolum ici Tekrar dene, sayfa calismaya devam eder', (tester) async {
      useScreen(tester, const Size(390, 2400));
      final b = FakeBackend()
        ..fail('/events/featured')
        ..on('/menu/today', {'date': '2026-10-26', 'items': ['Pilav']});
      await tester.pumpWidget(buildApp(home(b)));
      await settle(tester, const Duration(seconds: 2));
      expect(find.text('Etkinlik yüklenemedi'), findsOneWidget);
      expect(find.text('Yeniden dene'), findsNothing); // tüm sayfa çökmedi
      b.on('/events/featured', featured());
      await tester.tap(find.text('Tekrar dene'));
      await settle(tester, const Duration(seconds: 1));
      expect(find.text('Etkinlik yüklenemedi'), findsNothing);
      expect(find.text('Bahar Şenliği ' * 4), findsOneWidget);
      await unmount(tester);
    });
  });

  group('etkinlik karti kapagi', () {
    testWidgets('liste karti (yeni tasarim): kapak yok, tarih karosu var', (tester) async {
      useScreen(tester, kPhoneMedium);
      final ev = featured();
      final b = FakeBackend()..on('/events/calendar*', [ev]);
      await tester.pumpWidget(buildApp(EventsPage(session: makeSession(b))));
      await settle(tester, const Duration(seconds: 1));
      expect(find.byType(EventCoverImage), findsNothing);
      expect(find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('ev-card-')), findsOneWidget);
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
          final b = FakeBackend()..on('/me/communities*', {'items': [{'id': 7, 'name': 'Robotik Topluluğu', 'myRole': 'OWNER', 'myStatus': 'ACTIVE'}]});
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
