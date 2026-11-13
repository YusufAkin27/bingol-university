import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:bu_kampus/widgets/bu_dirty_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(bool Function() dirty, {bool busy = false}) => MaterialApp(
      theme: BuTheme.light(),
      locale: const Locale('tr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(
        builder: (c) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(c).push(MaterialPageRoute<void>(
                builder: (_) => BuDirtyGuard(dirty: dirty, busy: busy, child: const Scaffold(body: Text('FORM'))),
              )),
              child: const Text('ac'),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('degisiklik yokken geri onaysiz kapanir', (t) async {
    await t.pumpWidget(_app(() => false));
    await t.tap(find.text('ac'));
    await t.pumpAndSettle();
    expect(find.text('FORM'), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.text('FORM'), findsNothing);
  });

  testWidgets('degisiklik varken geri onay ister; vazgec formda tutar, at kapatir', (t) async {
    await t.pumpWidget(_app(() => true));
    await t.tap(find.text('ac'));
    await t.pumpAndSettle();
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.text('FORM'), findsOneWidget, reason: 'onay sorulmadan kapanmamali');
    await t.tap(find.text('Düzenlemeye devam'));
    await t.pumpAndSettle();
    expect(find.text('FORM'), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    await t.tap(find.text('At'));
    await t.pumpAndSettle();
    expect(find.text('FORM'), findsNothing);
  });

  testWidgets('kayit surerken geri jesti yutulur', (t) async {
    await t.pumpWidget(_app(() => false, busy: true));
    await t.tap(find.text('ac'));
    await t.pumpAndSettle();
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.text('FORM'), findsOneWidget);
    expect(find.text('At'), findsNothing);
  });
}
