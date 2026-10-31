import 'package:bu_kampus/core/permissions/permission_service.dart';
import 'package:bu_kampus/features/academic/acad_ref_widgets.dart';
import 'package:bu_kampus/features/academic/academic_calendar_page.dart';
import 'package:bu_kampus/features/academic/academic_hub_page.dart';
import 'package:bu_kampus/features/academic/academic_models.dart';
import 'package:bu_kampus/features/academic/akad_widgets.dart' show AkadCard;
import 'package:bu_kampus/features/academic/announcements_page.dart';
import 'package:bu_kampus/features/academic/exam_form_page.dart';
import 'package:bu_kampus/features/academic/exams_page.dart';
import 'package:bu_kampus/features/academic/reminder_settings_page.dart';
import 'package:bu_kampus/features/academic/reminders.dart';
import 'package:bu_kampus/features/academic/timetable_page.dart';
import 'package:bu_kampus/features/academic/timetable_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import 'p00_support.dart';

/// P69 Akademik Stitch v3 BIREBIR: kartsiz satirlar, metin sekmeleri, ic ice kart yok (docs/design/BIREBIR_AKADEMIK.md).
/// 3 dil x acik/koyu x yazi 1.0/1.3 x 320/390 tasma matrisi + davranis + erisilebilirlik.
final _wed = DateTime.utc(2026, 10, 28, 8, 20); // Carsamba 11:20 Istanbul
final _nov = DateTime.utc(2026, 11, 5, 6, 0); // Persembe 09:00

class _Platform implements ReminderPlatform {
  @override
  Future<void> replaceAll(List<PlannedReminder> items) async {}

  @override
  Future<bool> shareText(String text, String subject) async => true;
}

FakeBackend _rich() {
  final b = FakeBackend();
  final f = fakeAcademic(b);
  f.semester = {'id': 3, 'name': '2026-2027 Güz', 'startDate': '2026-09-28', 'endDate': '2027-01-15', 'current': true};
  f.addCourse('Çok Uzun Bir Ders Adı: Sayısal Analiz ve Programlama Uygulamaları', 3, '09:00', '10:45',
      room: 'Mühendislik Fakültesi Bilgisayar Laboratuvarı 2', instructor: 'Prof. Dr. Mehmet Ali Yıldırım Karaca', code: 'BIL4001');
  f.addCourse('Algoritma Analizi', 3, '11:00', '12:45', room: 'B-204', code: 'BM-201');
  f.addCourse('Ayrık Matematik', 3, '15:30', '17:15', room: 'Amfi 1', code: 'MAT-105');
  f.addCourse('Fizik', 4, '10:00', '11:00');
  f.addExam('Veri Yapıları Vize', '2026-11-18T10:30:00+03:00');
  f.exams.last['room'] = 'B-204';
  f.addExam('Algoritma Analizi Final', '2026-12-21T14:00:00+03:00', type: 'FINAL');
  f.addExam('Geçmiş Quiz', '2026-10-21T10:00:00+03:00', type: 'QUIZ');
  f.official = [
    {'id': 1, 'title': 'Fizik Final', 'type': 'FINAL', 'courseCode': 'FIZ101', 'department': 'Fizik Mühendisliği Bölümü', 'grade': '1', 'startsAt': '2026-11-20T09:00:00+03:00', 'room': 'A-1', 'note': 'Kimlik kartı zorunlu'}
  ];
  f.events = [
    {'id': 1, 'kind': 'VIZE', 'title': 'Ara sınavlar başlangıcı', 'startsAt': '2026-11-17T21:00:00Z'},
    {'id': 2, 'kind': 'DERS_KAYIT', 'title': 'Ders kayıt son günü', 'startsAt': '2026-11-29T21:00:00Z', 'endsAt': '2026-12-02T21:00:00Z', 'note': 'ÖBS üzerinden'},
  ];
  f.pageSize = 20;
  f.announcements.addAll([
    {'id': 500, 'title': 'Güz dönemi staj başvuruları ve çok uzun bir başlık satırı', 'body': 'x', 'department': 'Bilgisayar Mühendisliği', 'pinned': true, 'publishAt': '2026-11-03T10:00:00+03:00', 'read': false},
    {'id': 501, 'title': 'Okunmuş duyuru', 'body': 'x', 'faculty': 'Mühendislik Fakültesi', 'publishAt': '2026-10-01T10:00:00+03:00', 'read': true},
  ]);
  f.unread = 1;
  return b;
}

