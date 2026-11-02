@Tags(['hig'])
library;

// HIG denetimi - RAPOR URETEN test (normal paketi bozmaz: HIG=1 olmadan atlanir, hicbir olcum testi kirmaz).
//
// Calistirma (C:\bu_hig ASCII yolundan, Git Bash):
//   HIG=1 HIG_OUT=build/hig_report.json PUB_CACHE='C:\pubcache' \
//     /c/src/flutter/bin/flutter.bat test test/hig/hig_audit_test.dart --tags hig -r expanded
//
// Olcumler (docs/MOBILE_HIG_AUDIT.md b, c, h harfleri):
//   b) androidTapTargetGuideline + labeledTapTargetGuideline + textContrastGuideline, acik ve koyu tema AYRI pump
//   c) yazi olcegi 1.3 ve 2.0, genislik 320/390 dp: RenderFlex tasmasi (tum FlutterError'lar toplanir)
//   h) Arapca (RTL) + olcek 1.0/1.3: tasma / istisna
// Sonuc JSON'a yazilir (HIG_OUT); konsola "HIG|" onekli ozet satirlari basilir.

import 'dart:convert';
import 'dart:io';

import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/academic/academic_hub_page.dart';
import 'package:bu_kampus/features/auth/forgot_password_page.dart';
import 'package:bu_kampus/features/auth/login_page.dart';
import 'package:bu_kampus/features/auth/register_page.dart';
import 'package:bu_kampus/features/auth/welcome_page.dart';
import 'package:bu_kampus/features/chat/chat_tab.dart';
import 'package:bu_kampus/features/chat/new_chat_page.dart';
import 'package:bu_kampus/features/clubs/clubs_tab.dart';
import 'package:bu_kampus/features/discover/discover_tab.dart';
import 'package:bu_kampus/features/events/events_page.dart';
import 'package:bu_kampus/features/home/home_tab.dart';
import 'package:bu_kampus/features/menu/menu_page.dart';
import 'package:bu_kampus/features/news/news_list_page.dart';
import 'package:bu_kampus/features/notifications/notifications_page.dart';
import 'package:bu_kampus/features/polls/poll_list_page.dart';
import 'package:bu_kampus/features/profile/blocked_users_page.dart';
import 'package:bu_kampus/features/profile/my_events_page.dart';
import 'package:bu_kampus/features/profile/profile_tab.dart';
import 'package:bu_kampus/features/profile/settings_page.dart';
import 'package:bu_kampus/features/search/search_page.dart';
import 'package:bu_kampus/features/shell/app_shell.dart';
import 'package:bu_kampus/features/support/support_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../redesign/p00_support.dart';
import '../support/fake_app.dart';

final bool _on = Platform.environment['HIG'] == '1';
final String _out = Platform.environment['HIG_OUT'] ?? 'build/hig_report.json';

String _iso(DateTime d) => d.toUtc().toIso8601String();

/// Ekran tanimi: ad, sahte backend kurulumu, widget uretici.
class _Screen {
  const _Screen(this.name, this.build, {this.signedIn = true, this.scaffold = false});
  final String name;
  final Widget Function(Session s) build;
  final bool signedIn;

  /// true: p00App sayfayi Scaffold ile sarar (sayfanin kendi Scaffold'u yoksa).
  final bool scaffold;
}

