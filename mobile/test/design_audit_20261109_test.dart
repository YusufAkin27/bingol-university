import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/theme_controller.dart';
import 'package:bu_kampus/features/academic/academic_hub_page.dart';
import 'package:bu_kampus/features/chat/chat_tab.dart';
import 'package:bu_kampus/features/chat/department_chats_page.dart';
import 'package:bu_kampus/features/clubs/clubs_tab.dart';
import 'package:bu_kampus/features/events/events_page.dart';
import 'package:bu_kampus/features/home/home_tab.dart';
import 'package:bu_kampus/features/notifications/notifications_page.dart';
import 'package:bu_kampus/features/profile/profile_tab.dart';
import 'package:bu_kampus/features/profile/settings_page.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'redesign/p00_support.dart';
import 'support/fake_app.dart';

// Manual diagnostic: DESIGN_AUDIT_OUT=<absolute path> flutter test --no-pub test/design_audit_20261109_test.dart
// Collects layout errors and screenshots without changing production widgets.
FakeBackend backend() {
  final b = FakeBackend()
    ..on('/menu/today', {
      'date': '2026-11-09',
      'items': ['Mercimek çorbası', 'Orman kebabı', 'Pilav', 'Sütlaç']
    })
    ..on('/conversations', {
      'items': [
        {
          'id': 91,
          'type': 'DEPARTMENT',
          'title': 'Bilgisayar Mühendisliği',
          'memberCount': 100
        },
        {
          'id': 92,
          'type': 'DIRECT',
          'peer': {'id': 12, 'displayName': 'Mehmet Ali Yıldırım'},
          'unreadCount': 25,
          'lastMessage': {
            'id': 100,
            'senderId': 12,
            'text': 'Yarınki ders notlarını paylaşabilir misin?',
            'createdAt': DateTime.now().toIso8601String()
          }
        },
      ],
      'nextCursor': null
    })
    ..on('/conversations/unread-count', {'total': 25})
    ..on('/department-chat/rooms', [
      {
        'departmentName': 'Bilgisayar Mühendisliği',
        'joined': true,
        'conversationId': 91
      },
      {'departmentName': 'Elektrik-Elektronik Mühendisliği', 'joined': false},
      {'departmentName': 'Türk Dili ve Edebiyatı', 'joined': false},
    ])
    ..on('/communities/categories', [
      {'category': 'Teknoloji'}
    ])
    ..on('/communities', {
      'items': [
        {
          'id': 1,
          'name': 'Bilgisayar ve Bilişim Teknolojileri Topluluğu',
          'category': 'Teknoloji',
          'description': 'Öğrenci topluluğu',
          'memberCount': 135,
          'myStatus': 'NONE',
          'joinPolicy': 'OPEN'
        },
      ],
      'nextCursor': null
    })
    ..on('/notifications', {
      'unreadCount': 2,
      'items': [
        {
          'id': 1,
          'type': 'ANNOUNCEMENT',
          'title': 'Ders ekleme bırakma tarihleri hakkında önemli duyuru',
          'read': false,
          'createdAt': DateTime.now().toIso8601String()
        },
        {
          'id': 2,
          'type': 'COMMUNITY',
          'title': 'Topluluk katılım isteğiniz onaylandı',
          'read': true,
          'createdAt': DateTime.now().toIso8601String()
        },
      ],
      'nextCursor': null
    });
  fakeAcademic(b).addCourse(
      'Nesne Yönelimli Programlama', DateTime.now().weekday, '09:00', '11:00');
  return b;
}