Future<void> _noOverflow(WidgetTester tester, String lang, bool dark, double scale) async {
  expect(tester.takeException(), isNull, reason: '$lang dark=$dark x$scale');
}

void main() {
  setUpAll(loadTestFonts);
  setUp(() {
    academicClock = () => _nov;
    ReminderService.platform = _Platform();
    ReminderService.store = MemoryReminderStore();
    PermissionService.instance = FakePermissionService(initial: {AppPermission.notifications: PermState.granted});
  });
  tearDown(() {
    academicClock = DateTime.now;
    ReminderService.platform = const ChannelReminderPlatform();
    ReminderService.store = const SecureReminderStore();
    PermissionService.instance = SystemPermissionService();
  });

  group('p69 matris (tr/en/ar x acik/koyu x 1.0/1.3 x 320/390)', () {
    testWidgets('hub', (t) async {
      await p00Matrix(t, () => AcademicHubPage(session: makeSession(_rich())), scaffold: false, settleMs: 800, check: _noOverflow);
    });
    testWidgets('ders programi (bugun, uzun adlar)', (t) async {
      academicClock = () => _wed;
      await p00Matrix(t, () => TimetablePage(session: makeSession(_rich())), scaffold: false, settleMs: 800, check: _noOverflow);
    });
    testWidgets('sinavlar kisisel + resmi', (t) async {
      await p00Matrix(t, () => ExamsPage(session: makeSession(_rich())), scaffold: false, settleMs: 800, check: _noOverflow);
      await p00Matrix(t, () => ExamsPage(session: makeSession(_rich()), initialTab: 1), scaffold: false, settleMs: 800, check: _noOverflow, widths: const [320]);
    });
    testWidgets('sinav ekle', (t) async {
      await p00Matrix(t, () => ExamFormPage(session: makeSession(_rich()), courses: [Course.fromJson(fakeAcademic(FakeBackend()).addCourse('Veri Yapıları ve Algoritmalar Uygulaması', 1, '09:00', '10:00'))]),
          scaffold: false, check: _noOverflow);
    });
    testWidgets('akademik takvim', (t) async {
      await p00Matrix(t, () => AcademicCalendarPage(session: makeSession(_rich())), scaffold: false, settleMs: 800, check: _noOverflow);
    });
    testWidgets('bolum duyurulari + detay', (t) async {
      await p00Matrix(t, () => AnnouncementsPage(session: makeSession(_rich())), scaffold: false, settleMs: 800, check: _noOverflow);
      await p00Matrix(t, () => AnnouncementDetailPage(session: makeSession(_rich()), id: 500), scaffold: false, settleMs: 800, check: _noOverflow, widths: const [320]);
    });
    testWidgets('hatirlatmalar (izin acik)', (t) async {
      await p00Matrix(t, () => ReminderSettingsPage(session: makeSession(_rich())), scaffold: false, settleMs: 800, check: _noOverflow);
    });
    testWidgets('hatirlatmalar (izin kapali)', (t) async {
      PermissionService.instance = FakePermissionService(initial: {AppPermission.notifications: PermState.denied});
      await p00Matrix(t, () => ReminderSettingsPage(session: makeSession(_rich())), scaffold: false, settleMs: 800, check: _noOverflow);
    });
  });

  group('p69 davranis', () {
    testWidgets('hub: dort kartsiz gezinme satiri + siradaki sinav blogu; kart/simge karosu yok', (t) async {
      useScreen(t, kPhoneMedium);
      await t.pumpWidget(p00App(AcademicHubPage(session: makeSession(_rich())), scaffold: false));
      await settle(t);
      expect(find.byType(AkadCard), findsNothing); // kartsiz satirlar
      for (final k in ['acadhub-timetable', 'acadhub-exams', 'acadhub-calendar', 'acadhub-announcements']) {
        expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
      }
      expect(find.text('SIRADAKİ SINAV'), findsOneWidget);
      expect(find.text('Veri Yapıları Vize'), findsOneWidget);
      expect(find.text('18 Kasım · 10:30 · B-204'), findsOneWidget);
      expect(find.text('13 gün kaldı'), findsOneWidget);
      expect(find.text('1 okunmamış'), findsOneWidget);
      expect(find.text('Hatırlatmalar'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('hub: satira dokununca ilgili sayfa acilir, Hatirlatmalar ayarlari acar', (t) async {
      useScreen(t, kPhoneMedium);
      await t.pumpWidget(p00App(AcademicHubPage(session: makeSession(_rich())), scaffold: false));
      await settle(t);
      await t.tap(find.byKey(const ValueKey('acadhub-exams')));
      await settle(t, const Duration(milliseconds: 800));
      expect(find.byType(ExamsPage), findsOneWidget);
      await t.tap(find.byTooltip('Geri'));
      await settle(t, const Duration(milliseconds: 600));
      await t.tap(find.text('Hatırlatmalar'));
      await settle(t, const Duration(milliseconds: 800));
      expect(find.byType(ReminderSettingsPage), findsOneWidget);
      await unmount(t);
    });

    testWidgets('ders programi: Simdi cizgisi, hafta, kalan dk, Tamamlandi, Son oturum, ozet', (t) async {
      academicClock = () => _wed;
      useScreen(t, kPhoneMedium);
      await t.pumpWidget(p00App(TimetablePage(session: makeSession(_rich())), scaffold: false));
      await settle(t, const Duration(milliseconds: 900));
      expect(find.text('Şimdi · 11:20'), findsOneWidget);
      expect(find.textContaining('5. Hafta'), findsOneWidget);
      expect(find.text('Tamamlandı'), findsOneWidget);
      expect(find.text('85 dk kaldı'), findsOneWidget);
      expect(find.text('Son oturum'), findsOneWidget);
      expect(find.text('Bugün toplam 3 oturum (5 saat 15 dk)'), findsOneWidget);
      expect(find.byType(TtSlotCard), findsNWidgets(3));
      expect(find.byTooltip('Ders ekle'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('ders programi: gun secimi, hafta sonu gunleri yalniz dersi varsa goruntulenir', (t) async {
      academicClock = () => _wed;
      useScreen(t, kPhoneMedium);
      await t.pumpWidget(p00App(TimetablePage(session: makeSession(_rich())), scaffold: false));
      await settle(t, const Duration(milliseconds: 900));
      expect(find.text('Cmt'), findsNothing);
      expect(find.text('Paz'), findsNothing);
      await t.tap(find.text('Sal'));
      await settle(t, const Duration(milliseconds: 700));
      expect(find.text('Salı günü dersin yok.'), findsOneWidget);
      expect(find.byType(TtNowLine), findsNothing);
      await unmount(t);
    });

    testWidgets('sinavlar: baslikta geri oku + 28 sp baslik, + dugmesi formu acar, sekme degisir', (t) async {
      useScreen(t, kPhoneMedium);
      await t.pumpWidget(p00App(ExamsPage(session: makeSession(_rich())), scaffold: false));
      await settle(t, const Duration(milliseconds: 900));
      expect(find.text('Sınavlar'), findsOneWidget); // tek baslik (ust cubukta yinelenmez)
      expect(find.text('Veri Yapıları Vize'), findsOneWidget);
      expect(find.text('18 Kasım · 10:30 · B-204'), findsOneWidget);
      expect(find.text('13 gün kaldı'), findsOneWidget);
      expect(find.byType(AcadTabs), findsOneWidget);
      await t.tap(find.byTooltip('Sınav ekle'));
      await settle(t, const Duration(milliseconds: 800));
      expect(find.byType(ExamFormPage), findsOneWidget);
      await t.tap(find.byTooltip('Geri'));
      await settle(t, const Duration(milliseconds: 600));
      await t.tap(find.text('Okul programı'));
      await settle(t, const Duration(milliseconds: 700));
      expect(find.text('Fizik Final'), findsOneWidget);
      expect(find.byTooltip('Sınav ekle'), findsNothing);
      await unmount(t);
    });

    testWidgets('sinavlar: tek tur varken tur suzgeci yok, farkli tur olunca cikar; bos durum satiri', (t) async {
      useScreen(t, kPhoneMedium);
      final b = FakeBackend();
      fakeAcademic(b).addExam('A Vize', '2026-11-18T10:30:00+03:00');
      await t.pumpWidget(p00App(ExamsPage(session: makeSession(b)), scaffold: false));
      await settle(t, const Duration(milliseconds: 900));
      expect(find.textContaining('Tümü ('), findsNothing);
      await unmount(t);
      await t.pumpWidget(p00App(ExamsPage(session: makeSession(_rich())), scaffold: false));
      await settle(t, const Duration(milliseconds: 900));
      expect(find.textContaining('Tümü ('), findsOneWidget);
      await unmount(t);
      final e = FakeBackend();
      fakeAcademic(e);
      await t.pumpWidget(p00App(ExamsPage(session: makeSession(e)), scaffold: false));
      await settle(t, const Duration(milliseconds: 900));
      expect(find.text('Henüz sınav eklemedin.'), findsOneWidget);
      expect(find.text('Sınav ekle'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('sinav ekle: alan ici hatalar (Sinav adi gerekli, tarih), tur cipleri, bilgi notu, Kaydet', (t) async {
      useScreen(t, const Size(390, 1000));
      await t.pumpWidget(p00App(ExamFormPage(session: makeSession(FakeBackend())), scaffold: false));
      await settle(t);
      expect(find.text('Sınav adı'), findsOneWidget);
      expect(find.text('Sınavdan 1 gün önce yerel, 2 saat önce push bildirimi alırsın.'), findsOneWidget);
      await t.scrollUntilVisible(find.text('Kaydet'), 300, scrollable: find.byType(Scrollable).first);
      await t.tap(find.text('Kaydet'));
      await settle(t, const Duration(milliseconds: 500));
      expect(find.text('Sınav adı gerekli.'), findsOneWidget);
      expect(find.text('Sınav tarihini seç.'), findsOneWidget);
      await t.tap(find.text('Final'));
      await settle(t, const Duration(milliseconds: 300));
      await unmount(t);
    });

    testWidgets('takvim: ay gezgini, nokta, Gune Don bugunu secer, olay satirina dokununca o gun secilir', (t) async {
      useScreen(t, const Size(390, 989));
      await t.pumpWidget(p00App(AcademicCalendarPage(session: makeSession(_rich())), scaffold: false));
      await settle(t, const Duration(milliseconds: 900));
      expect(find.text('Kasım 2026'), findsOneWidget);
      expect(find.text('2026-2027 GÜZ YARIYILI'), findsOneWidget);
      expect(find.text('Akademik Olaylar'), findsOneWidget);
      expect(find.text('2 Kayıt'), findsOneWidget);
      expect(find.text('Ara sınavlar başlangıcı'), findsOneWidget);
      expect(find.text('18 Kasım'), findsOneWidget);
      expect(find.text('Çarşamba'), findsOneWidget);
      await t.tap(find.text('Ders kayıt son günü'));
      await settle(t, const Duration(milliseconds: 500));
      await t.tap(find.text('Güne Dön'));
      await settle(t, const Duration(milliseconds: 600));
      expect(find.text('Kasım 2026'), findsOneWidget);
      await t.tap(find.byTooltip('Sonraki ay'));
      await settle(t, const Duration(milliseconds: 600));
      expect(find.text('Aralık 2026'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('duyurular: okunmamis kalin + nokta, sabitlenmis etiketi, okundu isareti ust cubukta, sekme', (t) async {
      useScreen(t, kPhoneMedium);
      await t.pumpWidget(p00App(AnnouncementsPage(session: makeSession(_rich())), scaffold: false));
      await settle(t, const Duration(milliseconds: 900));
      expect(find.text('Sabitlenmiş'), findsOneWidget);
      expect(find.byType(AcadDot), findsOneWidget); // yalniz okunmamis satirda
      expect(find.text('Mühendislik Fakültesi · 1 ay önce'.replaceAll('1 ay önce', '1 Ekim 2026')), findsOneWidget);
      expect(find.byTooltip('Tümünü okundu işaretle'), findsOneWidget);
      await t.tap(find.byTooltip('Tümünü okundu işaretle'));
      await settle(t, const Duration(milliseconds: 600));
      expect(find.byType(AcadDot), findsNothing);
      expect(find.byTooltip('Tümünü okundu işaretle'), findsNothing);
      await t.tap(find.text('Tümü'));
      await settle(t, const Duration(milliseconds: 700));
      expect(find.text('Okunmuş duyuru'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('duyuru detay: madde isaretli liste, Ekli belgeyi ac, baslik 24 sp', (t) async {
      useScreen(t, kPhoneMedium);
      final b = _rich();
      b.handlers.insert(
          0,
          (req, p) => p == '/announcements/500'
              ? FakeResult.json({
                  'id': 500,
                  'title': 'Güz dönemi staj başvuruları',
                  'body': 'Giriş metni.\n\nHususlar:\n\n- Birinci madde\n- İkinci madde\n\nSon not.',
                  'department': 'Bilgisayar Mühendisliği',
                  'publishAt': '2026-10-12T10:00:00+03:00',
                  'attachmentUrl': 'https://www.bingol.edu.tr/files/staj.pdf',
                  'read': true,
                })
              : null);
      await t.pumpWidget(p00App(AnnouncementDetailPage(session: makeSession(b), id: 500), scaffold: false));
      await settle(t, const Duration(milliseconds: 900));
      expect(find.text('Güz dönemi staj başvuruları'), findsOneWidget);
      expect(find.text('Bilgisayar Mühendisliği · 12 Ekim 2026'), findsOneWidget);
      expect(find.text('Birinci madde'), findsOneWidget);
      expect(find.text('İkinci madde'), findsOneWidget);
      expect(find.text('Ekli belgeyi aç'), findsOneWidget);
      final title = t.widget<Text>(find.text('Güz dönemi staj başvuruları'));
      expect(title.style!.fontSize, 24);
      await unmount(t);
    });

    testWidgets('hatirlatmalar: anahtar kaydeder, sure cipi secilir; izin kapaliyken not + pasif', (t) async {
      useScreen(t, kPhoneMedium);
      await t.pumpWidget(p00App(ReminderSettingsPage(session: makeSession(_rich())), scaffold: false));
      await settle(t, const Duration(milliseconds: 900));
      expect(find.text('Sınav hatırlatması'), findsOneWidget);
      expect(find.text('Ders hatırlatması'), findsOneWidget);
      expect(find.text('Hatırlatmalar bu telefonda oluşturulur.'), findsOneWidget);
      expect(find.text('Sınavdan 2 saat önce (bildirim)'), findsOneWidget);
      await t.tap(find.text('30 dk'));
      await settle(t, const Duration(milliseconds: 400));
      expect((ReminderService.store as MemoryReminderStore).value.classLeadMin, 30);
      await t.tap(find.text('Sınav hatırlatması'));
      await settle(t, const Duration(milliseconds: 400));
      expect((ReminderService.store as MemoryReminderStore).value.examDayBefore, isFalse);
      await unmount(t);

      ReminderService.store = MemoryReminderStore();
      PermissionService.instance = FakePermissionService(initial: {AppPermission.notifications: PermState.denied});
      await t.pumpWidget(p00App(ReminderSettingsPage(session: makeSession(_rich())), scaffold: false));
      await settle(t, const Duration(milliseconds: 900));
      expect(find.text('Bildirim izni kapalı. Hatırlatma almak için ayarlardan izin ver.'), findsOneWidget);
      expect(find.text('Ayarlardan aç'), findsOneWidget);
      await t.tap(find.text('Sınav hatırlatması'), warnIfMissed: false);
      await settle(t, const Duration(milliseconds: 300));
      expect((ReminderService.store as MemoryReminderStore).value.examDayBefore, isTrue); // pasif: degismez
      await unmount(t);
    });
  });

  group('p69 erisilebilirlik (48 dp, etiket, kontrast)', () {
    final pages = <String, Widget Function()>{
      'hub': () => AcademicHubPage(session: makeSession(_rich())),
      'ders programi': () => TimetablePage(session: makeSession(_rich())),
      'sinavlar': () => ExamsPage(session: makeSession(_rich())),
      'sinav ekle': () => ExamFormPage(session: makeSession(_rich())),
      'takvim': () => AcademicCalendarPage(session: makeSession(_rich())),
      'duyurular': () => AnnouncementsPage(session: makeSession(_rich())),
      'hatirlatmalar': () => ReminderSettingsPage(session: makeSession(_rich())),
      'duyuru detay': () => AnnouncementDetailPage(session: makeSession(_rich()), id: 500),
    };
    for (final e in pages.entries) {
      for (final dark in [false, true]) {
        testWidgets('${e.key} dark=$dark', (t) async {
          final h = t.ensureSemantics();
          academicClock = () => _wed;
          useScreen(t, kPhoneMedium);
          await t.pumpWidget(p00App(e.value(), scaffold: false, dark: dark));
          await settle(t, const Duration(seconds: 1));
          await expectLater(t, meetsGuideline(androidTapTargetGuideline));
          await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(t, meetsGuideline(textContrastGuideline));
          h.dispose();
          await unmount(t);
        });
      }
    }
  });
}

