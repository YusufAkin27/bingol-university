import 'dart:typed_data';

import 'package:bu_kampus/core/platform/image_service.dart';
import 'package:bu_kampus/features/chat/chat_info_media.dart';
import 'package:bu_kampus/features/chat/chat_info_members.dart';
import 'package:bu_kampus/features/chat/chat_info_page.dart';
import 'package:bu_kampus/features/chat/chat_info_tabs.dart';
import 'package:bu_kampus/features/chat/sohbety_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

Map<String, dynamic> _msg(int id) => {
      'id': id,
      'senderId': id.isEven ? 1 : 2,
      'createdAt': '2026-10-20T10:${(id % 60).toString().padLeft(2, '0')}:00Z',
      'attachments': [
        {'id': id, 'kind': 'IMAGE', 'url': '/api/conversations/5/media/$id', 'thumbUrl': '/api/conversations/5/media/$id/thumb'},
      ],
    };

const _conv = {
  'id': 5,
  'type': 'DIRECT',
  'peer': {'id': 2, 'displayName': 'Mehmet Kaya'},
};

const _members = [
  {'userId': 1, 'displayName': 'Ayşe Yılmaz'},
  {'userId': 2, 'displayName': 'Mehmet Kaya'},
];

Map<String, dynamic> _group({required bool admin}) =>
    {'id': 5, 'type': 'GROUP', 'title': 'Proje Grubu', 'memberCount': 8, 'admin': admin};

List<Map<String, dynamic>> _manyMembers(int n) => [
      for (var i = 1; i <= n; i++)
        {'userId': i, 'displayName': i == 1 ? 'Ayşe Yılmaz' : 'Üye $i', 'role': i == 2 ? 'ADMIN' : 'MEMBER'},
    ];

