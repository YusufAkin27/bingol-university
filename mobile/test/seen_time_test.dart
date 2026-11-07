import 'package:bu_kampus/core/relative_time.dart';
import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/features/chat/message_bubble.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 11, 7, 12);
DateTime _ago(Duration d) => _now.subtract(d);

void main() {
  test('RelAge esikleri', () {
    RelAge a(Duration d) => RelAge.between(_ago(d), _now);
    expect(a(const Duration(seconds: 59)).unit, RelUnit.now);
    expect((a(const Duration(minutes: 1)).unit, a(const Duration(minutes: 1)).n), (RelUnit.minutes, 1));
    expect(a(const Duration(minutes: 59)).n, 59);
    expect((a(const Duration(minutes: 60)).unit, a(const Duration(minutes: 60)).n), (RelUnit.hours, 1));
    expect(a(const Duration(hours: 23, minutes: 59)).n, 23);
    expect((a(const Duration(hours: 24)).unit, a(const Duration(hours: 24)).n), (RelUnit.days, 1));
    expect(a(const Duration(days: 6)).n, 6);
    expect((a(const Duration(days: 7)).unit, a(const Duration(days: 7)).n), (RelUnit.weeks, 1));
    expect((a(const Duration(days: 28)).unit, a(const Duration(days: 28)).n), (RelUnit.weeks, 4));
    expect((a(const Duration(days: 29)).unit, a(const Duration(days: 29)).n), (RelUnit.weeks, 4));
    expect((a(const Duration(days: 30)).unit, a(const Duration(days: 30)).n), (RelUnit.months, 1));
    expect((a(const Duration(days: 364)).unit, a(const Duration(days: 364)).n), (RelUnit.months, 11));
    expect((a(const Duration(days: 365)).unit, a(const Duration(days: 365)).n), (RelUnit.years, 1));
    expect(a(const Duration(days: 800)).n, 2);
    // Gelecek/saat dilimi: UTC ile yerel ayni ani temsil eder.
    expect(RelAge.between(_ago(const Duration(minutes: 25)).toLocal(), _now).n, 25);
    expect(RelAge.between(_now.add(const Duration(minutes: 5)), _now).unit, RelUnit.now);
  });

  Future<String> ago(Locale loc, Duration d) async {
    final l = await AppLocalizations.delegate.load(loc);
    return relativeAgo(l, _ago(d), now: _now);
  }

  test('tr', () async {
    const tr = Locale('tr');
    expect(await ago(tr, const Duration(minutes: 25)), '25 dakika önce');
    expect(await ago(tr, const Duration(hours: 1)), '1 saat önce');
    expect(await ago(tr, const Duration(days: 1)), '1 gün önce');
    expect(await ago(tr, const Duration(days: 5)), '5 gün önce');
    expect(await ago(tr, const Duration(days: 7)), '1 hafta önce');
    expect(await ago(tr, const Duration(days: 28)), '4 hafta önce');
    expect(await ago(tr, const Duration(days: 31)), '1 ay önce');
    expect(await ago(tr, const Duration(days: 400)), '1 yıl önce');
    expect(await ago(tr, const Duration(seconds: 10)), 'az önce');
  });

  test('en tekil/cogul', () async {
    const en = Locale('en');
    expect(await ago(en, const Duration(minutes: 1)), '1 minute ago');
    expect(await ago(en, const Duration(minutes: 25)), '25 minutes ago');
    expect(await ago(en, const Duration(hours: 1)), '1 hour ago');
    expect(await ago(en, const Duration(days: 5)), '5 days ago');
    expect(await ago(en, const Duration(days: 14)), '2 weeks ago');
    expect(await ago(en, const Duration(days: 60)), '2 months ago');
    expect(await ago(en, const Duration(days: 365)), '1 year ago');
  });

  test('ar cogul bicimleri', () async {
    const ar = Locale('ar');
    expect(await ago(ar, const Duration(minutes: 1)), 'منذ دقيقة واحدة');
    expect(await ago(ar, const Duration(minutes: 2)), 'منذ دقيقتين');
    expect(await ago(ar, const Duration(minutes: 5)), 'منذ 5 دقائق');
    expect(await ago(ar, const Duration(minutes: 25)), 'منذ 25 دقيقة');
    expect(await ago(ar, const Duration(days: 365)), 'منذ سنة واحدة');
  });

  Widget bubble(Locale loc, {DateTime? seenAt, double width = 320, String status = 'seen'}) => MaterialApp(
        theme: BuTheme.light(),
        locale: loc,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, 800), textScaler: const TextScaler.linear(1.3)),
          child: Scaffold(
            body: SizedBox(
              width: width,
              child: MessageBubble(
                message: {
                  'id': 5,
                  'conversationId': 1,
                  'senderId': 1,
                  'text': 'merhaba',
                  'status': 'READ',
                  'createdAt': DateTime.now().toUtc().toIso8601String(),
                },
                mine: true,
                statusLine: status,
                seenAt: seenAt,
                senderName: null,
                replyName: null,
                authHeaders: const {},
                onMenu: () {},
                onRetry: () {},
                onOpenImage: (_) {},
                onReact: (_) {},
              ),
            ),
          ),
        ),
      );

  testWidgets('StatusLine: zamanli', (tester) async {
    await tester.pumpWidget(bubble(const Locale('tr'), seenAt: DateTime.now().subtract(const Duration(minutes: 25))));
    await tester.pumpAndSettle();
    expect(find.text('Görüldü · 25 dakika önce'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Zamanlayici temizligi
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('StatusLine: zamansiz yalin', (tester) async {
    await tester.pumpWidget(bubble(const Locale('tr')));
    await tester.pumpAndSettle();
    expect(find.text('Görüldü'), findsOneWidget);
  });

  testWidgets('StatusLine: Gonderildi degismez', (tester) async {
    await tester.pumpWidget(bubble(const Locale('tr'), status: 'sent', seenAt: DateTime.now()));
    await tester.pumpAndSettle();
    expect(find.text('Gönderildi'), findsOneWidget);
  });

  testWidgets('StatusLine: RTL 320dp tasma yok', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(bubble(const Locale('ar'), seenAt: DateTime.now().subtract(const Duration(days: 400))));
    await tester.pumpAndSettle();
    expect(find.text('تمت المشاهدة · منذ سنة واحدة'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
