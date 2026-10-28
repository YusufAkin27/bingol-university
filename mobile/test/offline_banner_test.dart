import 'package:bu_kampus/core/connectivity/connectivity_service.dart';
import 'package:bu_kampus/core/connectivity/offline_banner.dart';
import 'package:bu_kampus/core/outbox/outbox.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child, {Locale locale = const Locale('tr')}) => MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: BuTheme.light(),
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('bekleyen mesaj yoksa serit yok; varsa cevrimdisi metni, bagli ise gonderiliyor', (tester) async {
    final ob = Outbox(store: MemoryOutboxStore(), autoSchedule: false);
    final cs = ConnectivityService();
    await tester.pumpWidget(host(OfflineBanner(outbox: ob, connectivity: cs, child: const Text('icerik'))));
    expect(find.text('icerik'), findsOneWidget);
    expect(find.textContaining('mesaj'), findsNothing);

    cs.reportFailure();
    ob.enqueue(conversationId: 1, clientId: 'a', text: 'x');
    ob.enqueue(conversationId: 1, clientId: 'b', text: 'y');
    await tester.pump();
    expect(find.text('2 mesaj bağlantı gelince gönderilecek'), findsOneWidget);
    expect(find.text('icerik'), findsOneWidget);

    cs.reportSuccess();
    await tester.pump();
    expect(find.text('2 mesaj gönderiliyor…'), findsOneWidget);
    ob.dispose();
  });

  testWidgets('StaleLabel yalniz cachedAt varsa gorunur; AR/EN metin uretir', (tester) async {
    await tester.pumpWidget(host(const StaleLabel(cachedAt: null)));
    expect(find.byType(Text), findsNothing);
    await tester.pumpWidget(host(StaleLabel(cachedAt: DateTime(2026, 10, 28, 9, 5)), locale: const Locale('en')));
    expect(find.textContaining('Last updated'), findsOneWidget);
    await tester.pumpWidget(host(StaleLabel(cachedAt: DateTime(2026, 10, 28, 9, 5)), locale: const Locale('tr')));
    expect(find.textContaining('Son güncelleme'), findsOneWidget);
  });
}