void main() {
  setUpAll(loadTestFonts);

  Future<void> pump(WidgetTester tester, FakeBackend be,
      {Brightness b = Brightness.light,
      Size size = kPhoneMedium,
      List<String>? saved,
      Map<String, dynamic> conv = _conv,
      List<Map<String, dynamic>>? members,
      Future<PreparedImage?> Function()? pickAvatar,
      Future<dynamic> Function(String, PreparedImage)? uploadAvatar}) async {
    useScreen(tester, size);
    await tester.pumpWidget(buildApp(
      ChatInfoPage(
        session: makeSession(be),
        conversation: conv,
        members: members ?? _members.map((e) => Map<String, dynamic>.from(e)).toList(),
        subtitle: 'Çevrimiçi',
        pickAvatar: pickAvatar,
        uploadAvatar: uploadAvatar,
        saveImage: (url, h) async => saved?.add(url),
      ),
      brightness: b,
      size: size,
    ));
  }

  testWidgets('yükleniyor, sonra 3 sütunlu ızgara', (tester) async {
    final be = FakeBackend(delay: const Duration(milliseconds: 200));
    be.on('/conversations/5/messages?size=40', {
      'items': [for (var i = 12; i > 0; i--) _msg(i)],
      'nextCursor': null,
    });
    await pump(tester, be);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await settle(tester);
    final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
    final d = grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(d.crossAxisCount, 3);
    expect(find.text('MEDYA · 12'), findsOneWidget);
    expect(find.text('Mehmet Kaya'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('boş durum', (tester) async {
    final be = FakeBackend()..on('/conversations/5/messages?size=40', {'items': [], 'nextCursor': null});
    await pump(tester, be);
    await settle(tester);
    expect(find.text('Bu sohbette henüz görsel yok.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('hata ve yeniden dene', (tester) async {
    final be = FakeBackend()..fail('/conversations/5/messages?size=40');
    await pump(tester, be);
    await settle(tester, const Duration(seconds: 3));
    expect(find.text('Yeniden dene'), findsOneWidget);
    be.on('/conversations/5/messages?size=40', {
      'items': [_msg(3), _msg(2)],
      'nextCursor': null,
    });
    await tester.tap(find.text('Yeniden dene'));
    await settle(tester);
    expect(find.byType(SliverGrid), findsOneWidget);
    expect(find.text('Yeniden dene'), findsNothing);
    await unmount(tester);
  });

  testWidgets('sonsuz kaydırma ikinci sayfayı çeker', (tester) async {
    final be = FakeBackend();
    be.on('/conversations/5/messages?size=40', {
      'items': [for (var i = 100; i > 60; i--) _msg(i)],
      'nextCursor': 61,
    });
    be.on('/conversations/5/messages?size=40&before=61', {
      'items': [for (var i = 60; i > 20; i--) _msg(i)],
      'nextCursor': null,
    });
    await pump(tester, be);
    await settle(tester);
    expect(be.count('before='), 0);
    await tester.tap(find.text('Tüm medyayı gör'));
    await settle(tester);
    expect(be.count('before='), 0);
    await tester.drag(find.byType(CustomScrollView).last, const Offset(0, -3000));
    await settle(tester);
    expect(be.count('before=61'), 1);
    await unmount(tester);
  });

  testWidgets('dokununca görüntüleyici açılır, sayaç doğru, İndir saveImage çağırır', (tester) async {
    final saved = <String>[];
    final be = FakeBackend()
      ..on('/conversations/5/messages?size=40', {
        'items': [for (var i = 8; i > 0; i--) _msg(i)],
        'nextCursor': null,
      });
    await pump(tester, be, saved: saved);
    await settle(tester);
    await tester.tap(contentImages().first);
    await settle(tester);
    expect(find.textContaining(' / 8'), findsOneWidget);
    await tester.tap(find.byTooltip('İndir'));
    await settle(tester);
    expect(saved.length, 1);
    expect(find.text('Galeriye kaydedildi'), findsOneWidget);
    await tester.tap(find.byTooltip('Kapat'));
    await settle(tester);
    expect(find.textContaining(' / 8'), findsNothing);
    await unmount(tester);
  });

  testWidgets('kaydetme hatasında hata mesajı', (tester) async {
    final be = FakeBackend()
      ..on('/conversations/5/messages?size=40', {
        'items': [_msg(2), _msg(1)],
        'nextCursor': null,
      });
    useScreen(tester, kPhoneMedium);
    await tester.pumpWidget(buildApp(
      ChatInfoPage(
        session: makeSession(be),
        conversation: _conv,
        saveImage: (u, h) async => throw UnsupportedError('x'),
      ),
      size: kPhoneMedium,
    ));
    await settle(tester);
    await tester.tap(contentImages().first);
    await settle(tester);
    await tester.tap(find.byTooltip('İndir'));
    await settle(tester);
    expect(find.text('Bu cihazda desteklenmiyor.'), findsOneWidget);
    await unmount(tester);
  });

  for (final b in Brightness.values) {
    for (final size in kPhoneSizes) {
      testWidgets('taşma yok: ${b.name} ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        final be = FakeBackend()
          ..on('/conversations/5/messages?size=40', {
            'items': [for (var i = 20; i > 0; i--) _msg(i)],
            'nextCursor': null,
          });
        await pump(tester, be, b: b, size: size, conv: {
          'id': 5,
          'type': 'GROUP',
          'title': 'Çok uzun bir grup sohbeti adı burada çok uzun bir grup sohbeti adı',
          'memberCount': 2,
          'admin': true,
        }, members: _manyMembers(8));
        await settle(tester);
        expect(tester.takeException(), isNull);
        await unmount(tester);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('yükleme sürerken kaldırılınca istisna yok', (tester) async {
    final be = FakeBackend(delay: const Duration(milliseconds: 500));
    await pump(tester, be);
    await tester.pump(const Duration(milliseconds: 50));
    await unmount(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('birebir: Üyeler sekmesi yok; Ara/Profil hızlı eylemleri, Ayarlar sekmesinde satırlar', (tester) async {
    final be = FakeBackend()..on('/conversations/5/messages?size=40', {'items': [], 'nextCursor': null});
    await pump(tester, be);
    await settle(tester);
    expect(find.text('Üyeler'), findsNothing);
    expect(find.text('Medya'), findsOneWidget);
    expect(find.text('Ayarlar'), findsOneWidget);
    expect(find.text('Ara'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
    expect(find.text('Sessize al'), findsNothing);
    expect(find.text('Bildirimleri sessize al'), findsNothing);
    await tester.tap(find.text('Ayarlar'));
    await settle(tester);
    // Ayarlar sekmesinde küçük başlık: hızlı eylemler yok.
    expect(find.text('Ara'), findsNothing);
    expect(find.text('Mehmet Kaya'), findsOneWidget);
    expect(find.text('Bildirimleri sessize al'), findsOneWidget);
    expect(find.text('Açık'), findsOneWidget);
    expect(find.text('Arşivle'), findsOneWidget);
    expect(find.text('Engelle'), findsOneWidget);
    expect(find.text('Engellediğiniz kişiyle mesajlaşamazsınız.'), findsOneWidget);
    expect(find.text('Kullanıcıyı şikâyet et'), findsOneWidget);
    expect(find.text('Sohbetten çık'), findsNothing);
    await unmount(tester);
  });

  testWidgets('sessize al: süre alt sayfası PUT gönderir, durum metni güncellenir', (tester) async {
    final be = FakeBackend()..on('/conversations/5/messages?size=40', {'items': [], 'nextCursor': null});
    await pump(tester, be);
    await settle(tester);
    await tester.tap(find.text('Ayarlar'));
    await settle(tester);
    await tester.tap(find.text('Bildirimleri sessize al'));
    await settle(tester);
    expect(find.text('8 saat'), findsOneWidget);
    expect(find.text('1 hafta'), findsOneWidget);
    expect(find.text('Her zaman'), findsOneWidget);
    await tester.tap(find.text('8 saat'));
    await settle(tester);
    expect(be.bodies['PUT /conversations/5/mute'], {'durationMinutes': 480});
    expect(find.text('Sessiz · 8 saat sonra açılır'), findsOneWidget);
    await tester.tap(find.text('Bildirimleri sessize al'));
    await settle(tester);
    expect(be.count('DELETE /conversations/5/mute'), 1);
    expect(find.text('Açık'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('tek gösterimlik ekler ızgarada görünmez', (tester) async {
    final once = _msg(9);
    (once['attachments'] as List).first['viewOnce'] = true;
    final be = FakeBackend()
      ..on('/conversations/5/messages?size=40', {
        'items': [once, _msg(2), _msg(1)],
        'nextCursor': null,
      });
    await pump(tester, be);
    await settle(tester);
    expect(contentImages(), findsNWidgets(2));
    await unmount(tester);
  });

  testWidgets('grup: üyelerle başlar, tüm üyeler listelenir, Sohbetten çık onaylı', (tester) async {
    final be = FakeBackend()..on('/conversations/5/messages?size=40', {'items': [], 'nextCursor': null});
    await pump(tester, be, conv: _group(admin: false), members: _manyMembers(8));
    await settle(tester);
    expect(find.text('ÜYELER · 8'), findsOneWidget);
    expect(find.text('Tümünü gör'), findsNothing);
    expect(find.text('Sen'), findsOneWidget);
    expect(find.text('Yönetici'), findsOneWidget);
    expect(find.text('Üye 8'), findsOneWidget);
    await tester.tap(find.text('Ayarlar'));
    await settle(tester);
    await tester.tap(find.text('Sohbetten çık'));
    await settle(tester);
    expect(find.text('Sohbetten ayrılınsın mı?'), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await settle(tester);
    expect(be.count('/leave'), 0);
    await tester.tap(find.text('Sohbetten çık'));
    await settle(tester);
    await tester.tap(find.text('Ayrıl'));
    await settle(tester);
    expect(be.count('POST /conversations/5/leave'), 1);
    await unmount(tester);
  });

  group('tek sayfa bölümleri', () {
    late FakeBackend be;
    setUp(() {
      be = FakeBackend()
        ..on('/conversations/5/messages?size=40', {
          'items': [for (var i = 20; i > 0; i--) _msg(i)],
          'nextCursor': null,
        });
    });

    Finder segment(String s) => find.descendant(of: find.byType(InfoSegmentBar), matching: find.text(s));
    InfoSection active(WidgetTester tester) => tester.widget<InfoSegmentBar>(find.byType(InfoSegmentBar)).active;
    Finder scrollView() => find.byType(CustomScrollView);

    testWidgets('varsayılan: Üyeler seçili ve üyeler görünür', (tester) async {
      await pump(tester, be, conv: _group(admin: false), members: _manyMembers(8));
      await settle(tester);
      expect(active(tester), InfoSection.members);
      expect(find.text('ÜYELER · 8'), findsOneWidget);
      expect(find.text('Üye 3'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('sekmeler: Medya yalnız medyayı, Ayarlar yalnız ayarları gösterir', (tester) async {
      await pump(tester, be, conv: _group(admin: false), members: _manyMembers(30), size: kPhoneSmall);
      await settle(tester);
      expect(find.text('Üye 3'), findsOneWidget);
      await tester.tap(segment('Medya'));
      await settle(tester, const Duration(seconds: 2));
      expect(active(tester), InfoSection.media);
      expect(find.text('MEDYA · 20'), findsOneWidget);
      expect(find.text('Üye 3'), findsNothing);
      await tester.tap(segment('Ayarlar'));
      await settle(tester, const Duration(seconds: 2));
      expect(active(tester), InfoSection.settings);
      expect(find.text('Bildirimleri sessize al'), findsOneWidget);
      expect(find.text('Sohbetten çık'), findsOneWidget);
      expect(find.text('MEDYA · 20'), findsNothing);
      await tester.tap(segment('Üyeler'));
      await settle(tester, const Duration(seconds: 2));
      expect(active(tester), InfoSection.members);
      expect(find.text('Üye 3'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('30 üye: hepsi listelenir, arama filtreler', (tester) async {
      await pump(tester, be, conv: _group(admin: false), members: _manyMembers(30));
      await settle(tester);
      expect(find.text('ÜYELER · 30'), findsOneWidget);
      expect(find.byType(SohbetyField), findsOneWidget);
      await tester.drag(scrollView(), const Offset(0, -2200));
      await settle(tester);
      expect(find.text('Üye 29'), findsOneWidget);
      await tester.drag(scrollView(), const Offset(0, 6000));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'Üye 17');
      await settle(tester);
      Finder row(String n) => find.descendant(of: find.byType(ChatMemberRow), matching: find.text(n));
      expect(row('Üye 17'), findsOneWidget);
      expect(row('Üye 18'), findsNothing);
      await tester.enterText(find.byType(TextField), 'zzz');
      await settle(tester);
      expect(find.text('Sonuç yok.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('az üyede arama alanı yok', (tester) async {
      await pump(tester, be, conv: _group(admin: false), members: _manyMembers(5));
      await settle(tester);
      expect(find.byType(SohbetyField), findsNothing);
      await unmount(tester);
    });

    testWidgets('Üye ekle yalnız yönetici grubunda; seçilenler POST /members ile eklenir', (tester) async {
      be
        ..on('/users/search*', {
          'items': [
            {'id': 41, 'displayName': 'Yeni Kişi', 'department': 'Hemşirelik'},
            {'id': 3, 'displayName': 'Zaten Üye'},
          ],
          'nextCursor': null,
        })
        ..on('/conversations/5/members', {'id': 5});
      await pump(tester, be, conv: _group(admin: true), members: _manyMembers(3));
      await settle(tester);
      expect(find.text('Üye ekle'), findsOneWidget);
      await tester.tap(find.text('Üye ekle'));
      await settle(tester);
      await tester.enterText(find.byType(TextField).last, 'yeni');
      await tester.pump(const Duration(milliseconds: 350));
      await settle(tester, const Duration(milliseconds: 400));
      expect(find.text('Yeni Kişi'), findsOneWidget);
      expect(find.text('Zaten Üye'), findsNothing); // zaten üye olanlar listelenmez
      await tester.tap(find.text('Yeni Kişi'));
      await tester.pump();
      await tester.tap(find.text('Ekle (1)'));
      await settle(tester);
      expect(be.bodies['POST /conversations/5/members'], {'userIds': [41]});
      await unmount(tester);

      final be2 = FakeBackend()..on('/conversations/5/messages?size=40', {'items': [], 'nextCursor': null});
      await pump(tester, be2, conv: _group(admin: false), members: _manyMembers(3));
      await settle(tester);
      expect(find.text('Üye ekle'), findsNothing);
      await unmount(tester);
    });

    testWidgets('medya önizlemesi en çok 9, Tüm medyayı gör tam sayfayı açar', (tester) async {
      await pump(tester, be);
      await settle(tester);
      expect(contentImages(), findsNWidgets(9));
      expect(find.text('Tüm medyayı gör'), findsOneWidget);
      await tester.tap(find.text('Tüm medyayı gör'));
      await settle(tester);
      expect(find.byType(ChatMediaGridPage), findsOneWidget);
      await unmount(tester);
    });
  });

  testWidgets('yönetici adı ve fotoğrafı değiştirebilir, üye göremez', (tester) async {
    final be = FakeBackend()
      ..on('/conversations/5/messages?size=40', {'items': [], 'nextCursor': null})
      ..on('/conversations/5', {'id': 5, 'type': 'GROUP', 'title': 'Yeni Ad', 'admin': true});
    final uploads = <String>[];
    await pump(
      tester,
      be,
      conv: _group(admin: true),
      members: _manyMembers(3),
      pickAvatar: () async => PreparedImage(Uint8List.fromList([0xFF, 0xD8, 0xFF, 1]), 'image/jpeg'),
      uploadAvatar: (p, i) async {
        uploads.add(p);
        return {'id': 5, 'avatarUrl': '/files/g.jpg'};
      },
    );
    await settle(tester);
    await tester.tap(find.byTooltip('Adı düzenle'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Yeni Ad');
    await tester.pump();
    await tester.tap(find.text('Kaydet'));
    await settle(tester);
    expect(be.bodies['PATCH /conversations/5'], {'title': 'Yeni Ad'});
    expect(find.text('Yeni Ad'), findsOneWidget);
    await tester.tap(find.byTooltip('Fotoğrafı değiştir'));
    await settle(tester);
    expect(find.text('Fotoğrafı kaldır'), findsNothing);
    await tester.tap(find.text('Galeriden seç'));
    await settle(tester);
    expect(uploads, ['/conversations/5/avatar']);
    await unmount(tester);

    final be2 = FakeBackend()..on('/conversations/5/messages?size=40', {'items': [], 'nextCursor': null});
    await pump(tester, be2, conv: _group(admin: false), members: _manyMembers(3));
    await settle(tester);
    expect(find.byTooltip('Adı düzenle'), findsNothing);
    expect(find.byTooltip('Fotoğrafı değiştir'), findsNothing);
    await unmount(tester);
  });
}
