import 'dart:convert';
import 'dart:io';

import 'package:bu_kampus/core/permissions/permission_service.dart';
import 'package:bu_kampus/features/scan/scan_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

// App Review 5.1.1(iv): izin oncesi ekranlarda dugme "Devam/Continue/Next" olmali, "Izin ver/Allow" olmamali.
void main() {
  final bad = RegExp(r'izin ver|allow|grant|enable|السماح|منح|سماح', caseSensitive: false);
  final keys = ['permAllow', 'permContinue', 'qrGrantCamera', 'p67AttachGrant', 'chatMiscContactsPermAction'];

  for (final lg in ['tr', 'en', 'ar']) {
    test('ARB $lg: izin dugmelerinde yonlendirici ifade yok', () {
      final m = jsonDecode(File('lib/l10n/app_$lg.arb').readAsStringSync()) as Map<String, dynamic>;
      for (final k in keys) {
        expect(bad.hasMatch(m[k] as String), isFalse, reason: '$lg/$k = ${m[k]}');
      }
      expect(bad.hasMatch(m['permPageIntro'] as String), isFalse, reason: '$lg/permPageIntro');
    });
  }

  testWidgets('QR tara: kamera gerekce sayfasinda dugme Devam', (tester) async {
    final perms = FakePermissionService(
      initial: {AppPermission.camera: PermState.denied},
      onRequest: {AppPermission.camera: PermState.denied},
    );
    useScreen(tester, kPhoneMedium);
    await tester.pumpWidget(buildApp(
      QrScanHubPage(
          session: makeSession(FakeBackend()), permissionService: perms, scannerBuilder: (ctx, _) => const ColoredBox(color: Color(0xFF222222))),
      size: kPhoneMedium,
    ));
    await settle(tester, const Duration(milliseconds: 500));
    expect(find.text('Devam'), findsOneWidget);
    expect(find.text('İzin ver'), findsNothing);
    expect(find.text('Kamera izni ver'), findsNothing);
  });
}
