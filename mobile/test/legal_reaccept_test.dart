import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/features/auth/widgets/auth_ref.dart';
import 'package:bu_kampus/features/legal/legal_reaccept.dart';
import 'package:bu_kampus/features/legal/legal_reaccept_page.dart';
import 'package:bu_kampus/features/profile/legal_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

const _status = '/legal/acceptance-status';

Map<String, dynamic> _pending({bool enforced = true}) => {
      'requiresAcceptance': [
        {'type': 'TERMS', 'version': 3},
        {'type': 'PRIVACY', 'version': 2},
      ],
      'enforced': enforced,
    };

Widget _gate(Session s) => buildApp(LegalReacceptGate(session: s, child: const Scaffold(body: Center(child: Text('KABUK')))));

void main() {
  setUpAll(loadTestFonts);

  group('LegalReacceptController', () {
    test('bekleyen belge varsa durum dolar (enforced bayragiyla)', () async {
      final b = FakeBackend()..on(_status, _pending());
      final s = makeSession(b);
      await s.legal.check(userId: 1);
      expect(s.legal.current, isNotNull);
      expect(s.legal.current!.enforced, isTrue);
      expect(s.legal.current!.items, [const LegalItem('TERMS', 3), const LegalItem('PRIVACY', 2)]);
    });

    test('bos liste: kapi acilmaz', () async {
      final b = FakeBackend()..on(_status, {'requiresAcceptance': [], 'enforced': true});
      final s = makeSession(b);
      await s.legal.check(userId: 1);
      expect(s.legal.current, isNull);
    });

    test('ag hatasi ve 5xx: kapi acilmaz, onceki durum korunur (kullanici kilitlenmez)', () async {
      final b = FakeBackend()..network(_status);
      final s = makeSession(b);
      await s.legal.check(userId: 1);
      expect(s.legal.current, isNull);
      b.fail(_status, status: 503, code: 'MAINTENANCE');
      await s.legal.check(userId: 1);
      expect(s.legal.current, isNull);
      // Önceden açılmış kapı geçici hatada kapanmaz
      b.on(_status, _pending());
      await s.legal.check(userId: 1);
      expect(s.legal.current, isNotNull);
      b.network(_status);
      await s.legal.check(userId: 1);
      expect(s.legal.current, isNotNull);
    });

    test('enforced=false: Daha sonra ayni surum kumesi icin bir daha gosterilmez, yeni surumde gelir', () async {
      final b = FakeBackend()..on(_status, _pending(enforced: false));
      final s = makeSession(b);
      await s.legal.check(userId: 41);
      expect(s.legal.current, isNotNull);
      expect(s.legal.current!.enforced, isFalse);
      await s.legal.defer();
      expect(s.legal.current, isNull);
      await s.legal.check(userId: 41);
      expect(s.legal.current, isNull);
      b.on(_status, {
        'requiresAcceptance': [
          {'type': 'TERMS', 'version': 4}
        ],
        'enforced': false,
      });
      await s.legal.check(userId: 41);
      expect(s.legal.current, isNotNull);
    });

    test('enforced=true iken Daha sonra yok sayilir', () async {
      final b = FakeBackend()..on(_status, _pending());
      final s = makeSession(b);
      await s.legal.check(userId: 1);
      await s.legal.defer();
      expect(s.legal.current, isNotNull);
    });

    test('kabul: POST /legal/accept tur+surum listesi, basarida durum temizlenir', () async {
      final b = FakeBackend()
        ..on(_status, _pending())
        ..on('/legal/accept', null, status: 204);
      final s = makeSession(b);
      await s.legal.check(userId: 1);
      await s.legal.accept();
      expect(b.bodies['POST /legal/accept'], {
        'items': [
          {'type': 'TERMS', 'version': 3},
          {'type': 'PRIVACY', 'version': 2},
        ],
      });
      expect(s.legal.current, isNull);
    });

    test('kabul hatasi (VERSION_OUTDATED): hata iletilir, liste sunucudan yenilenir', () async {
      final b = FakeBackend()
        ..on(_status, _pending())
        ..fail('/legal/accept', status: 409, code: 'VERSION_OUTDATED', message: 'eski');
      final s = makeSession(b);
      await s.legal.check(userId: 1);
      b.on(_status, {
        'requiresAcceptance': [
          {'type': 'TERMS', 'version': 4}
        ],
        'enforced': true,
      });
      await expectLater(s.legal.accept(), throwsA(isA<ApiError>()));
      expect(s.legal.current!.items, [const LegalItem('TERMS', 4)]);
    });

    test('herhangi bir yazma isteginde 403 LEGAL_REACCEPT_REQUIRED: engelleyici ekran durumu acilir', () async {
      final b = FakeBackend()
        ..on('/posts', {
          'code': 'LEGAL_REACCEPT_REQUIRED',
          'message': 'Sözleşmeler güncellendi.',
          'requiresAcceptance': [
            {'type': 'KVKK', 'version': 5}
          ],
        }, status: 403);
      final s = makeSession(b);
      expect(s.legal.current, isNull);
      await expectLater(s.api.post('/posts', {'x': 1}), throwsA(isA<ApiError>()));
      expect(s.legal.current, isNotNull);
      expect(s.legal.current!.enforced, isTrue);
      expect(s.legal.current!.items, [const LegalItem('KVKK', 5)]);
    });

    test('cikis: durum temizlenir', () async {
      final b = FakeBackend()..on(_status, _pending());
      final s = makeSession(b);
      await s.legal.check(userId: 1);
      await s.signOut(remote: false);
      expect(s.legal.current, isNull);
    });
  });

  group('LegalReacceptGate / sayfa', () {
    testWidgets('bekleyen belge yok: kabuk gorunur, ekran yok', (tester) async {
      final b = FakeBackend()..on(_status, {'requiresAcceptance': [], 'enforced': false});
      await tester.pumpWidget(_gate(makeSession(b)));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.text('KABUK'), findsOneWidget);
      expect(find.byType(LegalReacceptPage), findsNothing);
      await unmount(tester);
    });

    testWidgets('durum istegi basarisiz: kabuk acik kalir (kilitlenme yok)', (tester) async {
      final b = FakeBackend()..network(_status);
      await tester.pumpWidget(_gate(makeSession(b)));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.byType(LegalReacceptPage), findsNothing);
      expect(find.text('KABUK'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('enforced: ekran acilir, Daha sonra yok, onay kutusu isaretlenmeden Kabul et pasif; kabul kapatir',
        (tester) async {
      useScreen(tester, const Size(390, 1400));
      final b = FakeBackend()
        ..on(_status, _pending())
        ..on('/legal', [
          {'type': 'TERMS', 'version': 3, 'title': 'Kullanım Koşulları'},
          {'type': 'PRIVACY', 'version': 2, 'title': 'Gizlilik Politikası'},
        ])
        ..on('/legal/accept', null, status: 204);
      final s = makeSession(b);
      await tester.pumpWidget(_gate(s));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Sözleşmeler güncellendi'), findsOneWidget);
      expect(find.text('Kullanım Koşulları'), findsOneWidget);
      expect(find.text('Gizlilik Politikası'), findsOneWidget);
      expect(find.text('Daha sonra'), findsNothing);
      expect(find.text('Güncellenen belgeleri okudum ve kabul ediyorum'), findsOneWidget);
      // Açık rıza ayrı: bilgi notu
      expect(find.textContaining('açık rıza'), findsOneWidget);

      final accept = find.widgetWithText(RefButton, 'Kabul et');
      expect(tester.widget<RefButton>(accept).onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('legalReacceptAck')));
      await tester.pump();
      expect(tester.widget<RefButton>(accept).onPressed, isNotNull);
      await tester.tap(accept);
      await settle(tester, const Duration(milliseconds: 400));
      expect(b.count('POST /legal/accept'), 1);
      expect(find.byType(LegalReacceptPage), findsNothing);
      expect(find.text('KABUK'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('belgeye dokununca tam metin sayfasi acilir', (tester) async {
      useScreen(tester, const Size(390, 1400));
      final b = FakeBackend()
        ..on(_status, _pending())
        ..on('/legal', [
          {'type': 'TERMS', 'version': 3, 'title': 'Kullanım Koşulları'},
        ])
        ..on('/legal/TERMS', {'type': 'TERMS', 'version': 3, 'title': 'Kullanım Koşulları', 'content': '# Metin'});
      await tester.pumpWidget(_gate(makeSession(b)));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.tap(find.text('Kullanım Koşulları').first);
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.byType(LegalDocPage), findsOneWidget);
      expect(b.count('GET /legal/TERMS'), 1);
      await unmount(tester);
    });

    testWidgets('enforced=false: Daha sonra ile gecilir', (tester) async {
      useScreen(tester, const Size(390, 1400));
      final b = FakeBackend()..on(_status, _pending(enforced: false));
      final s = makeSession(b);
      await tester.pumpWidget(_gate(s));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Daha sonra'), findsOneWidget);
      await tester.tap(find.text('Daha sonra'));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.byType(LegalReacceptPage), findsNothing);
      expect(find.text('KABUK'), findsOneWidget);
      expect(b.count('POST /legal/accept'), 0);
      await unmount(tester);
    });

    testWidgets('Kabul etmiyorum: bilgi + Hesabimi sil / Cikis yap; cikis oturumu kapatir', (tester) async {
      useScreen(tester, const Size(390, 1400));
      final b = FakeBackend()..on(_status, _pending());
      final s = makeSession(b);
      await tester.pumpWidget(_gate(s));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.ensureVisible(find.text('Kabul etmiyorum'));
      await tester.tap(find.text('Kabul etmiyorum'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Kabul etmeden devam edilemez'), findsOneWidget);
      expect(find.text('Hesabımı sil'), findsOneWidget);
      expect(find.text('Çıkış yap'), findsOneWidget);
      await tester.tap(find.text('Çıkış yap'));
      await settle(tester, const Duration(milliseconds: 400));
      expect(s.state, SessionState.signedOut);
      expect(s.legal.current, isNull);
      await unmount(tester);
    });

    testWidgets('Kabul etmiyorum -> Hesabimi sil mevcut hesap silme sayfasini acar', (tester) async {
      useScreen(tester, const Size(390, 1400));
      final b = FakeBackend()..on(_status, _pending());
      await tester.pumpWidget(_gate(makeSession(b)));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.ensureVisible(find.text('Kabul etmiyorum'));
      await tester.tap(find.text('Kabul etmiyorum'));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.tap(find.text('Hesabımı sil'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Hesabı sil'), findsWidgets);
      await unmount(tester);
    });

    testWidgets('kabul sirasinda VERSION_OUTDATED: hata metni gosterilir, ekran acik kalir', (tester) async {
      useScreen(tester, const Size(390, 1400));
      final b = FakeBackend()
        ..on(_status, _pending())
        ..fail('/legal/accept', status: 409, code: 'VERSION_OUTDATED', message: 'eski');
      await tester.pumpWidget(_gate(makeSession(b)));
      await settle(tester, const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const ValueKey('legalReacceptAck')));
      await tester.pump();
      await tester.tap(find.widgetWithText(RefButton, 'Kabul et'));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.textContaining('yeniden güncellendi'), findsOneWidget);
      expect(find.byType(LegalReacceptPage), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('403 LEGAL_REACCEPT_REQUIRED yakalaninca acik kabukta ekran acilir', (tester) async {
      final b = FakeBackend()
        ..on(_status, {'requiresAcceptance': [], 'enforced': false})
        ..on('/posts', {
          'code': 'LEGAL_REACCEPT_REQUIRED',
          'message': 'x',
          'requiresAcceptance': [
            {'type': 'TERMS', 'version': 3}
          ],
        }, status: 403);
      final s = makeSession(b);
      await tester.pumpWidget(_gate(s));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.byType(LegalReacceptPage), findsNothing);
      await tester.runAsync(() => s.api.post('/posts', {'x': 1}).then<Object?>((_) => null, onError: (Object _) => null));
      await settle(tester, const Duration(milliseconds: 300));
      expect(find.byType(LegalReacceptPage), findsOneWidget);
      expect(find.text('Daha sonra'), findsNothing);
      await unmount(tester);
    });
  });
}
