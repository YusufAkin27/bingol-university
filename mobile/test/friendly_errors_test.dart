import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/features/system/error_views.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'redesign/p00_support.dart';
import 'support/fake_app.dart';

void main() {
  setUpAll(loadTestFonts);

  test(
      'release defaults to the production HTTPS address; insecure overrides remain blocked',
      () {
    expect(productionApiOrigin, 'https://bukampus.com.tr');
    expect(apiConfigValid(origin: productionApiOrigin, release: true), isTrue);
    expect(
        apiConfigValid(origin: developmentApiOrigin, release: true), isFalse);
  });

  test('technical API details never reach direct message readers', () {
    for (final message in [
      'API_BASE=http://10.0.2.2:8080',
      'java.sql.SQLException: jdbc:postgresql://db/private',
      'SocketException: connection refused',
      'HandshakeException: certificate validation failed',
      '<html><body>nginx upstream failure</body></html>',
      'PlatformException(channel-error, no connection)',
    ]) {
      final e = ApiError(400, 'UNKNOWN', message);
      expect(e.message, isEmpty);
      expect(errorText(e), isNot(contains(message)));
    }
    expect(
        ApiError(500, 'UNKNOWN', 'internal database detail').message, isEmpty);
    expect(
        ApiError(400, 'VALIDATION_ERROR', 'Ad en az 3 karakter olmalı.')
            .message,
        'Ad en az 3 karakter olmalı.');
  });

  test(
      'maintenance, server errors and invalid responses have localized actionable messages',
      () {
    for (final lang in ['tr', 'en', 'ar']) {
      final l = lookupAppLocalizations(Locale(lang));
      for (final error in [
        ApiError(500, 'HTTP_500', 'raw'),
        ApiError(502, 'UPSTREAM_ERROR', 'raw'),
        ApiError(0, 'BAD_RESPONSE', 'FormatException: invalid JSON'),
        ApiError(0, 'CONFIG_ERROR', 'API_BASE invalid')
      ]) {
        expect(knownErrorText(error, l), l.coreErrServiceUnavailable);
      }
      expect(knownErrorText(ApiError(503, 'MAINTENANCE', 'raw'), l),
          l.sistemuiMaintBody);
      expect(knownErrorText(ApiError(503, 'DB_TIMEOUT', 'raw'), l),
          l.errServiceBusy);
    }
    expect(errorText(ApiError(0, 'BAD_RESPONSE', '')),
        isNot(contains('İnternet')));
  });

  for (final lang in ['tr', 'en', 'ar']) {
    testWidgets(
        'configuration screen is user friendly at small width and large text $lang',
        (tester) async {
      useScreen(tester, const Size(320, 568));
      await tester.pumpWidget(p00App(
          const ConfigErrorView(origin: 'http://10.0.2.2:8080/private'),
          lang: lang,
          scale: 2,
          scaffold: false));
      await settle(tester);
      final l = lookupAppLocalizations(Locale(lang));
      expect(find.text(l.p01ConfigTitle), findsOneWidget);
      expect(find.text(l.p01ConfigBody), findsOneWidget);
      final rendered = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .join(' ');
      for (final technical in [
        'API_BASE',
        '10.0.2.2',
        'http://',
        'derleyin',
        'Rebuild',
        'monospace'
      ]) {
        expect(rendered, isNot(contains(technical)));
      }
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }

  testWidgets(
      'invalid server response is not presented as lost internet; maintenance uses its own heading',
      (tester) async {
    useScreen(tester, const Size(390, 700));
    final l = lookupAppLocalizations(const Locale('tr'));
    await tester.pumpWidget(buildApp(Scaffold(
        body: BuErrorState(
      error: ApiError(0, 'BAD_RESPONSE', 'FormatException'),
      onRetry: () {},
    ))));
    await settle(tester);
    expect(find.text(l.sistemuiOfflineTitle), findsNothing);
    expect(find.text(l.coreErrServiceUnavailable), findsOneWidget);
    await tester.pumpWidget(buildApp(Scaffold(
        body: BuErrorState(
      error: ApiError(503, 'MAINTENANCE', ''),
      onRetry: () {},
    ))));
    await settle(tester);
    expect(find.text(l.sistemuiMaintTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}
