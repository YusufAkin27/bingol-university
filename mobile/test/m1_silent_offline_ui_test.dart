import 'package:bu_kampus/core/app_gate.dart';
import 'package:bu_kampus/core/cache/message_cache.dart';
import 'package:bu_kampus/features/chat/chat_tab.dart';
import 'package:bu_kampus/features/home/home_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

/// M1 (kullanici karari 2026-10-30): cevrimdisiyken PASIF bilgi seritleri/metinleri yok; kayitli veri sessizce
/// gosterilir; kayit yoksa mevcut hata ekrani kalir.
const _banned = [
  'İnternet bağlantısı yok',
  'Kayıtlı veriler gösteriliyor',
  'Çevrimdışı önbellek',
  'Son güncelleme',
  'Son kaydedilen',
  'gönderilecek',
  'Bekliyor',
  'Kuyrukta',
];

void expectSilent() {
  for (final t in _banned) {
    expect(find.textContaining(t), findsNothing, reason: 'pasif cevrimdisi metni gorunmemeli: $t');
  }
}

void main() {
  setUpAll(loadTestFonts);
  setUp(() => MessageCache.instance = MessageCache.memoryOnly());

  testWidgets('AppGate: ag yokken ust serit/metin YOK (yoklama zamanlayicisi da yok)', (tester) async {
    useScreen(tester, kPhoneMedium);
    final be = FakeBackend()..offline = true;
    final s = makeSession(be);
    await tester.pumpWidget(buildApp(AppGate(api: s.api, child: const Scaffold(body: Text('icerik')))));
    await settle(tester, const Duration(seconds: 2));
    expect(find.text('icerik'), findsOneWidget);
    expectSilent();
    // 20 sn'lik yoklama kalktı: sure ilerleyince ek /status istegi gitmez
    final before = be.requests.length;
    await tester.pump(const Duration(seconds: 45));
    expect(be.requests.length, before);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Sohbet listesi: ag yokken kayitli liste SESSIZCE gorunur (serit/hata yok)', (tester) async {
    useScreen(tester, kPhoneMedium);
    MessageCache.instance.saveConversations([
      {
        'id': 7,
        'type': 'DIRECT',
        'title': 'Ali Veli',
        'peer': {'id': 11, 'displayName': 'Ali Veli'},
        'unreadCount': 5,
        'lastMessage': {'id': 3, 'conversationId': 7, 'senderId': 11, 'text': 'kayitli son mesaj', 'createdAt': DateTime.now().toUtc().toIso8601String()},
      }
    ]);
    final be = FakeBackend()..offline = true;
    final s = makeSession(be);
    await tester.pumpWidget(buildApp(ChatTab(session: s, connectRealtime: false), size: kPhoneMedium));
    await settle(tester, const Duration(milliseconds: 800));
    expect(find.textContaining('kayitli son mesaj'), findsOneWidget);
    expect(find.textContaining('Yüklenemedi'), findsNothing);
    expect(find.textContaining('Sunucuya ulaşılamadı'), findsNothing);
    expectSilent();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Sohbet listesi: kayit YOK ve ag yok -> mevcut hata ekrani (yeniden dene) kalir', (tester) async {
    useScreen(tester, kPhoneMedium);
    final be = FakeBackend()..offline = true;
    final s = makeSession(be);
    await tester.pumpWidget(buildApp(ChatTab(session: s, connectRealtime: false), size: kPhoneMedium));
    await settle(tester, const Duration(milliseconds: 800));
    expect(find.textContaining('Yeniden dene'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Ana sayfa: onbellekten gelen veri varken serit/Son guncelleme etiketi yok', (tester) async {
    useScreen(tester, kPhoneMedium);
    final be = FakeBackend();
    final s = makeSession(be);
    await tester.pumpWidget(buildApp(Scaffold(body: HomeTab(session: s, onOpenTab: (_, {newsType}) {})), size: kPhoneMedium));
    await settle(tester, const Duration(seconds: 1));
    be.offline = true;
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(buildApp(Scaffold(body: HomeTab(session: s, onOpenTab: (_, {newsType}) {})), size: kPhoneMedium));
    await settle(tester, const Duration(seconds: 1));
    expectSilent();
    await tester.pumpWidget(const SizedBox());
  });
}
