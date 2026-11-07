import 'package:bu_kampus/core/theme.dart';
import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/chat/chat_tab.dart';
import 'package:bu_kampus/features/clubs/clubs_tab.dart';
import 'package:bu_kampus/features/discover/discover_tab.dart';
import 'package:bu_kampus/features/home/home_tab.dart';
import 'package:bu_kampus/features/menu/menu_page.dart';
import 'package:bu_kampus/features/profile/profile_tab.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'fake_app.dart';

/// Ana ekranlar (ana sayfa, kesfet, sohbet, kulupler, yemek, profil).
final Map<String, Widget Function(FakeBackend)> a11yScreens = {
  'Ana sayfa': (b) => Scaffold(body: HomeTab(session: makeSession(b), onOpenTab: (i, {newsType}) {})),
  'Kesfet': (b) => DiscoverTab(session: makeSession(b), typeRequest: ValueNotifier<String?>(null)),
  'Sohbet': (b) => ChatTab(session: makeSession(b), connectRealtime: false),
  'Kulupler': (b) => ClubsTab(session: makeSession(b)),
  'Yemek': (b) => MenuPage(session: makeSession(b)),
  'Profil': (b) => ProfileTab(session: makeSession(b), themeController: ThemeController()),
};

/// Yerel ayar + yazi olcegi ile uygulama (l10n delegeleri dahil).
Widget a11yApp(Widget home, {required String lang, required double scale, required Size size}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: Locale(lang),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: BuTheme.light(),
    home: home,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(size: size, textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
  );
}
