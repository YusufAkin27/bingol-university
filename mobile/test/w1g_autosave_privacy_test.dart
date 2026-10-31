// W1-G / T-091: "Fotoğrafları galeriye kaydet" anahtarı CANLI Profil > Gizlilik ve veriler sayfasındadır
// (eski yeri ulaşılamayan SettingsPage'ti); varsayılan KAPALI, açarken rıza metni, kapatmak onaysız.
import 'package:bu_kampus/features/chat/photo_autosave.dart';
import 'package:bu_kampus/features/profile/privacy_data_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

FakeBackend _backend() => FakeBackend()
  ..on('/users/me/privacy', {
    'avatar': 'EVERYONE',
    'bio': 'EVERYONE',
    'department': 'EVERYONE',
    'faculty': 'EVERYONE',
    'classYear': 'EVERYONE',
    'avatarHiddenByModeration': false,
  })
  ..on('/users/me', {'id': 1, 'showEmail': false, 'language': 'tr'});

bool _switchOn(WidgetTester t) {
  final sw = find.descendant(of: find.byKey(const ValueKey('privacy-save-gallery-switch')), matching: find.byType(Switch));
  return t.widget<Switch>(sw).value;
}

void main() {
  setUpAll(loadTestFonts);

  testWidgets('anahtar canlı gizlilik sayfasında; yeni kurulumda KAPALI; açarken rıza, vazgeçilirse kapalı kalır', (tester) async {
    useScreen(tester, kPhoneMedium);
    final auto = PhotoAutoSave(store: MemoryAutoSaveStore(), supported: true);
    PhotoAutoSave.instance = auto;
    await tester.pumpWidget(buildApp(PrivacyDataPage(session: makeSession(_backend())), size: kPhoneMedium));
    await settle(tester);
    final key = find.byKey(const ValueKey('privacy-save-gallery-switch'));
    await tester.scrollUntilVisible(key, 300);
    await tester.pump();
    expect(key, findsOneWidget);
    expect(find.text('Fotoğrafları galeriye kaydet'), findsOneWidget);
    expect(_switchOn(tester), isFalse, reason: 'varsayılan KAPALI');
    expect(await auto.enabled(), isFalse);

    // Aç -> rıza sayfası; "Vazgeç" -> kapalı kalır.
    await tester.tap(key);
    await settle(tester);
    expect(find.text('Fotoğraflar galeriye kaydedilsin mi?'), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await settle(tester);
    expect(_switchOn(tester), isFalse);
    expect(await auto.enabled(), isFalse);

    // Aç -> rıza ver -> açık; kayıt cihaza yazıldı.
    await tester.tap(key);
    await settle(tester);
    await tester.tap(find.text('Aç'));
    await settle(tester);
    expect(_switchOn(tester), isTrue);
    expect(await auto.enabled(), isTrue);

    // Kapat: onaysız.
    await tester.tap(key);
    await settle(tester);
    expect(find.text('Fotoğraflar galeriye kaydedilsin mi?'), findsNothing);
    expect(_switchOn(tester), isFalse);
    expect(await auto.enabled(), isFalse);
    await unmount(tester);
  });

  testWidgets('daha önce açıkça açılmış kullanıcıda anahtar AÇIK görünür', (tester) async {
    useScreen(tester, kPhoneMedium);
    PhotoAutoSave.instance = PhotoAutoSave(store: MemoryAutoSaveStore({'enabled': true, 'since': 1}), supported: true);
    await tester.pumpWidget(buildApp(PrivacyDataPage(session: makeSession(_backend())), size: kPhoneMedium));
    await settle(tester);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('privacy-save-gallery-switch')), 300);
    await tester.pump();
    expect(_switchOn(tester), isTrue);
    await unmount(tester);
  });
}
