import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/polls/anket_flat.dart';
import 'package:bu_kampus/features/polls/poll_club_section.dart';
import 'package:bu_kampus/features/polls/poll_detail_page.dart';
import 'package:bu_kampus/features/polls/poll_form_page.dart';
import 'package:bu_kampus/features/polls/poll_list_page.dart';
import 'package:bu_kampus/features/polls/poll_parts.dart';
import 'package:bu_kampus/features/support/support_new_ticket_page.dart';
import 'package:bu_kampus/features/support/support_page.dart';
import 'package:bu_kampus/features/support/support_suggestions_page.dart';
import 'package:bu_kampus/features/support/support_ticket_page.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import 'p00_support.dart';

/// P68 Anketler (4 ekran) + Destek (5 ekran) Stitch v3 birebir: kartsiz satir, metin sekmeleri, beyaz 48 dp alan,
/// sonuc cubuklari, 3 dil x acik/koyu x 1.0/1.3 x 320/390 tasma matrisi ve 48 dp dokunma alani.

String _later(Duration d) => DateTime.now().add(d).toUtc().toIso8601String();

Map<String, dynamic> _poll(int id, String title, String scope, String type, Duration left,
    {List<String>? opts, List<int>? mine, bool anonymous = false, String showResults = 'ALWAYS', bool closed = false}) {
  final p = samplePoll(
      id: id,
      title: title,
      type: type,
      anonymous: anonymous,
      optionCount: opts?.length ?? 3,
      myOptionIds: mine,
      closesAt: _later(left),
      showResults: showResults,
      closed: closed);
  p['scope'] = scope;
  if (scope != 'COMMUNITY') {
    p['communityId'] = null;
    p['communityName'] = null;
  }
  if (opts != null) {
    p['options'] = [for (var i = 0; i < opts.length; i++) {'id': id * 100 + i + 1, 'text': opts[i], 'position': i + 1}];
  }
  return p;
}

const _menuOpts = ['Mevcut menü', 'Daha çok vejetaryen seçenek', 'Daha çok tatlı çeşidi', 'Kahvaltı eklensin'];

FakeBackend _listBe() {
  final b = FakeBackend();
  final f = fakePolls(b, count: 0);
  f.polls
    ..add(_poll(1, 'Yeni dönem yemek menüsü', 'MENU', 'SINGLE', const Duration(days: 2, hours: 3), opts: _menuOpts))
    ..add(_poll(2, 'Kulüp başkanlığı seçimi', 'COMMUNITY', 'RANKED', const Duration(days: 5, hours: 3), opts: ['Ayşe', 'Mehmet', 'Elif']))
    ..add(_poll(3, 'Kütüphane çalışma saatleri', 'GLOBAL', 'MULTI', const Duration(days: 1, hours: 3), opts: ['24 saat açık', 'Hafta sonu açık', 'Mevcut'], mine: [301]));
  f.others[1] = {101: 20, 102: 12, 103: 6, 104: 4};
  f.others[3] = {301: 100, 302: 40, 303: 15};
  return b;
}

FakeBackend _voteBe({bool voted = false, String type = 'SINGLE', bool closed = false, List<int>? mine}) {
  final b = FakeBackend();
  final f = fakePolls(b, count: 0);
  f.polls.add(_poll(1, 'Yeni dönem yemek menüsü', 'MENU', type, const Duration(days: 2, hours: 3),
      opts: type == 'RATING' ? null : _menuOpts, anonymous: true, mine: voted ? (mine ?? [101]) : null, showResults: 'AFTER_VOTE', closed: closed));
  f.others[1] = {101: 13, 102: 9, 103: 4, 104: 2};
  return b;
}

Map<String, dynamic> _page(List<Object> items) => {'items': items, 'nextCursor': null};

