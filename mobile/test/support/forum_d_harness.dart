import 'package:bu_kampus/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Açılan rota adlarını kaydeder (gerçek ekran MB-B/MB-C birleşince de geçerli kalan testler için:
/// `openTopicDetail` yer tutucu da olsa gerçek sayfa da olsa rota adı `forum_topic`tir).
class RouteLog extends NavigatorObserver {
  final List<String?> names = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    names.add(route.settings.name);
  }

  int count(String name) => names.where((n) => n == name).length;
}

/// MB-D testleri için uygulama sarmalayıcı: gerçek tema, açık/koyu, yazı ölçeği, rota gözlemcisi.
Widget forumDApp(
  Widget home, {
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  RouteLog? log,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: BuTheme.light(),
    darkTheme: BuTheme.dark(),
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    navigatorObservers: [if (log != null) log],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: home,
  );
}

/// Sayfaya yazı yazar (BuSearchField içindeki TextField).
Future<void> typeInto(WidgetTester tester, Key fieldKey, String text) async {
  await tester.enterText(find.descendant(of: find.byKey(fieldKey), matching: find.byType(TextField)), text);
}

/// Taşma/istisna yok mu?
void expectNoException(WidgetTester tester) {
  final e = tester.takeException();
  if (e != null) fail('Istisna: ${e.toString().split('\n').take(25).join('\n')}');
}
