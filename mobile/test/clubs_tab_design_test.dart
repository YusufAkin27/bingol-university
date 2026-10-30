import 'package:bu_kampus/features/clubs/clubs_tab.dart';
import 'package:bu_kampus/features/clubs/clubs_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

const _long = 'Bingöl Üniversitesi Mühendislik Fakültesi Bilgisayar Mühendisliği Öğrenci Topluluğu';

Map<String, dynamic> _c(int id, String name, {String status = 'NONE'}) => {
      'id': id,
      'name': name,
      'category': 'Teknoloji',
      'description': 'Kısa açıklama $id',
      'memberCount': 10 + id,
      'myStatus': status,
      'joinPolicy': 'OPEN',
    };

FakeBackend _be() => FakeBackend()
  ..on('/communities/categories', [
    {'category': 'Teknoloji'},
  ])
  ..on('/me/communities*', {
    'items': [_c(2, 'Satranç Kulübü', status: 'ACTIVE')],
    'nextCursor': null,
  })
  ..on('/communities*', {
    'items': [
      _c(1, _long),
      _c(2, 'Satranç Kulübü', status: 'ACTIVE'),
      _c(3, 'Tiyatro', status: 'PENDING'),
      _c(4, 'Müzik'),
    ],
    'nextCursor': null,
  });

void main() {
  test('baş harfler', () {
    expect(clubsInitials('Fotoğraf Kulübü'), 'FK');
    expect(clubsInitials('Tiyatro'), 'TI');
  });

  for (final b in Brightness.values) {
    for (final size in kPhoneSizes) {
      for (final rtl in [false, true]) {
        testWidgets('şerit + liste taşma yok ${b.name} ${size.width.toInt()} rtl=$rtl', (tester) async {
          useScreen(tester, size);
          final app = buildApp(
              Directionality(
                  textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                  child: ClubsTab(session: makeSession(_be()))),
              brightness: b,
              size: size);
          await tester.pumpWidget(app);
          await settle(tester, const Duration(seconds: 1));
          expect(find.text('Keşfet'), findsOneWidget); // segment
          expect(find.text('Kulüplerim'), findsOneWidget); // segment
          expect(find.text('Satranç Kulübü'), findsOneWidget); // Keşfet listesinde (Üyesin)
          expect(find.text('Katıl'), findsWidgets);
          expect(find.text('İstek gönderildi'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await unmount(tester);
        });
      }
    }
  }
}