FakeBackend _supportBe() => FakeBackend()
  ..on('/faq', [
    {
      'category': 'Hesap',
      'items': [
        {'question': 'Şifremi nasıl değiştiririm?', 'answer': 'Profil ayarlarından şifre sıfırlama bağlantısı iste.'},
        {'question': 'Hesabımı nasıl silerim?', 'answer': 'Profil, Ayarlar, Hesabı sil.'},
        {'question': 'Etkinliğe nasıl katılırım?', 'answer': 'Katıl düğmesine dokun.'},
      ],
    },
  ])
  ..on('/support/tickets/3812', {
    'ticket': {'id': 3812, 'subject': 'Yemekhane puanı görünmüyor', 'status': 'ANSWERED', 'category': 'TECHNICAL', 'createdAt': DateTime.now().toIso8601String()},
    'messages': [
      {'id': 1, 'text': 'Merhaba, hangi günkü puan?', 'fromStaff': true, 'createdAt': DateTime.now().toIso8601String()},
      {'id': 2, 'text': 'Dünkü öğle menüsü.', 'fromStaff': false, 'createdAt': DateTime.now().toIso8601String()},
    ],
  })
  ..on('/support/tickets', _page([
    {'id': 3812, 'subject': 'Yemekhane puanı görünmüyor', 'status': 'ANSWERED', 'category': 'ACCOUNT', 'createdAt': '2026-10-12T10:00:00'},
    {'id': 3790, 'subject': 'Kulüp listesinde eksiklik', 'status': 'OPEN', 'category': 'TECHNICAL', 'createdAt': '2026-10-10T10:00:00'},
    {'id': 3411, 'subject': 'Derslik kodu güncellemesi', 'status': 'CLOSED', 'category': 'ACCOUNT', 'createdAt': '2025-09-28T10:00:00'},
  ]))
  ..on('/suggestions', {
    'totalPages': 1,
    'items': [
      {'id': 1, 'subject': 'Kütüphane 24 saat açık olsun', 'message': 'Sınav dönemlerinde salonlar yetersiz.', 'status': 'PLANNED', 'voteCount': 142, 'votedByMe': true, 'createdAt': '2026-10-27T10:00:00'},
      {'id': 2, 'subject': 'Ring sefer saatleri', 'message': 'Yoğunluk var.', 'status': 'IN_REVIEW', 'voteCount': 86, 'votedByMe': false, 'createdAt': '2026-10-26T10:00:00'},
    ],
  });