void main() {
  final out = Platform.environment['DESIGN_AUDIT_OUT'];
  setUpAll(loadTestFonts);
  final pages = <String, Widget Function(FakeBackend)>{
    'home': (b) => Scaffold(
        body: HomeTab(session: makeSession(b), onOpenTab: (i, {newsType}) {})),
    'chat': (b) => ChatTab(session: makeSession(b), connectRealtime: false),
    'departments': (b) => DepartmentChatsPage(session: makeSession(b)),
    'clubs': (b) => ClubsTab(session: makeSession(b)),
    'notifications': (b) => NotificationsPage(session: makeSession(b)),
    'academic': (b) => AcademicHubPage(session: makeSession(b)),
    'profile': (b) =>
        ProfileTab(session: makeSession(b), themeController: ThemeController()),
    'settings': (b) => SettingsPage(
        session: makeSession(b), themeController: ThemeController()),
    'events': (b) => EventsPage(session: makeSession(b)),
  };
  testWidgets('capture layout matrix', skip: out == null, (tester) async {
    final semantics = tester.ensureSemantics();
    final results = <Map<String, dynamic>>[];
    for (final entry in pages.entries) {
      for (final width in [320.0, 390.0]) {
        for (final scale in [1.0, 1.3, 2.0]) {
          for (final dark in [false, true]) {
            final size = Size(width, 700);
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = size;
            final errors = <String>[];
            final handler = FlutterError.onError;
            final key = GlobalKey();
            final name =
                '${entry.key}_${width.toInt()}_${scale}_${dark ? 'dark' : 'light'}';
            try {
              FlutterError.onError =
                  (details) => errors.add(details.toString());
              await tester.pumpWidget(p00App(
                  RepaintBoundary(key: key, child: entry.value(backend())),
                  scale: scale,
                  dark: dark,
                  scaffold: false));
              await settle(tester);
              Map<String, dynamic> accessibility = {};
              if (width == 390 && scale == 1 && !dark) {
                final targets =
                    await androidTapTargetGuideline.evaluate(tester);
                final labels = await labeledTapTargetGuideline.evaluate(tester);
                accessibility = {
                  'targetsPassed': targets.passed,
                  'targetDetails': targets.reason,
                  'labelsPassed': labels.passed,
                  'labelDetails': labels.reason
                };
              }
              if (errors.isNotEmpty ||
                  (width == 390 && scale == 1.0) ||
                  (width == 320 && scale == 2 && dark)) {
                await tester.runAsync(() async {
                  final dir = Directory(out!)..createSync(recursive: true);
                  final image = await (key.currentContext!.findRenderObject()
                          as RenderRepaintBoundary)
                      .toImage(pixelRatio: 1);
                  final data =
                      (await image.toByteData(format: ui.ImageByteFormat.png))!;
                  File('${dir.path}/$name.png')
                      .writeAsBytesSync(data.buffer.asUint8List());
                  image.dispose();
                });
              }
              results.add({'scene': name, 'errors': errors, ...accessibility});
              await unmount(tester);
            } finally {
              FlutterError.onError = handler;
            }
          }
        }
      }
    }
    tester.view.reset();
    await tester.runAsync(() async {
      File('$out/results.json').writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(results));
    });
    final failed =
        results.where((r) => (r['errors'] as List).isNotEmpty).toList();
    print(
        'AUDIT: ${results.length} scenes, ${failed.length} scenes with layout errors');
    for (final r in failed) {
      print('AUDIT: ${r['scene']}: ${(r['errors'] as List).length} errors');
    }
    semantics.dispose();
  });

  testWidgets('department search with keyboard and large text',
      skip: out == null, (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    final results = <Map<String, dynamic>>[];
    for (final offline in [false, true]) {
      final errors = <String>[];
      final handler = FlutterError.onError;
      final key = GlobalKey();
      try {
        FlutterError.onError = (details) => errors.add(details.toString());
        final b = backend();
        if (offline) b.fail('/department-chat/rooms');
        await tester.pumpWidget(p00App(
            RepaintBoundary(
                key: key, child: DepartmentChatsPage(session: makeSession(b))),
            scale: 2,
            scaffold: false));
        await settle(tester);
        await tester.runAsync(() async {
          final image = await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 1);
          final data =
              (await image.toByteData(format: ui.ImageByteFormat.png))!;
          File('$out/departments_keyboard_${offline ? 'error' : 'loaded'}.png')
              .writeAsBytesSync(data.buffer.asUint8List());
          image.dispose();
        });
        results.add({'offline': offline, 'errors': errors});
        await unmount(tester);
      } finally {
        FlutterError.onError = handler;
      }
    }
    await tester.runAsync(() async {
      File('$out/keyboard.json').writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(results));
    });
  });

  testWidgets('common search visual border also focuses text field',
      skip: out == null, (tester) async {
    useScreen(tester, const Size(390, 700));
    await tester.pumpWidget(p00App(const Center(
        child: Padding(
      padding: EdgeInsets.all(20),
      child: BuSearchField(hint: 'Kulüp ara'),
    ))));
    await settle(tester);
    final rect = tester.getRect(find.byType(BuSearchField));
    final field = find.byType(TextField);
    await tester.tapAt(rect.topLeft + const Offset(100, 4));
    await tester.pump();
    final borderFocus = tester.widget<TextField>(field).focusNode!.hasFocus;
    await tester.tapAt(rect.center);
    await tester.pump();
    final centerFocus = tester.widget<TextField>(field).focusNode!.hasFocus;
    await tester.runAsync(() async {
      File('$out/search-hit-area.json').writeAsStringSync(jsonEncode({
        'visualHeight': rect.height,
        'borderTapFocuses': borderFocus,
        'centerTapFocuses': centerFocus,
      }));
    });
    await unmount(tester);
  });
}
