import 'dart:typed_data';

import 'package:bu_kampus/core/platform/image_service.dart';
import 'package:bu_kampus/features/chat/chat_info_media.dart';
import 'package:bu_kampus/features/chat/chat_info_members.dart';
import 'package:bu_kampus/features/chat/chat_info_page.dart';
import 'package:bu_kampus/features/chat/chat_info_parts.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';

Map<String, dynamic> _msg(int id, {bool video = false}) => {
      'id': id,
      'senderId': id.isEven ? 1 : 2,
      'createdAt': '2026-10-20T10:${(id % 60).toString().padLeft(2, '0')}:00Z',
      'attachments': [
        {
          'id': id,
          'kind': video ? 'VIDEO' : 'IMAGE',
          if (video) 'durationMs': 42000,
          'url': '/api/conversations/5/media/$id',
          'thumbUrl': '/api/conversations/5/media/$id/thumb'
        },
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
      VoidCallback? onOpenRoom,
      double scale = 1,
      Future<PreparedImage?> Function()? pickAvatar,
      Future<dynamic> Function(String, PreparedImage)? uploadAvatar}) async {
    useScreen(tester, size);
    await tester.pumpWidget(buildApp(
      Builder(
        builder: (c) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: ChatInfoPage(
            session: makeSession(be),
            conversation: Map.of(conv),
            members: members ?? _members.map((e) => Map<String, dynamic>.from(e)).toList(),
            subtitle: 'Çevrimiçi',
            onOpenRoom: onOpenRoom,
            pickAvatar: pickAvatar,
            uploadAvatar: uploadAvatar,
            saveImage: (url, h) async => saved?.add(url),
          ),
        ),
      ),
      brightness: b,
      size: size,
    ));
  }

  FakeBackend backend({int images = 12, Set<int> videos = const {}}) => FakeBackend()
    ..on('/conversations/5/messages?size=40', {
      'items': [for (var i = images; i > 0; i--) _msg(i, video: videos.contains(i))],
      'nextCursor': null,
    });

  /// Görüntüleyicinin İndir denetimi (düğme etiketi ya da ipucu).
  Finder _download() => find.byTooltip('İndir').evaluate().isNotEmpty ? find.byTooltip('İndir') : find.text('İndir');

  Future<void> scrollTo(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(f, 300, scrollable: find.byType(Scrollable).first);
    await settle(tester, const Duration(milliseconds: 300));
  }

  group('belirtme eki', () {
    test('Türkçe ünlü uyumu ve kaynaştırma harfi', () {
      expect(chatInfoAccusative('Mehmet Kaya', 'tr'), "Mehmet Kaya'yı");
      expect(chatInfoAccusative('Ayşe', 'tr'), "Ayşe'yi");
      expect(chatInfoAccusative('Ali', 'tr'), "Ali'yi");
      expect(chatInfoAccusative('Mert', 'tr'), "Mert'i");
      expect(chatInfoAccusative('Ömer', 'tr'), "Ömer'i");
      expect(chatInfoAccusative('Burak', 'tr'), "Burak'ı");
      expect(chatInfoAccusative('Nur', 'tr'), "Nur'u");
      expect(chatInfoAccusative('Gül', 'tr'), "Gül'ü");
      expect(chatInfoAccusative('Zeynep Arslan', 'tr'), "Zeynep Arslan'ı");
    });
    test('büyük harfli adlar', () {
      expect(chatInfoAccusative('ALİ', 'tr'), "ALİ'yi");
      expect(chatInfoAccusative('IŞIL', 'tr'), "IŞIL'ı");
      expect(chatInfoAccusative('ÖMER', 'tr'), "ÖMER'i");
    });
    test('arama katlaması: İ/I/ı ve Türkçe harfler', () {
      expect(chatInfoFold('İlker'), 'ilker');
      expect(chatInfoFold('ILKER'), 'ilker');
      expect(chatInfoFold('Işıl Şahin'), 'isil sahin');
      expect(chatInfoFold('ÇAĞLAR Öz'), 'caglar oz');
    });
    test('diğer dillerde ad değişmez', () {
      expect(chatInfoAccusative('Mehmet Kaya', 'en'), 'Mehmet Kaya');
      expect(chatInfoAccusative('محمد', 'ar'), 'محمد');
    });
  });

  testWidgets('yükleniyor iskeleti, sonra 4 karolu şerit ve +N', (tester) async {
    final be = backend();
    final slow = FakeBackend(delay: const Duration(milliseconds: 200))
      ..on('/conversations/5/messages?size=40', {
        'items': [for (var i = 12; i > 0; i--) _msg(i)],
        'nextCursor': null,
      });
    await pump(tester, slow);
    await tester.pump();
    expect(find.byType(BuSkeleton), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await settle(tester);
    // Stitch v3: 72 dp sabit kare küçük resimler (4 karo), 8 dp aralık.
    expect(find.byType(ChatInfoThumb), findsNWidgets(4));
    expect(tester.getSize(find.byType(ChatInfoThumb).first), const Size(72, 72));
    expect(find.text('Medya · 12'), findsOneWidget);
    expect(find.text('+9'), findsOneWidget);
    expect(contentImages(), findsNWidgets(4));
    expect(find.text('Mehmet Kaya'), findsOneWidget);
    await unmount(tester);
    expect(be.requests, isEmpty);
  });

  testWidgets('boş durum', (tester) async {
    final be = FakeBackend()..on('/conversations/5/messages?size=40', {'items': [], 'nextCursor': null});
    await pump(tester, be);
    await settle(tester);
    expect(find.text('Bu sohbette henüz görsel yok.'), findsOneWidget);
    expect(find.text('Tümünü gör'), findsNothing);
    await unmount(tester);
  });

  testWidgets('hata ve yeniden dene', (tester) async {
    final be = FakeBackend()..fail('/conversations/5/messages?size=40');
    await pump(tester, be);
    await settle(tester, const Duration(seconds: 3));
    expect(find.text('Medya yüklenemedi.'), findsOneWidget);
    expect(find.text('Yeniden dene'), findsOneWidget);
    be.on('/conversations/5/messages?size=40', {
      'items': [_msg(3), _msg(2)],
      'nextCursor': null,
    });
    await tester.tap(find.text('Yeniden dene'));
    await settle(tester);
    expect(find.byType(ChatInfoThumb), findsWidgets);
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
    await tester.tap(find.text('Tümünü gör'));
    await settle(tester);
    expect(be.count('before='), 0);
    await tester.drag(find.byType(CustomScrollView).last, const Offset(0, -3000));
    await settle(tester);
    expect(be.count('before=61'), 1);
    await unmount(tester);
  });

  testWidgets('dokununca görüntüleyici açılır, sayaç doğru, İndir saveImage çağırır', (tester) async {
    final saved = <String>[];
    final be = backend(images: 8);
    await pump(tester, be, saved: saved);
    await settle(tester);
    await tester.tap(contentImages().first);
    await settle(tester);
    expect(find.textContaining(' / 8'), findsOneWidget);
    await tester.tap(_download());
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
        conversation: Map.of(_conv),
        saveImage: (u, h) async => throw UnsupportedError('x'),
      ),
      size: kPhoneMedium,
    ));
    await settle(tester);
    await tester.tap(contentImages().first);
    await settle(tester);
    await tester.tap(_download());
    await settle(tester);
    expect(find.text('Bu cihazda desteklenmiyor.'), findsOneWidget);
    await unmount(tester);
  });

  for (final b in Brightness.values) {
    for (final size in kPhoneSizes) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('taşma yok: ${b.name} ${size.width.toInt()}x${size.height.toInt()} x$scale', (tester) async {
          final be = backend(images: 20, videos: {3});
          await pump(tester, be, b: b, size: size, scale: scale, conv: {
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
  }

  testWidgets('yükleme sürerken kaldırılınca istisna yok', (tester) async {
    final be = FakeBackend(delay: const Duration(milliseconds: 500));
    await pump(tester, be);
    await tester.pump(const Duration(milliseconds: 50));
    await unmount(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('birebir: hızlı eylemler, profil, medya, sessiz, engelle ve şikâyet satırları; üye bölümü yok', (tester) async {
    final be = backend()..on('/users/2', {'id': 2, 'displayName': 'Mehmet Kaya', 'department': 'Bilgisayar Mühendisliği', 'classYear': 3});
    await pump(tester, be);
    await settle(tester);
    expect(find.text('Ara'), findsOneWidget);
    expect(find.text('Sessize al'), findsOneWidget);
    expect(find.text('Arşivle'), findsOneWidget);
    expect(find.text('Profili görüntüle'), findsOneWidget);
    expect(find.text('Bildirimleri sessize al'), findsOneWidget);
    expect(find.text('Açık'), findsOneWidget);
    expect(find.text('Engelle'), findsOneWidget);
    expect(find.text('Kullanıcıyı şikâyet et'), findsOneWidget);
    expect(find.text('Bilgisayar Mühendisliği · 3. Sınıf'), findsOneWidget);
    expect(find.text('Üyeler'), findsNothing);
    expect(find.text('Sohbetten çık'), findsNothing);
    expect(find.text('Çevrimiçi'), findsNothing);
    await unmount(tester);
  });

  testWidgets('sessize al: süre alt sayfası PUT gönderir, durum metni güncellenir; Sesi aç kaldırır', (tester) async {
    final be = backend();
    await pump(tester, be);
    await settle(tester);
    await tester.tap(find.text('Bildirimleri sessize al'));
    await settle(tester);
    expect(find.text('8 saat'), findsOneWidget);
    expect(find.text('1 hafta'), findsOneWidget);
    expect(find.text('Her zaman'), findsOneWidget);
    await tester.tap(find.text('1 hafta'));
    await tester.tap(find.text('8 saat'));
    await tester.pump();
    expect(be.count('PUT /conversations/5/mute'), 0); // seçim tek başına göndermez
    await tester.tap(find.widgetWithText(BuButton, 'Sessize al'));
    await settle(tester);
    expect(be.bodies['PUT /conversations/5/mute'], {'durationMinutes': 480});
    expect(find.text('Sessiz · 8 saat sonra açılır'), findsOneWidget);
    expect(find.text('Açık'), findsNothing); // uzun durum başlığın altında, sağda değil
    expect(find.text('Sesi aç'), findsOneWidget);
    await tester.tap(find.text('Sesi aç'));
    await settle(tester);
    expect(be.count('DELETE /conversations/5/mute'), 1);
    expect(find.text('Açık'), findsOneWidget);
    expect(find.text('Sessize al'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('arşivle ve engelle: onay penceresi, istekler', (tester) async {
    final be = backend();
    await pump(tester, be);
    await settle(tester);
    await tester.tap(find.text('Arşivle'));
    await settle(tester);
    expect(be.bodies['PUT /conversations/5/archive'], {'keepArchived': false});
    expect(find.text('Arşivden çıkar'), findsOneWidget);
    await tester.tap(find.text('Engelle').first);
    await settle(tester);
    expect(find.text('Kullanıcı engellensin mi?'), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await settle(tester);
    expect(be.count('POST /users/2/block'), 0);
    await tester.tap(find.text('Engelle').first);
    await settle(tester);
    await tester.tap(find.text('Engelle').last);
    await settle(tester);
    expect(be.count('POST /users/2/block'), 1);
    expect(find.text('Engeli kaldır'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('tek gösterimlik ekler şeritte görünmez', (tester) async {
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

  testWidgets('video karosu süre rozeti taşır', (tester) async {
    final be = backend(images: 3, videos: {2});
    await pump(tester, be);
    await settle(tester);
    expect(find.text('0:42'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('grup (üye): önizleme 4 satır, Sen/Yönetici, Tümü; Sohbetten çık onaylı', (tester) async {
    final be = backend(images: 8);
    await pump(tester, be, conv: _group(admin: false), members: _manyMembers(8));
    await settle(tester);
    expect(find.text('Üyeler'), findsOneWidget);
    expect(find.text('8'), findsWidgets);
    expect(find.text('Ayşe Yılmaz (Sen)'), findsOneWidget);
    expect(find.text('Yönetici'), findsOneWidget);
    expect(find.text('Üye 4'), findsOneWidget);
    expect(find.text('Üye 5'), findsNothing);
    expect(find.text('Tümü'), findsOneWidget);
    expect(find.byTooltip('Üye seçenekleri'), findsNothing);
    expect(find.text('Üye ekle'), findsNothing);
    await scrollTo(tester, find.text('Sohbetten çık'));
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

  testWidgets('grup medya şeridi 3 karo, Tüm medyayı gör tam sayfayı açar', (tester) async {
    final be = backend(images: 8);
    await pump(tester, be, conv: _group(admin: false), members: _manyMembers(3));
    await settle(tester);
    await scrollTo(tester, find.text('Tümünü gör'));
    expect(contentImages(), findsNWidgets(3));
    await tester.tap(find.text('Tümünü gör'));
    await settle(tester);
    expect(find.byType(ChatMediaGridPage), findsOneWidget);
    await unmount(tester);
  });

  group('üyeler sayfası', () {
    late FakeBackend be;
    setUp(() => be = backend(images: 2));

    Future<void> openAll(WidgetTester tester) async {
      await tester.tap(find.text('Tümü'));
      await settle(tester);
    }

    testWidgets('30 üye: hepsi listelenir, arama filtreler, sonuç yok', (tester) async {
      await pump(tester, be, conv: _group(admin: false), members: _manyMembers(30));
      await settle(tester);
      await openAll(tester);
      expect(find.byType(ChatMembersPage), findsOneWidget);
      expect(find.text('Üyeler (30)'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      await tester.drag(find.byType(ListView).last, const Offset(0, -2600));
      await settle(tester);
      expect(find.text('Üye 29'), findsOneWidget);
      await tester.drag(find.byType(ListView).last, const Offset(0, 6000));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'Üye 17');
      await settle(tester);
      Finder row(String n) => find.descendant(of: find.byType(ChatMemberListRow), matching: find.text(n));
      expect(row('Üye 17'), findsOneWidget);
      expect(row('Üye 18'), findsNothing);
      await tester.enterText(find.byType(TextField), 'zzz');
      await settle(tester);
      expect(find.text('Sonuç yok.'), findsOneWidget);
      expect(find.byType(ChatMemberListRow), findsNothing);
      await tester.tap(find.byTooltip('Kapat'));
      await settle(tester);
      expect(find.byType(ChatMemberListRow), findsWidgets);
      await unmount(tester);
    });

    testWidgets('arama Türkçe İ/I duyarlı (ilker, isil)', (tester) async {
      final ms = [..._manyMembers(5), {'userId': 20, 'displayName': 'İlker Şahin'}, {'userId': 21, 'displayName': 'Işıl Kaya'}];
      await pump(tester, be, conv: _group(admin: false), members: ms);
      await settle(tester);
      await openAll(tester);
      await tester.enterText(find.byType(TextField), 'ilker');
      await settle(tester);
      Finder row(String n) => find.descendant(of: find.byType(ChatMemberListRow), matching: find.text(n));
      expect(row('İlker Şahin'), findsOneWidget);
      expect(row('Işıl Kaya'), findsNothing);
      await tester.enterText(find.byType(TextField), 'isil');
      await settle(tester);
      expect(row('Işıl Kaya'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('Üye ekle alt çubuğa sabit; büyük yazıda çıkar düğmesi yalnız simge', (tester) async {
      final sem = tester.ensureSemantics();
      useScreen(tester, kPhoneMedium);
      await tester.pumpWidget(buildApp(
        Builder(
          builder: (c) => MediaQuery(
            data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: ChatMembersPage(
              members: _manyMembers(30),
              selfId: 1,
              onRemove: (m) async => true,
              onAdd: () async => null,
            ),
          ),
        ),
        size: kPhoneMedium,
      ));
      await settle(tester);
      final add = find.widgetWithText(BuButton, 'Üye ekle');
      expect(add, findsOneWidget);
      expect(tester.getBottomLeft(add).dy, greaterThan(kPhoneMedium.height - 80));
      expect(find.text('Gruptan çıkar'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Gruptan çıkar')), findsWidgets);
      await tester.drag(find.byType(ListView).last, const Offset(0, -600));
      await settle(tester);
      expect(tester.getBottomLeft(add).dy, greaterThan(kPhoneMedium.height - 80)); // kaydırınca yerinde
      expect(tester.takeException(), isNull);
      await unmount(tester);
      sem.dispose();
    });

    testWidgets('yönetici: Gruptan çıkar onaylı, DELETE gider, toast çıkar; Üye ekle düğmesi var', (tester) async {
      be.on('/conversations/5', {
        'conversation': {'id': 5, 'type': 'GROUP', 'title': 'Proje Grubu', 'admin': true},
        'members': _manyMembers(8),
      });
      await pump(tester, be, conv: _group(admin: true), members: _manyMembers(8));
      await settle(tester);
      await openAll(tester);
      expect(find.text('Sen'), findsOneWidget);
      expect(find.text('Yönetici'), findsOneWidget);
      expect(find.text('Gruptan çıkar'), findsWidgets);
      expect(find.text('Üye ekle'), findsOneWidget);
      await tester.tap(find.text('Gruptan çıkar').first);
      await settle(tester);
      expect(find.text('Üye çıkarılsın mı?'), findsOneWidget);
      expect(find.text('Üye 3 gruptan çıkarılır.', findRichText: true), findsOneWidget);
      await tester.tap(find.text('Vazgeç'));
      await settle(tester);
      expect(be.count('DELETE /conversations/5/members'), 0);
      await tester.tap(find.text('Gruptan çıkar').first);
      await settle(tester);
      await tester.tap(find.text('Çıkar'));
      await settle(tester);
      expect(be.count('DELETE /conversations/5/members/3'), 1);
      expect(find.text('Üye 3 gruptan çıkarıldı'), findsOneWidget);
      expect(find.text('Üyeler (7)'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('üye (yönetici değil): çıkar düğmesi ve Üye ekle yok', (tester) async {
      await pump(tester, be, conv: _group(admin: false), members: _manyMembers(8));
      await settle(tester);
      await openAll(tester);
      expect(find.text('Gruptan çıkar'), findsNothing);
      expect(find.text('Üye ekle'), findsNothing);
      await unmount(tester);
    });

    testWidgets('liste alınamazsa hata bandı, Yeniden dene listeyi getirir', (tester) async {
      be.fail('/conversations/5');
      await pump(tester, be, conv: _group(admin: false), members: const []);
      await settle(tester, const Duration(seconds: 3));
      expect(find.text('Üye listesi alınamadı.'), findsOneWidget);
      be.on('/conversations/5', {
        'conversation': {'id': 5},
        'members': _manyMembers(6),
      });
      await tester.tap(find.text('Yeniden dene'));
      await settle(tester);
      expect(find.text('Üye 3'), findsOneWidget);
      expect(find.text('Üye listesi alınamadı.'), findsNothing);
      await unmount(tester);
    });
  });

  testWidgets('yönetici: üye önizlemesinde ⋮ menüsü Gruptan çıkar; Üye ekle POST /members gönderir', (tester) async {
    final be = backend(images: 0)
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
    expect(find.byTooltip('Üye seçenekleri'), findsOneWidget); // yalnız yönetici olmayan, kendisi olmayan 1 üye
    await tester.tap(find.byTooltip('Üye seçenekleri'));
    await settle(tester);
    expect(find.text('Gruptan çıkar'), findsOneWidget);
    await tester.tap(find.text('Gruptan çıkar'));
    await settle(tester);
    expect(find.text('Üye çıkarılsın mı?'), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await settle(tester);
    expect(be.count('DELETE'), 0);

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
    expect(find.text('Fotoğraf çek'), findsOneWidget);
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

  testWidgets('kulüp odası: etiket, üye sayısı, sayfa bağlantısı; ad/fotoğraf düzenleme ve Sohbetten çık yok', (tester) async {
    var opened = 0;
    final be = backend(images: 3);
    await pump(tester, be,
        conv: {'id': 5, 'type': 'CLUB', 'title': 'Robotik Kulübü', 'memberCount': 86},
        members: _manyMembers(5),
        onOpenRoom: () => opened++);
    await settle(tester);
    expect(find.text('Robotik Kulübü'), findsOneWidget);
    expect(find.text('Kulüp odası'), findsOneWidget);
    expect(find.text('86 üye'), findsOneWidget);
    expect(find.text('Etkinlikler ve projeler'), findsOneWidget);
    expect(find.text('Bu sohbet kapalı'), findsNothing);
    expect(find.byTooltip('Adı düzenle'), findsNothing);
    expect(find.byTooltip('Fotoğrafı değiştir'), findsNothing);
    expect(find.text('Ara'), findsOneWidget);
    await tester.tap(find.text('Kulüp sayfasını aç'));
    expect(opened, 1);
    await scrollTo(tester, find.text('Medya'));
    expect(find.text('Sohbetten çık'), findsNothing);
    await unmount(tester);
  });

  testWidgets('kapalı etkinlik odası: kapalı kartı ve etkinlik sayfası satırı', (tester) async {
    final be = backend(images: 0);
    await pump(tester, be,
        conv: {'id': 5, 'type': 'EVENT', 'title': 'Bahar Hackathonu 2025 Odası', 'memberCount': 42, 'closed': true},
        members: _manyMembers(3),
        onOpenRoom: () {});
    await settle(tester);
    expect(find.text('Etkinlik odası'), findsOneWidget);
    expect(find.text('Bu sohbet kapalı'), findsOneWidget);
    expect(find.text('Yeni mesaj gönderilemez'), findsOneWidget);
    expect(find.text('Etkinlik sayfasını aç'), findsOneWidget);
    expect(find.byIcon(LucideIcons.lock), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('medya sayfası: video rozeti; yükleniyor, boş ve hata kartları', (tester) async {
    final be = backend(images: 6, videos: {2});
    useScreen(tester, kPhoneMedium);
    final feed = ChatMediaFeed(api: makeSession(be).api, conversationId: 5, senderName: (m) => null);
    await tester.pumpWidget(buildApp(ChatMediaGridPage(feed: feed, headers: const {}, onOpen: (i) {}), size: kPhoneMedium));
    await tester.pump();
    expect(find.text('Yükleniyor...'), findsOneWidget);
    feed.load(first: true);
    await settle(tester);
    expect(find.text('Yükleniyor...'), findsNothing);
    expect(find.text('0:42'), findsOneWidget);
    expect(contentImages(), findsNWidgets(6));
    await unmount(tester);

    final empty = FakeBackend()..on('/conversations/5/messages?size=40', {'items': [], 'nextCursor': null});
    final f2 = ChatMediaFeed(api: makeSession(empty).api, conversationId: 5, senderName: (m) => null)..load(first: true);
    await tester.pumpWidget(buildApp(ChatMediaGridPage(feed: f2, headers: const {}, onOpen: (i) {}), size: kPhoneMedium));
    await settle(tester);
    expect(find.text('Bu sohbette henüz görsel yok.'), findsOneWidget);
    expect(find.text('Paylaşılan fotoğraflar ve videolar burada görünür.'), findsOneWidget);
    await unmount(tester);

    final bad = FakeBackend()..fail('/conversations/5/messages?size=40');
    final f3 = ChatMediaFeed(api: makeSession(bad).api, conversationId: 5, senderName: (m) => null)..load(first: true);
    await tester.pumpWidget(buildApp(ChatMediaGridPage(feed: f3, headers: const {}, onOpen: (i) {}), size: kPhoneMedium));
    await settle(tester, const Duration(seconds: 3));
    expect(find.text('Hata oluştu'), findsOneWidget);
    expect(find.text('Medya yüklenemedi.'), findsOneWidget);
    bad.on('/conversations/5/messages?size=40', {'items': [_msg(1)], 'nextCursor': null});
    await tester.tap(find.text('Yeniden dene'));
    await settle(tester);
    expect(find.text('Hata oluştu'), findsNothing);
    expect(contentImages(), findsNWidgets(1));
    await unmount(tester);
  });
}