FakeBackend _backend() {
  final now = DateTime.now();
  final b = FakeBackend();
  b.on('/news', newsPage([for (var i = 1; i <= 8; i++) newsItem(i, type: i % 3 == 0 ? 'DUYURU' : 'HABER')]));
  b.on('/conversations', {
    'items': [
      for (var i = 1; i <= 4; i++)
        {
          'id': i,
          'type': i == 1 ? 'DIRECT' : (i == 2 ? 'GROUP' : (i == 3 ? 'CLUB' : 'EVENT')),
          'title': ['Ali Veli', 'Proje Grubu', 'Robotik Kulübü', 'Kariyer Günleri'][i - 1],
          if (i == 1) 'peer': {'id': 11, 'displayName': 'Ali Veli'},
          'unreadCount': i == 1 ? 3 : 0,
          'muted': false,
          'lastMessage': {
            'id': 100 + i,
            'conversationId': i,
            'senderId': 10 + i,
            'text': 'Yarın görüşelim mi?',
            'createdAt': _iso(now),
          },
        }
    ],
    'nextCursor': null,
  });
  b.on('/communities*', {
    'items': [
      for (var i = 1; i <= 5; i++)
        {
          'id': i,
          'name': ['Robotik ve Yapay Zekâ', 'Satranç', 'Fotoğrafçılık', 'Tiyatro', 'Girişimcilik'][i - 1],
          'category': 'Teknoloji',
          'memberCount': 12 + i,
          'myStatus': i == 1 ? 'ACTIVE' : 'NONE',
          'joinPolicy': 'OPEN',
        }
    ],
    'nextCursor': null,
  });
  b.on('/events*', {
    'items': [
      for (var i = 1; i <= 4; i++)
        {
          'id': i,
          'source': 'USER',
          'title': 'Kariyer Günleri ve Sektör Buluşması $i',
          'description': 'Açıklama metni',
          'startsAt': _iso(now.add(Duration(days: i))),
          'endsAt': _iso(now.add(Duration(days: i, hours: 2))),
          'location': 'Merkez Kampüs Konferans Salonu',
          'communityName': 'Bilgisayar Mühendisliği Topluluğu',
          'goingCount': 42,
          'interestedCount': 7,
          'canManage': false,
          'registrationClosed': false,
          'status': 'ACTIVE',
        }
    ],
    'nextCursor': null,
  });
  b.on('/notifications', {
    'items': [
      {'id': 1, 'type': 'ANNOUNCEMENT', 'title': 'Yeni duyuru yayımlandı', 'body': 'Ayrıntı metni', 'read': false, 'createdAt': now.toIso8601String()},
      {'id': 2, 'type': 'EVENT', 'title': 'Etkinlik yarın saat 14:00', 'body': 'Kongre Merkezi', 'read': true, 'createdAt': now.toIso8601String()},
    ],
    'nextCursor': null,
  });
  return b;
}

List<_Screen> _screens() => [
      _Screen('Welcome', (s) => WelcomePage(onLogin: () {}, onRegister: () {}), signedIn: false),
      _Screen('Login', (s) => LoginPage(session: s), signedIn: false),
      _Screen('Register', (s) => RegisterPage(session: s), signedIn: false),
      _Screen('ForgotPassword', (s) => ForgotPasswordPage(session: s), signedIn: false),
      _Screen('AppShell(Ana Sayfa+nav)', (s) => AppShell(session: s, themeController: ThemeController())),
      _Screen('HomeTab', (s) => HomeTab(session: s, onOpenTab: (i, {newsType}) {}), scaffold: true),
      _Screen('DiscoverTab', (s) => DiscoverTab(session: s, typeRequest: ValueNotifier<String?>(null)), scaffold: true),
      _Screen('SearchPage', (s) => SearchPage(session: s)),
      _Screen('NewsListPage', (s) => NewsListPage(session: s)),
      _Screen('MenuPage', (s) => MenuPage(session: s)),
      _Screen('AcademicHub', (s) => AcademicHubPage(session: s)),
      _Screen('ChatTab', (s) => ChatTab(session: s, connectRealtime: false), scaffold: true),
      _Screen('NewChatPage', (s) => NewChatPage(session: s)),
      _Screen('ClubsTab', (s) => ClubsTab(session: s), scaffold: true),
      _Screen('EventsPage', (s) => EventsPage(session: s)),
      _Screen('PollListPage', (s) => PollListPage(session: s)),
      _Screen('NotificationsPage', (s) => NotificationsPage(session: s)),
      _Screen('ProfileTab', (s) => ProfileTab(session: s, themeController: ThemeController()), scaffold: true),
      _Screen('SettingsPage', (s) => SettingsPage(session: s, themeController: ThemeController())),
      _Screen('MyEventsPage', (s) => MyEventsPage(session: s)),
      _Screen('BlockedUsersPage', (s) => BlockedUsersPage(session: s)),
      _Screen('SupportPage', (s) => SupportPage(session: s)),
    ];

