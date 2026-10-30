import 'dart:typed_data';

import 'package:bu_kampus/features/clubs/club_form_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'support/fake_app.dart';

/// K7: kulup formunda logo (1:1) ve kapak (16:9) secimi kirpma akisina bagli: kaynak sayfasi -> kirp -> onizleme;
/// "Fotografi kaldir"; kismi kayit (yukleme uclari bozulmadan) ve var olan logonun silinmesi.
Uint8List _jpeg() => Uint8List.fromList(img.encodeJpg(img.Image(width: 400, height: 300), quality: 80));

Future<Uint8List?> _pick(source) async => _jpeg();

Future<void> _pump(WidgetTester tester, Widget w) async {
  useScreen(tester, const Size(390, 1400));
  // Form bir rotaya itilir: kayit sonrasi Navigator.pop gercek akistaki gibi calisir.
  await tester.pumpWidget(buildApp(
      Builder(
        builder: (c) => Scaffold(
          body: TextButton(key: const ValueKey('open'), onPressed: () => Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => w)), child: const Text('ac')),
        ),
      ),
      size: const Size(390, 1400)));
  await tester.tap(find.byKey(const ValueKey('open')));
  await settle(tester, const Duration(milliseconds: 900));
}

/// Kirpma sayfasinda "Kirp"a basar ve sayfa kapanana dek bekler (kesme isolate'ta calisir).
Future<void> _cropAndSave(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
  await tester.pump(const Duration(milliseconds: 400));
  expect(find.byKey(const ValueKey('cropSave')), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('cropSave')));
  await tester.pump();
  for (var i = 0; i < 60 && find.byKey(const ValueKey('cropSave')).evaluate().isNotEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  await settle(tester, const Duration(milliseconds: 600));
}

FakeBackend _be() => FakeBackend()..on('/communities/categories', <Object>[]);

void main() {
  testWidgets('kapak: kaynak sayfasi -> 16:9 kirp -> "Kapagi degistir"; kaldir yalniz secilen gorseli geri alir', (tester) async {
    await _pump(tester, ClubFormPage(session: makeSession(_be()), cropPicker: _pick));
    await tester.tap(find.text('Kapak ekle (isteğe bağlı)'));
    await settle(tester, const Duration(milliseconds: 700));
    expect(find.text('Galeriden seç'), findsOneWidget);
    expect(find.text('Fotoğraf çek'), findsOneWidget);
    expect(find.text('Fotoğrafı kaldır'), findsNothing); // henüz görsel yok
    await tester.tap(find.text('Galeriden seç'));
    await tester.pump();
    await _cropAndSave(tester);
    expect(find.text('Kapağı değiştir'), findsOneWidget); // seçilen kapak önizlemede

    await tester.tap(find.text('Kapağı değiştir'));
    await settle(tester, const Duration(milliseconds: 700));
    expect(find.text('Fotoğrafı kaldır'), findsOneWidget);
    await tester.tap(find.text('Fotoğrafı kaldır'));
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.text('Kapak ekle (isteğe bağlı)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('logo: 1:1 kirpma basligi, secilince degistir/kaldir, kaldirinca "Logo ekle" geri gelir', (tester) async {
    await _pump(tester, ClubFormPage(session: makeSession(_be()), cropPicker: _pick));
    await tester.tap(find.text('Logo ekle').first);
    await settle(tester, const Duration(milliseconds: 700));
    await tester.tap(find.text('Galeriden seç'));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Kulüp logosu'), findsOneWidget); // 1:1 logo kırpma sayfası
    await _cropAndSave(tester);
    expect(find.text('Logo ekle'), findsNothing); // logo seçildi

    final sem = tester.ensureSemantics();
    await tester.tap(find.bySemanticsLabel('Logoyu değiştir'));
    await settle(tester, const Duration(milliseconds: 700));
    await tester.tap(find.text('Fotoğrafı kaldır'));
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.text('Logo ekle'), findsWidgets);
    sem.dispose();
  });

  testWidgets('kapak/logo yukleme basarisiz olursa kulup kaydedilir, kismi kayit uyarisi gorunur', (tester) async {
    // MultipartUploader gercek ag kullanir; testte ag kapali -> yukleme basarisiz (kismi kayit yolu).
    final be = _be()..on('/communities', {'id': 9, 'status': 'ACTIVE'}, status: 201);
    await _pump(tester, ClubFormPage(session: makeSession(be), cropPicker: _pick));
    await tester.tap(find.text('Kapak ekle (isteğe bağlı)'));
    await settle(tester, const Duration(milliseconds: 700));
    await tester.tap(find.text('Galeriden seç'));
    await tester.pump();
    await _cropAndSave(tester);
    await tester.enterText(find.byType(TextField).first, 'Yeni Kulüp');
    await tester.ensureVisible(find.text('Kulübü oluştur'));
    await tester.tap(find.text('Kulübü oluştur'));
    for (var i = 0; i < 40 && find.text('Kısmi kayıt uyarısı').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(be.requests, contains('POST /communities'));
    expect(find.text('Kısmi kayıt uyarısı'), findsOneWidget);
    expect(find.text('Yeniden dene'), findsOneWidget);
    expect(find.text('Kaydet'), findsOneWidget); // kulüp artık var: düzenleme kipine geçti
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('var olan logo "kaldir" ile silinir: kayitta DELETE /communities/7/logo', (tester) async {
    final be = _be()
      ..on('/communities/7/join-questions', <Object>[])
      ..on('/communities/7', {'ok': true});
    final club = {
      'id': 7,
      'name': 'Robotik Kulübü',
      'description': 'Açıklama',
      'visibility': 'PUBLIC',
      'joinPolicy': 'OPEN',
      'logoUrl': '/files/logo.png',
    };
    await _pump(tester, ClubFormPage(session: makeSession(be), club: club, cropPicker: _pick));
    final sem = tester.ensureSemantics();
    await tester.tap(find.bySemanticsLabel('Logoyu değiştir'));
    await settle(tester, const Duration(milliseconds: 700));
    expect(find.text('Fotoğrafı kaldır'), findsOneWidget); // var olan logo için de kaldırılabilir
    await tester.tap(find.text('Fotoğrafı kaldır'));
    await settle(tester, const Duration(milliseconds: 600));
    expect(find.text('Logo ekle'), findsWidgets);
    sem.dispose();
    await tester.ensureVisible(find.text('Kaydet'));
    await tester.tap(find.text('Kaydet'));
    await settle(tester, const Duration(seconds: 1));
    expect(be.requests, contains('DELETE /communities/7/logo'));
    expect(be.requests, contains('PATCH /communities/7'));
  });
}