void main() {
  setUpAll(loadTestFonts);

  group('Anketler 01 liste', () {
    testWidgets('metin sekmeleri + kartsiz satir: baslik, meta, katilim, Oy verdiniz (ok yesil)', (t) async {
      useScreen(t, kPhoneMedium);
      await t.pumpWidget(buildApp(PollListPage(session: makeSession(_listBe())), size: kPhoneMedium));
      await settle(t, const Duration(milliseconds: 900));
      expect(find.byType(AnketTextTabs), findsOneWidget);
      expect(t.getSize(find.byType(AnketTextTabs)).height, 48);
      expect(find.text('Açık'), findsOneWidget);
      expect(find.text('Katıldıklarım'), findsOneWidget);
      expect(find.text('Kapanan'), findsOneWidget);
      expect(find.byType(PollCard), findsNWidgets(3));
      expect(find.byType(BuCard), findsNothing);
      expect(find.text('Yeni dönem yemek menüsü'), findsOneWidget);
      expect(find.text('Yemek · Tek seçim · 2 gün kaldı'), findsOneWidget);
      expect(find.text('42 katılım'), findsOneWidget);
      expect(find.text('Oy verdiniz'), findsOneWidget);
      final voted = t.widget<Text>(find.text('Oy verdiniz'));
      final ctx = t.element(find.text('Oy verdiniz'));
      expect(voted.style!.color, ctx.bu.ok);
      // Satir yuksekligi: referansta ~79 dp.
      final h = t.getSize(find.byType(PollCard).at(1)).height;
      expect(h, inInclusiveRange(77, 82));
      await unmount(t);
    });

    testWidgets('bos: tek soluk satir; hata: soluk satir + Yeniden dene metin dugmesi; ikon/kart yok', (t) async {
      useScreen(t, kPhoneMedium);
      final b = FakeBackend();
      fakePolls(b, count: 0);
      await t.pumpWidget(buildApp(PollListPage(session: makeSession(b)), size: kPhoneMedium));
      await settle(t, const Duration(milliseconds: 900));
      expect(find.text('Şu an açık anket yok.'), findsOneWidget);
      expect(find.byType(BuCard), findsNothing);
      await unmount(t);

      useScreen(t, kPhoneMedium);
      await t.pumpWidget(buildApp(PollListPage(session: makeSession(FakeBackend()..fail('/polls*'))), size: kPhoneMedium));
      await settle(t, const Duration(milliseconds: 900));
      expect(find.text('Yüklenemedi, tekrar dene'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Yeniden dene'), findsOneWidget);
      expect(t.getSize(find.widgetWithText(TextButton, 'Yeniden dene')).height, greaterThanOrEqualTo(48));
      await unmount(t);
    });

    testWidgets('"+ Yeni" yalniz yetkili kulup listesinde; pr metin; 48 dp', (t) async {
      useScreen(t, kPhoneMedium);
      await t.pumpWidget(buildApp(PollListPage(session: makeSession(_listBe()), communityId: 5, canCreate: true), size: kPhoneMedium));
      await settle(t, const Duration(milliseconds: 900));
      expect(find.text('+ Yeni'), findsOneWidget);
      expect(find.byType(AnketTextTabs), findsNothing);
      expect(t.getSize(find.widgetWithText(TextButton, '+ Yeni')).height, greaterThanOrEqualTo(48));
      await unmount(t);
    });
  });

  group('Anketler 02/03 detay', () {
    testWidgets('oy verme: 56 dp beyaz satir, secili = soft + pr 1.5 dp cerceve, Oy ver icerikte, gizli oy notu', (t) async {
      useScreen(t, kPhoneMedium);
      await t.pumpWidget(buildApp(PollDetailPage(session: makeSession(_voteBe()), pollId: 1), size: kPhoneMedium));
      await settle(t, const Duration(milliseconds: 900));
      expect(find.text('Anket'), findsOneWidget);
      expect(find.text('Yeni dönem yemek menüsü'), findsOneWidget);
      expect(find.text('Yemek · Tek seçim · Gizli oy · 2 gün kaldı'), findsOneWidget);
      for (final o in _menuOpts) {
        expect(find.text(o), findsOneWidget);
      }
      final row = find.ancestor(of: find.text('Mevcut menü'), matching: find.byType(AnimatedContainer)).first;
      expect(t.getSize(row).height, 56);
      expect(find.text('Kimin ne oy verdiği kimseye gösterilmez.'), findsOneWidget);
      await t.tap(find.text('Mevcut menü'));
      await t.pump(const Duration(milliseconds: 400));
      final deco = t.widget<AnimatedContainer>(find.ancestor(of: find.text('Mevcut menü'), matching: find.byType(AnimatedContainer)).first).decoration! as BoxDecoration;
      final tk = t.element(find.text('Mevcut menü')).bu;
      expect(deco.color, tk.soft);
      expect((deco.border! as Border).top.color, tk.pr);
      expect((deco.border! as Border).top.width, 1.5);
      expect(find.byType(BottomAppBar), findsNothing);
      await unmount(t);
    });

    testWidgets('sonuc: %48 / %31, 8 dp cubuk, Senin oyun, katilim ozeti, Oyumu geri cek (cerceveli)', (t) async {
      useScreen(t, kPhoneMedium);
      await t.pumpWidget(buildApp(PollDetailPage(session: makeSession(_voteBe(voted: true)), pollId: 1), size: kPhoneMedium));
      await settle(t, const Duration(milliseconds: 1400));
      expect(find.text('%48'), findsOneWidget);
      expect(find.text('%31'), findsOneWidget);
      expect(find.text('Senin oyun'), findsOneWidget);
      expect(find.text('14 oy'), findsOneWidget);
      expect(find.text('29 katılım · 2 gün kaldı'), findsOneWidget);
      expect(find.text('Oyumu geri çek'), findsOneWidget);
      final bar = t.getSize(find.descendant(of: find.byType(ResultBar).first, matching: find.byType(ClipRRect)).first);
      expect(bar.height, 8);
      expect(find.byType(BuCard), findsNothing);
      await unmount(t);
    });

    testWidgets('puanlama: yildizlar 48 dp dokunma; coklu secim: kare onay kutusu', (t) async {
      useScreen(t, kPhoneMedium);
      await t.pumpWidget(buildApp(PollDetailPage(session: makeSession(_voteBe(type: 'RATING')), pollId: 1), size: kPhoneMedium));
      await settle(t, const Duration(milliseconds: 900));
      expect(find.byType(StarRating), findsOneWidget);
      expect(t.getSize(find.byType(StarRating)).height, greaterThanOrEqualTo(48));
      await unmount(t);

      useScreen(t, kPhoneMedium);
      await t.pumpWidget(buildApp(PollDetailPage(session: makeSession(_voteBe(type: 'MULTI')), pollId: 1), size: kPhoneMedium));
      await settle(t, const Duration(milliseconds: 900));
      expect(find.byType(AnketMarkFlat), findsNWidgets(4));
      expect(t.widget<AnketMarkFlat>(find.byType(AnketMarkFlat).first).square, isTrue);
      await unmount(t);
    });
  });

  group('Anketler 04 form', () {
    testWidgets('etiketler ustte, 48 dp alanlar, Tur segmenti, secenek sayaci, bitis cipleri, anahtar satirlari, Yayinla', (t) async {
      useScreen(t, const Size(390, 1800));
      final b = FakeBackend();
      fakePolls(b, count: 0);
      await t.pumpWidget(buildApp(PollFormPage(session: makeSession(b), communityId: 5), size: const Size(390, 1800)));
      await settle(t, const Duration(milliseconds: 900));
      expect(find.text('Anket oluştur'), findsOneWidget);
      for (final s in ['Başlık', 'Açıklama (isteğe bağlı)', 'Tür', 'Seçenekler (2-12)', '2 / 12', 'Bitiş zamanı', 'Sonuçlar ne zaman görünsün?', 'Gizli oy', 'Bildirim gönder', 'Yayınla']) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
      expect(find.text('Tek seçim'), findsOneWidget);
      expect(find.text('Çoklu'), findsOneWidget);
      expect(find.text('Puanlama'), findsOneWidget);
      expect(find.text('Sıralı'), findsOneWidget);
      expect(find.text('1 gün'), findsOneWidget);
      expect(find.text('3 gün'), findsOneWidget);
      expect(find.text('7 gün'), findsOneWidget);
      expect(find.text('Tarih seç'), findsOneWidget);
      expect(find.text('+ Seçenek ekle'), findsOneWidget);
      expect(t.getSize(find.byType(TextField).first).height, 48);
      expect(find.byType(Switch), findsNWidgets(2));
      expect(find.byType(BuCard), findsNothing);
      await unmount(t);
    });

    testWidgets('secenek ekle/sil: sayac guncellenir; tek secenekle Yayinla -> satir ici "En az 2 secenek girin."', (t) async {
      useScreen(t, const Size(390, 1400));
      final b = FakeBackend();
      fakePolls(b, count: 0);
      await t.pumpWidget(buildApp(PollFormPage(session: makeSession(b), communityId: 5), size: const Size(390, 1400)));
      await settle(t, const Duration(milliseconds: 900));
      await t.tap(find.text('+ Seçenek ekle'));
      await settle(t, const Duration(milliseconds: 500));
      expect(find.text('3 / 12'), findsOneWidget);
      await t.tap(find.byTooltip('Seçeneği sil').first);
      await settle(t, const Duration(milliseconds: 500));
      expect(find.text('2 / 12'), findsOneWidget);
      await t.enterText(find.byType(TextField).at(0), 'Baslik');
      await t.enterText(find.byType(TextField).at(2), 'Tek');
      await t.ensureVisible(find.text('Yayınla'));
      await t.tap(find.text('Yayınla'));
      await settle(t, const Duration(milliseconds: 600));
      expect(find.text('En az 2 seçenek girin.'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('Puanlama turunde secenek alanlari gizlenir', (t) async {
      useScreen(t, const Size(390, 1200));
      final b = FakeBackend();
      fakePolls(b, count: 0);
      await t.pumpWidget(buildApp(PollFormPage(session: makeSession(b), communityId: 5), size: const Size(390, 1200)));
      await settle(t, const Duration(milliseconds: 900));
      await t.tap(find.text('Puanlama'));
      await settle(t, const Duration(milliseconds: 600));
      expect(find.text('Seçenekler (2-12)'), findsNothing);
      await unmount(t);
    });
  });

  group('Destek', () {
    testWidgets('01 ana: bolum basliklari, kartsiz SSS ve talep satirlari, durum rengi, Yeni talep, alt baglantilar', (t) async {
      useScreen(t, const Size(390, 900));
      await t.pumpWidget(buildApp(SupportPage(session: makeSession(_supportBe())), size: const Size(390, 900)));
      await settle(t, const Duration(milliseconds: 900));
      expect(find.text('Sık sorulan sorular'), findsOneWidget);
      expect(find.text('Taleplerim'), findsOneWidget);
      expect(find.byType(BuCard), findsNothing);
      expect(find.byType(TextField), findsNothing); // 3 soru: arama/sutuz yok
      expect(find.text('12 Ekim · Yanıtlandı', findRichText: true), findsOneWidget);
      expect(find.text('10 Ekim · Açık', findRichText: true), findsOneWidget);
      expect(find.text('28 Eylül 2025 · Kapalı', findRichText: true), findsOneWidget);
      expect(find.widgetWithText(BuButton, 'Yeni talep'), findsOneWidget);
      expect(find.text('Geri bildirim'), findsOneWidget);
      expect(find.text('Öneri panosu'), findsOneWidget);
      // SSS akordeonu: cevap dokununca acilir.
      expect(find.text('Profil ayarlarından şifre sıfırlama bağlantısı iste.'), findsNothing);
      await t.tap(find.text('Şifremi nasıl değiştiririm?'));
      await settle(t, const Duration(milliseconds: 600));
      expect(find.text('Profil ayarlarından şifre sıfırlama bağlantısı iste.'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('04 durumlar: bos -> "Henuz talebin yok." + Yeni talep metin dugmesi; hata -> tek satir + Yeniden dene', (t) async {
      useScreen(t, const Size(390, 900));
      await t.pumpWidget(buildApp(SupportPage(session: makeSession(FakeBackend()..on('/faq', <Object>[])..on('/support/tickets', _page([])))), size: const Size(390, 900)));
      await settle(t, const Duration(milliseconds: 900));
      expect(find.text('Henüz talebin yok.'), findsOneWidget);
      expect(find.text('Yeni talep'), findsOneWidget);
      expect(find.byType(BuButton), findsNothing);
      await unmount(t);

      useScreen(t, const Size(390, 900));
      final b = _supportBe()..on('/support/tickets', {'code': 'X', 'message': 'x'}, status: 500);
      await t.pumpWidget(buildApp(SupportPage(session: makeSession(b)), size: const Size(390, 900)));
      await settle(t, const Duration(milliseconds: 900));
      expect(find.text('Yüklenemedi, tekrar dene'), findsOneWidget);
      expect(find.text('Yeniden dene'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('02 yazisma: baslik = konu, "Yanitlandi · Bilet #3812", Talebi kapat, Destek etiketi, balonlar, Yanitini yaz', (t) async {
      useScreen(t, kPhoneMedium);
      await t.pumpWidget(buildApp(SupportTicketPage(session: makeSession(_supportBe()), ticketId: 3812), size: kPhoneMedium));
      await settle(t, const Duration(milliseconds: 900));
      expect(find.text('Yemekhane puanı görünmüyor'), findsOneWidget);
      expect(find.text('Yanıtlandı · Bilet #3812', findRichText: true), findsOneWidget);
      expect(find.text('Talebi kapat'), findsOneWidget);
      expect(find.text('Destek'), findsOneWidget);
      expect(find.text('Merhaba, hangi günkü puan?'), findsOneWidget);
      expect(find.text('Yanıtını yaz'), findsOneWidget);
      expect(find.byTooltip('Gönder'), findsOneWidget);
      expect(t.getSize(find.byTooltip('Gönder')).width, greaterThanOrEqualTo(44));
      // Kendi mesaji sf2, destek yaniti sf + cizgili.
      final tk = t.element(find.text('Dünkü öğle menüsü.')).bu;
      BoxDecoration deco(String s) => t.widget<Container>(find.ancestor(of: find.text(s), matching: find.byType(Container)).first).decoration! as BoxDecoration;
      expect(deco('Dünkü öğle menüsü.').color, tk.sf2);
      expect(deco('Merhaba, hangi günkü puan?').color, tk.sf);
      expect(deco('Merhaba, hangi günkü puan?').border, isNotNull);
      await unmount(t);
    });

    testWidgets('03 yeni talep: Zorunlu, sayac, bildirim notu, Gonder; konu < 3 karakter -> satir ici hata', (t) async {
      useScreen(t, kPhoneMedium);
      await t.pumpWidget(buildApp(NewTicketPage(session: makeSession(FakeBackend())), size: kPhoneMedium));
      await settle(t, const Duration(milliseconds: 900));
      expect(find.text('Konu'), findsOneWidget);
      expect(find.text('Zorunlu'), findsOneWidget);
      expect(find.text('Mesaj'), findsOneWidget);
      expect(find.text('0/2000'), findsOneWidget);
      expect(find.text('Yanıtı bildirim ve e-posta ile alırsın.'), findsOneWidget);
      expect(t.getSize(find.byType(TextField).first).height, 48);
      await t.enterText(find.byType(TextField).first, 'De');
      await t.enterText(find.byType(TextField).last, 'Ayrinti');
      await t.ensureVisible(find.widgetWithText(BuButton, 'Gönder'));
      await t.tap(find.widgetWithText(BuButton, 'Gönder'));
      await settle(t, const Duration(milliseconds: 500));
      expect(find.text('Konu en az 3 karakter olmalı.'), findsOneWidget);
      await unmount(t);
    });

    testWidgets('05 oneriler: baslik "Oneriler", siralama metinleri, kartsiz satir, 56x64 oy kontrolu, Oneri gonder', (t) async {
      useScreen(t, kPhoneMedium);
      await t.pumpWidget(buildApp(SuggestionsPage(session: makeSession(_supportBe())), size: kPhoneMedium));
      await settle(t, const Duration(milliseconds: 900));
      expect(find.text('Öneriler'), findsOneWidget);
      expect(find.text('En çok oylanan'), findsOneWidget);
      expect(find.text('Yeni'), findsOneWidget);
      expect(find.byType(BuCard), findsNothing);
      expect(find.text('Kütüphane 24 saat açık olsun'), findsOneWidget);
      expect(find.text('Planlandı'), findsOneWidget);
      expect(t.getSize(find.byType(VotePill).first), const Size(56, 64));
      expect(find.text('142'), findsOneWidget);
      expect(find.text('Öneri gönder'), findsOneWidget);
      // oy: ikinci satirda dokununca sayi artar
      await t.tap(find.byType(VotePill).at(1));
      await settle(t, const Duration(milliseconds: 500));
      expect(find.text('87'), findsOneWidget);
      await unmount(t);
    });
  });

  group('tasma matrisi (3 dil x acik/koyu x 1.0/1.3 x 320/390)', () {
    testWidgets('anket listesi', (t) async {
      await p00Matrix(t, () => PollListPage(session: makeSession(_listBe())), scaffold: false, settleMs: 700);
    });
    testWidgets('anket oy verme', (t) async {
      await p00Matrix(t, () => PollDetailPage(session: makeSession(_voteBe()), pollId: 1), scaffold: false, settleMs: 700);
    });
    testWidgets('anket sonuclari', (t) async {
      await p00Matrix(t, () => PollDetailPage(session: makeSession(_voteBe(voted: true)), pollId: 1), scaffold: false, settleMs: 900);
    });
    testWidgets('anket formu', (t) async {
      await p00Matrix(t, () {
        final b = FakeBackend();
        fakePolls(b, count: 0);
        return PollFormPage(session: makeSession(b), communityId: 5);
      }, scaffold: false, settleMs: 500);
    });
    testWidgets('kulup anket bolumu', (t) async {
      await p00Matrix(t, () => SingleChildScrollView(child: PollClubSection(session: makeSession(_listBe()), communityId: 5, canCreate: true)), settleMs: 700);
    });
    testWidgets('destek ana', (t) async {
      await p00Matrix(t, () => SupportPage(session: makeSession(_supportBe())), scaffold: false, settleMs: 700);
    });
    testWidgets('destek yazisma', (t) async {
      await p00Matrix(t, () => SupportTicketPage(session: makeSession(_supportBe()), ticketId: 3812), scaffold: false, settleMs: 700);
    });
    testWidgets('yeni talep', (t) async {
      await p00Matrix(t, () => NewTicketPage(session: makeSession(FakeBackend())), scaffold: false, settleMs: 500);
    });
    testWidgets('oneriler', (t) async {
      await p00Matrix(t, () => SuggestionsPage(session: makeSession(_supportBe())), scaffold: false, settleMs: 700);
    });
  });
}
