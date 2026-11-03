@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;
import 'package:bu_kampus/features/notifications/notifications_page.dart';
import 'package:bu_kampus/features/notifications/notification_exam_detail.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/fake_app.dart';

void main() {
  final output = Platform.environment['NOTIFICATION_SHOTS_OUT'];
  setUpAll(loadTestFonts);
  for (final dark in [false, true]) {
    for (final exam in [false, true]) {
      testWidgets(
          'notification reference ${exam ? 'exam' : 'inbox'} ${dark ? 'dark' : 'light'}',
          skip: output == null, (tester) async {
        useScreen(tester, kPhoneMedium);
        final be = FakeBackend()
          ..on('/notifications', {
            'unreadCount': 2,
            'items': [
              {
                'id': 1,
                'type': 'FOLLOW_REQUEST',
                'title': 'Can Öztürk',
                'body': 'Sana takip isteği gönderdi.',
                'read': false,
                'data': {'userId': '8'},
                'createdAt': DateTime.now().toIso8601String()
              },
              {
                'id': 2,
                'type': 'EVENT',
                'title': 'Yapay Zekâ Atölyesi',
                'body': 'Etkinlik yarın 14:00’da başlıyor · Konferans Salonu',
                'read': false,
                'data': {'eventId': '4'},
                'createdAt': DateTime.now().toIso8601String()
              },
              {
                'id': 3,
                'type': 'ANNOUNCEMENT',
                'subtype': 'EXAM_REMINDER',
                'title': 'Sınav hatırlatması',
                'body': 'Veri Yapıları ve Algoritmalar · B-204 Amfi',
                'read': true,
                'data': {'examId': '42'},
                'createdAt': DateTime.now().toIso8601String()
              },
            ],
          })
          ..on('/timetable/exams', {
            'items': [
              {
                'id': 42,
                'title': 'Veri Yapıları ve Algoritmalar',
                'courseName': 'BLG 222',
                'type': 'VIZE',
                'startsAt': DateTime.now()
                    .add(const Duration(hours: 14))
                    .toIso8601String(),
                'endsAt': DateTime.now()
                    .add(const Duration(hours: 15, minutes: 30))
                    .toIso8601String(),
                'room': 'B-204 Amfi · Mühendislik Binası 2. Kat',
                'note':
                    'Fotoğraflı öğrenci kimliğinizi yanınızda bulundurunuz.',
              }
            ]
          });
        final session = makeSession(be);
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(
            key: key,
            child: buildApp(
              exam
                  ? Scaffold(
                      body:
                          NotificationExamDetail(session: session, examId: 42))
                  : NotificationsPage(session: session),
              brightness: dark ? Brightness.dark : Brightness.light,
            )));
        await settle(tester);
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          final dir = Directory(output!)..createSync(recursive: true);
          File('${dir.path}/${exam ? 'exam' : 'inbox'}-${dark ? 'dark' : 'light'}.png')
              .writeAsBytesSync(data!.buffer.asUint8List());
          image.dispose();
        });
        await unmount(tester);
      });
    }
  }
}