final _report = <String, dynamic>{
  'screens': <String>[],
  'guidelines': <Map<String, dynamic>>[],
  'overflow': <Map<String, dynamic>>[],
  'rtl': <Map<String, dynamic>>[],
  'errors': <Map<String, dynamic>>[],
};

final _pat = RegExp(r'file:///[^\s)]*?(?:mobile|bu_hig)/(lib/[^\s):]+\.dart):(\d+)');
final _ovf = RegExp(r'overflowed by ([\d.]+) pixels on the (\w+)');

/// FlutterError akisini toplar: {kind: 'overflow'|'exception', msg, loc}.
class _Catch {
  final List<Map<String, String>> items = [];
  void Function(FlutterErrorDetails)? _prev;

  void start() {
    _prev = FlutterError.onError;
    FlutterError.onError = (d) {
      final s = d.toString();
      final m = _ovf.firstMatch(s);
      final loc = _pat.firstMatch(s);
      items.add({
        'kind': m != null ? 'overflow' : 'exception',
        'msg': m != null ? 'tasma ${m.group(1)}px ${m.group(2)}' : s.split('\n').first.replaceAll(RegExp(r'[^\x20-\x7E]'), '?'),
        'loc': loc != null ? '${loc.group(1)}:${loc.group(2)}' : '-',
      });
    };
  }

  void stop() => FlutterError.onError = _prev;
}

Future<void> _pump(WidgetTester t, _Screen sc,
    {required Size size, bool dark = false, double scale = 1.0, String lang = 'tr', int settleMs = 1500}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  final b = _backend();
  final s = makeSession(b, signedIn: sc.signedIn);
  await t.pumpWidget(p00App(sc.build(s), lang: lang, dark: dark, scale: scale, scaffold: sc.scaffold));
  await settle(t, Duration(milliseconds: settleMs));
}

/// Anlamsal agacta dokunulabilir dugum sayisi (ekranin gercekten dolu cizildigini kanitlar).
int _tappables(WidgetTester t) {
  var n = 0;
  void walk(SemanticsNode x) {
    if (x.getSemanticsData().hasAction(SemanticsAction.tap)) n++;
    x.visitChildren((c) {
      walk(c);
      return true;
    });
  }

  final root = t.binding.renderViews.first.owner?.semanticsOwner?.rootSemanticsNode;
  if (root != null) walk(root);
  return n;
}

Future<void> _unmount(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump(const Duration(milliseconds: 500));
}


/// Yonerge `reason` metnini SemanticsNode bazli girdilere boler: "etiket | kutu | mesaj".
List<String> _entries(String? reason) {
  if (reason == null) return const [];
  final out = <String>[];
  String? cur;
  for (final l in reason.split('\n')) {
    if (l.startsWith('SemanticsNode#')) {
      if (cur != null) out.add(cur);
      final label = RegExp(r'label: "([^"]*)"').firstMatch(l)?.group(1) ?? '';
      final rect = RegExp(r'Rect.fromLTRB\(([^)]*)\)').firstMatch(l)?.group(1) ?? '';
      final isField = l.contains('isTextField') ? 'alan ' : '';
      final msg = l.contains('):') ? l.substring(l.lastIndexOf('):') + 2).trim() : '';
      cur = '$isField[${label.length > 40 ? label.substring(0, 40) : label}] ($rect) $msg';
    } else if (cur != null && (l.startsWith('Expected contrast') || l.contains('expected '))) {
      cur = '$cur ${l.trim()}';
    }
  }
  if (cur != null) out.add(cur);
  return out;
}

void main() {
  setUpAll(loadTestFonts);
  tearDownAll(() {
    if (!_on) return;
    final f = File(_out);
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(const JsonEncoder.withIndent(' ').convert(_report));
    // ignore: avoid_print
    print('HIG|rapor yazildi: ${f.absolute.path}');
  });

  final screens = _screens();

  // ------------------------------------------------------------------ (b) erisilebilirlik yonergeleri
  for (final sc in screens) {
    for (final dark in [false, true]) {
      testWidgets('HIG-b ${sc.name} ${dark ? "koyu" : "acik"}', (t) async {
        final c = _Catch()..start();
        final h = t.ensureSemantics();
        try {
          await _pump(t, sc, size: kPhoneMedium, dark: dark, settleMs: 3500);
          final row = <String, dynamic>{'screen': sc.name, 'theme': dark ? 'dark' : 'light', 'tappables': _tappables(t)};
          final guides = <String, AccessibilityGuideline>{
            'tap48': androidTapTargetGuideline,
            'tap44': iOSTapTargetGuideline,
            'label': labeledTapTargetGuideline,
            'contrast': textContrastGuideline,
          };
          for (final e in guides.entries) {
            try {
              final ev = await e.value.evaluate(t);
              final entries = _entries(ev.reason);
              row[e.key] = {
                'pass': ev.passed,
                'count': ev.passed ? 0 : entries.length,
                'first': entries.take(12).toList(),
              };
            } catch (err) {
              row[e.key] = {'pass': null, 'error': err.toString().split('\n').first.replaceAll(RegExp(r'[^\x20-\x7E]'), '?')};
            }
          }
          (_report['guidelines'] as List).add(row);
          (_report['screens'] as List<String>).contains(sc.name) ? null : (_report['screens'] as List<String>).add(sc.name);
          // ignore: avoid_print
          print('HIG|b|${sc.name}|${dark ? "dark" : "light"}|tap48=${(row['tap48'] as Map)['count']}|tap44=${(row['tap44'] as Map)['count']}|label=${(row['label'] as Map)['count']}|contrast=${(row['contrast'] as Map)['count']}');
        } catch (err) {
          (_report['errors'] as List).add({'screen': sc.name, 'phase': 'b', 'error': err.toString().split('\n').first});
        } finally {
          c.stop();
          h.dispose();
          for (final i in c.items) {
            (_report['errors'] as List).add({'screen': sc.name, 'phase': 'b', ...i});
          }
          t.takeException();
          try {
            await _unmount(t);
          } catch (_) {}
          t.takeException();
        }
      }, skip: !_on);
    }
  }

  // ------------------------------------------------------------------ (c) yazi olcegi tasmasi
  for (final sc in screens) {
    testWidgets('HIG-c ${sc.name} olcek 1.3/2.0', (t) async {
      for (final w in [320.0, 390.0]) {
        for (final scale in [1.3, 2.0]) {
          final c = _Catch()..start();
          try {
            await _pump(t, sc, size: Size(w, 800), scale: scale);
          } catch (err) {
            c.items.add({'kind': 'exception', 'msg': err.toString().split('\n').first, 'loc': '-'});
          }
          c.stop();
          t.takeException();
          final ov = c.items.where((e) => e['kind'] == 'overflow').toList();
          final ex = c.items.where((e) => e['kind'] == 'exception').toList();
          (_report['overflow'] as List).add({
            'screen': sc.name,
            'width': w,
            'scale': scale,
            'overflow_count': ov.length,
            'overflow_locs': ov.map((e) => '${e['loc']} ${e['msg']}').toSet().take(8).toList(),
            'exception_count': ex.length,
            'exceptions': ex.map((e) => '${e['loc']} ${e['msg']}').toSet().take(3).toList(),
          });
          // ignore: avoid_print
          print('HIG|c|${sc.name}|w=$w|x$scale|overflow=${ov.length}|exc=${ex.length}');
          try {
            await _unmount(t);
          } catch (_) {}
          t.takeException();
        }
      }
    }, skip: !_on);
  }

  // ------------------------------------------------------------------ (h) RTL (Arapca)
  for (final sc in screens) {
    testWidgets('HIG-h ${sc.name} RTL', (t) async {
      for (final w in [320.0, 390.0]) {
        for (final scale in [1.0, 1.3]) {
          for (final dark in [false, true]) {
            final c = _Catch()..start();
            try {
              await _pump(t, sc, size: Size(w, 800), scale: scale, lang: 'ar', dark: dark);
            } catch (err) {
              c.items.add({'kind': 'exception', 'msg': err.toString().split('\n').first, 'loc': '-'});
            }
            c.stop();
            t.takeException();
            final ov = c.items.where((e) => e['kind'] == 'overflow').toList();
            final ex = c.items.where((e) => e['kind'] == 'exception').toList();
            (_report['rtl'] as List).add({
              'screen': sc.name,
              'width': w,
              'scale': scale,
              'dark': dark,
              'overflow_count': ov.length,
              'overflow_locs': ov.map((e) => '${e['loc']} ${e['msg']}').toSet().take(8).toList(),
              'exception_count': ex.length,
              'exceptions': ex.map((e) => '${e['loc']} ${e['msg']}').toSet().take(3).toList(),
            });
            // ignore: avoid_print
            print('HIG|h|${sc.name}|w=$w|x$scale|dark=$dark|overflow=${ov.length}|exc=${ex.length}');
            try {
              await _unmount(t);
            } catch (_) {}
            t.takeException();
          }
        }
      }
    }, skip: !_on);
  }

  // ------------------------------------------------------------------ (g) klavye: odaktaki alan klavyenin ustunde kalir mi
  const keyboard = 300.0;
  final formScreens = screens.where((s) => const ['Login', 'Register', 'ForgotPassword', 'SearchPage', 'NewChatPage'].contains(s.name));
  for (final sc in formScreens) {
    testWidgets('HIG-g ${sc.name} klavye', (t) async {
      for (final h in [640.0, 844.0]) {
        final c = _Catch()..start();
        var visible = 'alan yok';
        try {
          t.view.devicePixelRatio = 1;
          t.view.physicalSize = Size(360, h);
          t.view.viewInsets = const FakeViewPadding(bottom: keyboard);
          addTearDown(t.view.resetViewInsets);
          final s = makeSession(_backend(), signedIn: sc.signedIn);
          await t.pumpWidget(p00App(sc.build(s), scaffold: sc.scaffold));
          await settle(t, const Duration(milliseconds: 2500));
          final fields = find.byType(EditableText);
          if (fields.evaluate().isNotEmpty) {
            // Son alana odaklan: en kotu durum (klavyeye en yakin)
            await t.tap(fields.last, warnIfMissed: false);
            await settle(t, const Duration(milliseconds: 900));
            final r = t.getRect(fields.last);
            final limit = h - keyboard;
            visible = r.bottom <= limit + 1 ? 'gorunur' : 'KLAVYE ALTINDA (alt=${r.bottom.toStringAsFixed(0)} sinir=${limit.toStringAsFixed(0)})';
          }
        } catch (err) {
          visible = 'hata: ${err.toString().split('\n').first}';
        }
        c.stop();
        t.takeException();
        (_report['keyboard'] ??= <Map<String, dynamic>>[] as dynamic);
        (_report['keyboard'] as List).add({
          'screen': sc.name,
          'height': h,
          'focused_field': visible,
          'overflow_count': c.items.where((e) => e['kind'] == 'overflow').length,
        });
        // ignore: avoid_print
        print('HIG|g|${sc.name}|h=$h|$visible|overflow=${c.items.where((e) => e['kind'] == 'overflow').length}');
        try {
          await _unmount(t);
        } catch (_) {}
        t.takeException();
        t.view.resetViewInsets();
      }
    }, skip: !_on);
  }
}
