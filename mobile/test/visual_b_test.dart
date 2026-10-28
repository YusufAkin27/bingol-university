import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/features/chat/chat_detail_page.dart';
import 'package:bu_kampus/features/chat/chat_info_page.dart';
import 'package:bu_kampus/features/chat/chat_tab.dart';
import 'package:bu_kampus/features/chat/media_picker_page.dart';
import 'package:bu_kampus/features/chat/new_chat_page.dart';
import 'package:bu_kampus/features/clubs/club_detail_page.dart';
import 'package:bu_kampus/features/clubs/club_form_page.dart';
import 'package:bu_kampus/features/clubs/club_members_page.dart';
import 'package:bu_kampus/features/clubs/club_requests_page.dart';
import 'package:bu_kampus/features/clubs/clubs_tab.dart';
import 'package:bu_kampus/features/events/event_detail_page.dart';
import 'package:bu_kampus/features/events/event_form_page.dart';
import 'package:bu_kampus/features/events/events_page.dart';
import 'package:bu_kampus/features/profile/my_clubs_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_app.dart';
import 'support/fake_media.dart';
import 'support/visual_b.dart';

/// B ajani: sohbet + kulupler + etkinlikler gorsel regresyonu.
/// Sayfa x tema x (320/390/430) x (1.0/1.5) tasma yok; RTL senaryolari; Semantics etiketleri.
/// PNG icin: `VIS_SHOTS=1 flutter test test/visual_b_test.dart` -> build/shots/b/.

String _iso(DateTime d) => d.toUtc().toIso8601String();

const _longTitle = 'Bingöl Üniversitesi Mühendislik Fakültesi Bilgisayar Mühendisliği Öğrenci Topluluğu Büyük Buluşma';
const _longWord = 'Süperkalifragilistikekspiyalidokiyuslukarakterizasyonlarından';
const _ar = 'مرحبا بكم في جامعة بينغول، هذه رسالة طويلة جدا لاختبار الاتجاه من اليمين إلى اليسار';

Map<String, dynamic> _conv(int id, String type, String title, {int unread = 0, String text = 'Merhaba', String? status}) => {
      'id': id,
      'type': type,
      'title': title,
      if (type == 'DIRECT') 'peer': {'id': 10 + id, 'displayName': title},
      'unreadCount': unread,
      'muted': id == 3,
      'lastMessage': {
        'id': 100 + id,
        'conversationId': id,
        'senderId': status == null ? 10 + id : 1,
        'text': text,
        if (status != null) 'status': status,
        'createdAt': _iso(DateTime.now()),
      },
    };

Map<String, dynamic> _convPage({bool ar = false}) => {
      'items': [
        _conv(1, 'DIRECT', ar ? 'علي ولي' : 'Ali Veli', unread: 3, text: ar ? _ar : 'Yarın $_longWord görüşelim mi?'),
        _conv(2, 'GROUP', ar ? _ar : _longTitle, unread: 120, text: 'Toplantı saat kaçta olacak, herkes gelebiliyor mu acaba?'),
        _conv(3, 'CLUB', 'Robotik Kulübü', unread: 1, status: 'READ', text: 'Tamamdır'),
        _conv(4, 'EVENT', 'Kariyer Günleri', status: 'DELIVERED', text: 'Fotoğraf'),
        _conv(5, 'DIRECT', 'Zeynep Çelik', status: 'SENT', text: 'Görüşürüz 👋'),
      ],
      'nextCursor': null,
    };

Map<String, dynamic> _att(int id, {bool video = false, bool once = false, bool removed = false}) => {
      'id': id,
      'kind': video ? 'VIDEO' : 'IMAGE',
      'url': '/api/conversations/1/media/$id',
      'thumbUrl': '/api/conversations/1/media/$id/thumb',
      'width': 1080,
      'height': 1350,
      if (video) 'durationMs': 42000,
      if (once) 'viewOnce': true,
      if (removed) 'removed': true,
    };

Map<String, dynamic> _msg(int id, int sender, String? text, {int min = 0, Map<String, dynamic>? extra}) => {
      'id': id,
      'conversationId': 1,
      'senderId': sender,
      'text': text,
      'createdAt': _iso(DateTime(2026, 10, 26, 9, 0).add(Duration(minutes: min))),
      ...?extra,
    };

Map<String, dynamic> _messagePage({bool group = false, bool ar = false}) {
  final other = group ? 12 : 11;
  final items = <Map<String, dynamic>>[
    _msg(20, 1, null, min: 60, extra: {'attachments': [for (var i = 0; i < 9; i++) _att(900 + i)], 'status': 'READ'}),
    _msg(19, other, null, min: 58, extra: {'attachments': [_att(800), _att(801, video: true), _att(802), _att(803), _att(804)]}),
    _msg(18, 1, null, min: 55, extra: {'attachments': [_att(700, once: true)], 'status': 'DELIVERED'}),
    _msg(17, other, null, min: 50, extra: {'attachments': [_att(600, video: true)]}),
    _msg(16, 1, null, min: 45, extra: {'attachments': [_att(500)], 'status': 'SENT'}),
    _msg(15, other, 'Bu mesaj silindi', min: 40, extra: {'deleted': true}),
    _msg(14, 1, 'Satır bir\nSatır iki\nSatır üç ve biraz daha uzun bir satır olsun ki sarsın', min: 35, extra: {'status': 'READ'}),
    _msg(13, other, ar ? _ar : 'Bu çok uzun bir mesajdır ve birkaç satıra yayılmalıdır. $_longWord bitiş 😀😀😀😀😀😀😀😀', min: 30),
    _msg(12, 1, 'Tamam, görüşürüz 12:30', min: 28, extra: {'status': 'READ', 'edited': true}),
    _msg(11, 1, 'Merhaba nasılsınız bugün', min: 26, extra: {
      'status': 'DELIVERED',
      'reactions': [
        {'emoji': '👍', 'count': 2},
        {'emoji': '❤️', 'count': 1},
        {'emoji': '😂', 'count': 4},
      ],
      'myReaction': '👍',
    }),
    _msg(10, other, 'Evet', min: 25),
    _msg(9, 1, 'Cevap', min: 24, extra: {
      'status': 'READ',
      'replyTo': {'id': 4, 'senderId': other, 'text': 'Yarın görüşelim mi? $_longTitle', 'deleted': false},
    }),
    _msg(8, other, 'Kısa', min: 23),
    _msg(7, 1, 'a', min: 22, extra: {'status': 'READ'}),
    _msg(6, other, 'Selam', min: 1, extra: {
      'replyTo': {'id': 3, 'senderId': 1, 'text': '', 'kind': 'VIDEO', 'deleted': false},
    }),
  ];
  return {'items': items, 'nextCursor': null};
}

FakeBackend _chatBe({bool group = false, bool ar = false}) => FakeBackend()
  ..on('/conversations/1/messages*', _messagePage(group: group, ar: ar))
  ..on('/conversations/1', {
    'conversation': {'id': 1},
    'members': [
      {'userId': 1, 'displayName': 'Ayşe Yılmaz'},
      {'userId': 11, 'displayName': 'Ali Veli'},
      {'userId': 12, 'displayName': 'Mehmet Kaya Uzunsoyadlı Çalışkan'},
    ],
  })
  ..on('/messages/reactions', {
    'emojis': ['👍', '❤️', '😂', '😮', '😢', '🙏']
  })
  ..on('/users/11/presence', {'online': true});

ChatDetailPage _chatPage(Session s, {bool group = false}) => ChatDetailPage(
      session: s,
      connectRealtime: false,
      conversation: {
        'id': 1,
        'type': group ? 'GROUP' : 'DIRECT',
        'title': group ? _longTitle : 'Ali Veli',
        if (!group) 'peer': {'id': 11, 'displayName': 'Ali Veli'},
        if (group) 'memberCount': 12,
      },
    );

Map<String, dynamic> _club({String status = 'ACTIVE', String? role = 'OWNER', String name = 'Robotik ve Yapay Zekâ Topluluğu'}) => {
      'id': 7,
      'name': name,
      'description': 'Robot yarışmalarına hazırlanan öğrenciler. $_longWord Haftalık toplantılar yapılır.',
      'category': 'Teknoloji',
      'memberCount': 42,
      'visibility': 'PUBLIC',
      'joinPolicy': 'OPEN',
      'myStatus': status,
      'myRole': role,
    };

Map<String, dynamic> _clubItem(int id, String name, {String status = 'NONE'}) => {
      'id': id,
      'name': name,
      'category': 'Teknoloji',
      'memberCount': 12 + id,
      'myStatus': status,
      'joinPolicy': 'OPEN',
    };

Map<String, dynamic> _event({String? rsvp, bool manage = false, String? title, int id = 5}) {
  final s = DateTime.now().add(const Duration(hours: 2));
  return {
    'id': id,
    'source': 'USER',
    'title': title ?? _longTitle,
    'description': 'Etkinlik açıklaması. $_longWord',
    'startsAt': _iso(s),
    'endsAt': _iso(s.add(const Duration(hours: 2))),
    'location': 'Kongre ve Kültür Merkezi Büyük Salon',
    'communityId': 7,
    'communityName': 'Robotik ve Yapay Zekâ Topluluğu',
    'goingCount': 8,
    'interestedCount': 3,
    'capacity': 50,
    'myRsvp': rsvp,
    'canManage': manage,
    'registrationClosed': false,
    'status': 'ACTIVE',
    'organizerName': 'Ayşe',
  };
}

List<Map<String, dynamic>> _calendar() {
  final now = DateTime.now();
  final s = DateTime(now.year, now.month, now.day, 12);
  return [
    {'id': 5, 'source': 'USER', 'title': _longTitle, 'startsAt': _iso(s), 'location': 'Büyük Salon', 'communityName': 'Robotik', 'goingCount': 4},
    {'id': 6, 'source': 'USER', 'title': 'Katıldığım etkinlik', 'startsAt': _iso(s), 'goingCount': 9, 'myRsvp': 'GOING'},
    {'id': 9, 'source': 'OFFICIAL', 'title': 'Resmi duyuru etkinliği', 'date': '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}'},
  ];
}

class _Scene {
  const _Scene(this.name, this.backend, this.page, {this.act}) : rtl = false;
  final String name;
  final FakeBackend Function() backend;
  final Widget Function(Session s) page;
  final bool rtl;
  final Future<void> Function(WidgetTester t)? act;
}

Future<void> _reveal(WidgetTester t, Finder f) async {
  await t.dragUntilVisible(f, find.byType(Scrollable).first, const Offset(0, 200));
  await settle(t, const Duration(milliseconds: 200));
}

Future<void> _openMenuOther(WidgetTester t) async {
  final f = find.textContaining('Evet');
  await t.dragUntilVisible(f, find.byType(Scrollable).first, const Offset(0, 200));
  await t.longPress(f);
  await settle(t, const Duration(milliseconds: 500));
}

Future<void> _openMenu(WidgetTester t) async {
  final f = find.textContaining('Tamam, görüşürüz');
  await t.dragUntilVisible(f, find.byType(Scrollable).first, const Offset(0, 200));
  await t.longPress(f);
  await settle(t, const Duration(milliseconds: 500));
}

List<_Scene> _scenes() => [
      _Scene('chat_list', () => FakeBackend()..on('/conversations', _convPage()), (s) => ChatTab(session: s, connectRealtime: false)),
      _Scene('chat_list_empty', () => FakeBackend()..on('/conversations', {'items': [], 'nextCursor': null}),
          (s) => ChatTab(session: s, connectRealtime: false)),
      _Scene('chat_list_error', () => FakeBackend()..fail('/conversations'), (s) => ChatTab(session: s, connectRealtime: false)),
      _Scene('chat_direct', () => _chatBe(), (s) => _chatPage(s)),
      _Scene('chat_group', () => _chatBe(group: true), (s) => _chatPage(s, group: true)),
      _Scene('chat_menu', () => _chatBe(), (s) => _chatPage(s), act: _openMenu),
      _Scene('chat_empty', () => FakeBackend()..on('/conversations/1/messages*', {'items': [], 'nextCursor': null}), (s) => _chatPage(s)),
      _Scene('chat_error', () => FakeBackend()..fail('/conversations/1/messages*'), (s) => _chatPage(s)),
      _Scene(
          'chat_info_group',
          () => FakeBackend()
            ..on('/conversations/5/messages?size=40', {
              'items': [
                for (var i = 12; i > 0; i--)
                  {
                    'id': i,
                    'senderId': 1,
                    'createdAt': '2026-10-20T10:00:00Z',
                    'attachments': [
                      {'id': i, 'kind': i % 4 == 0 ? 'VIDEO' : 'IMAGE', 'url': '/api/conversations/5/media/$i', 'thumbUrl': '/t/$i', 'durationMs': 12000}
                    ],
                  }
              ],
              'nextCursor': null,
            }),
          (s) => ChatInfoPage(
                session: s,
                conversation: const {'id': 5, 'type': 'GROUP', 'title': _longTitle, 'memberCount': 8, 'admin': true},
                members: [
                  for (var i = 1; i <= 8; i++) {'userId': i, 'displayName': i == 2 ? _longTitle : 'Üye $i', 'role': i == 2 ? 'ADMIN' : 'MEMBER'}
                ],
                subtitle: '8 üye',
              )),
      _Scene(
          'chat_info_direct',
          () => FakeBackend()..on('/conversations/5/messages?size=40', {'items': [], 'nextCursor': null}),
          (s) => ChatInfoPage(
                session: s,
                conversation: const {
                  'id': 5,
                  'type': 'DIRECT',
                  'peer': {'id': 2, 'displayName': 'Mehmet Kaya'}
                },
                members: const [
                  {'userId': 1, 'displayName': 'Ayşe Yılmaz'},
                  {'userId': 2, 'displayName': 'Mehmet Kaya'},
                ],
                subtitle: 'Çevrimiçi',
              )),
      _Scene(
          'new_chat',
          () => FakeBackend()
            ..on('/users*', {
              'items': [
                {'id': 2, 'displayName': 'Mehmet Kaya', 'department': 'Bilgisayar Mühendisliği'},
                {'id': 3, 'displayName': _longTitle, 'department': 'Elektrik Elektronik Mühendisliği Bölümü Yüksek Lisans'},
              ],
              'nextCursor': null,
            }),
          (s) => NewChatPage(session: s)),
      _Scene('media_picker', () => FakeBackend(), (s) => MediaPickerPage(library: FakeMediaLibrary.photos(30, videos: [FakeMediaLibrary.video('v1', ms: 12000)]), ensureAccess: (c, p, {rationale}) async => true)),
      _Scene(
          'clubs_tab',
          () => FakeBackend()
            ..on('/communities', {
              'items': [
                _clubItem(1, 'Robotik Kulübü', status: 'ACTIVE'),
                _clubItem(2, _longTitle),
                _clubItem(3, 'Fotoğrafçılık', status: 'PENDING'),
              ],
              'nextCursor': null,
            }),
          (s) => ClubsTab(session: s)),
      _Scene('club_detail_owner', () => _clubBe(), (s) => ClubDetailPage(session: s, communityId: 7)),
      _Scene('club_detail_none', () => _clubBe(status: 'NONE', role: null), (s) => ClubDetailPage(session: s, communityId: 7)),
      _Scene('club_detail_long', () => _clubBe(name: _longTitle), (s) => ClubDetailPage(session: s, communityId: 7)),
      _Scene('club_form', () => FakeBackend(), (s) => ClubFormPage(session: s)),
      _Scene(
          'club_members',
          () => FakeBackend()
            ..on('/communities/7/members*', {
              'items': [
                {'userId': 1, 'displayName': 'Ayşe Yılmaz', 'role': 'OWNER'},
                {'userId': 2, 'displayName': _longTitle, 'role': 'ADMIN'},
                {'userId': 3, 'displayName': 'Ali Veli', 'role': 'MEMBER'},
              ],
              'nextCursor': null,
            }),
          (s) => ClubMembersPage(session: s, communityId: 7, myRole: 'OWNER')),
      _Scene(
          'club_requests',
          () => FakeBackend()
            ..on('/communities/7/requests*', {
              'items': [
                {'userId': 20, 'displayName': 'Ali Veli', 'answers': []},
                {'userId': 21, 'displayName': _longTitle, 'answers': []},
              ],
              'nextCursor': null,
            }),
          (s) => ClubRequestsPage(session: s, communityId: 7)),
      _Scene('my_clubs', () => FakeBackend()..on('/me/communities', {'items': [_clubItem(1, 'Robotik Kulübü', status: 'ACTIVE'), _clubItem(2, _longTitle, status: 'ACTIVE')], 'nextCursor': null}),
          (s) => MyClubsPage(session: s)),
      _Scene('events_page', () => _eventsBe(), (s) => EventsPage(session: s)),
      _Scene('events_calendar', () => _eventsBe(), (s) => EventsPage(session: s, initialTab: 1)),
      _Scene('events_mine', () => _eventsBe(), (s) => EventsPage(session: s, initialTab: 2)),
      _Scene('event_detail', () => _eventDetailBe(manage: true), (s) => EventDetailPage(session: s, eventId: 5)),
      _Scene('event_detail_going', () => _eventDetailBe(rsvp: 'GOING'), (s) => EventDetailPage(session: s, eventId: 5)),
      _Scene('event_form', () => FakeBackend()..on('/me/communities*', {'items': [{'id': 7, 'name': 'Robotik Topluluğu', 'myRole': 'OWNER', 'myStatus': 'ACTIVE'}]}), (s) => EventFormPage(session: s, communityId: 7)),
    ];

FakeBackend _clubBe({String status = 'ACTIVE', String? role = 'OWNER', String? name}) => FakeBackend()
  ..on('/communities/7', _club(status: status, role: role, name: name ?? 'Robotik ve Yapay Zekâ Topluluğu'))
  ..on('/communities/7/posts*', {'items': [], 'nextCursor': null})
  ..on('/events*', {
    'items': [_event(title: 'Kısa etkinlik'), _event(id: 6)],
    'nextCursor': null
  });

FakeBackend _eventsBe() => FakeBackend()
  ..on('/events', {
    'items': [_event(), _event(id: 6, title: 'Bahar Şenliği', rsvp: 'GOING'), _event(id: 7, manage: true)],
    'nextCursor': null,
  })
  ..on('/events/calendar*', _calendar())
  ..on('/me/events*', {
    'items': [_event(manage: true), _event(id: 8, title: 'Bahar Şenliği', rsvp: 'GOING')],
    'nextCursor': null
  });

FakeBackend _eventDetailBe({String? rsvp, bool manage = false}) => FakeBackend()
  ..on('/events/5', _event(rsvp: rsvp, manage: manage))
  ..on('/events/5/attendees*', {
    'items': [
      {'userId': 1, 'displayName': 'Ayşe Yılmaz'},
      {'userId': 2, 'displayName': 'Ali Veli'},
    ],
    'nextCursor': null
  })
  ..on('/events/5/attendance', {'items': [], 'checkedIn': 0, 'total': 0})
  ..on('/events/5/my-attendance', {'checkedIn': false})
  ..on('/events/5/checkin-code', {'code': '123456', 'expiresAt': _iso(DateTime.now().add(const Duration(minutes: 5)))})
  ..on('/events/5/attendees/preview', {'items': [], 'total': 0});

void main() {
  setUpAll(loadVisualFonts);

  final scenes = _scenes();
  final sizes = [kPhoneSmall, kPhoneMedium, kPhoneLarge];
  final scales = [1.0, 1.5];

  for (final sc in scenes) {
    for (final b in Brightness.values) {
      for (final size in sizes) {
        for (final scale in scales) {
          final tag = '${sc.name}__${b.name}_${size.width.toInt()}_x${(scale * 10).round()}';
          testWidgets('tasma yok: $tag', (tester) async {
            captureErrors();
            final s = makeSession(sc.backend());
            await pumpVisual(tester, sc.page(s), brightness: b, size: size, scale: scale);
            if (sc.act != null) await sc.act!(tester);
            expectNoErrors(tester);
            await shot(tester, tag);
            await unmount(tester);
            expectNoErrors(tester);
          });
        }
      }
    }
  }

  // RTL: Arapca yerlesim (mantiksal baslangic/bitis) tasmamali.
  final rtlScenes = <_Scene>[
    _Scene('chat_list', () => FakeBackend()..on('/conversations', _convPage(ar: true)), (s) => ChatTab(session: s, connectRealtime: false)),
    _Scene('chat_direct', () => _chatBe(ar: true), (s) => _chatPage(s)),
    _Scene('chat_group', () => _chatBe(group: true, ar: true), (s) => _chatPage(s, group: true)),
    _Scene('chat_menu', () => _chatBe(ar: true), (s) => _chatPage(s), act: _openMenuOther),
    ..._scenes().where((e) => const ['chat_info_group', 'clubs_tab', 'club_detail_owner', 'events_page', 'event_detail', 'club_form', 'event_form', 'media_picker'].contains(e.name)),
  ];
  for (final sc in rtlScenes) {
    for (final b in Brightness.values) {
      for (final size in [kPhoneSmall, kPhoneMedium]) {
        final tag = 'rtl_${sc.name}__${b.name}_${size.width.toInt()}';
        testWidgets('RTL tasma yok: $tag', (tester) async {
          captureErrors();
          final s = makeSession(sc.backend());
          await pumpVisual(tester, sc.page(s), brightness: b, size: size, rtl: true, scale: 1.3);
          if (sc.act != null) await sc.act!(tester);
          expectNoErrors(tester);
          await shot(tester, tag);
          await unmount(tester);
        });
      }
    }
  }

  // RTL: giden baloncuk baslangic tarafinda (soldadir), gelen bitis tarafinda; LTR'nin tersi.
  testWidgets('RTL: baloncuk yonu LTR ile aynalanir', (tester) async {
    captureErrors();
    final s = makeSession(_chatBe());
    await pumpVisual(tester, _chatPage(s), size: kPhoneMedium);
    await _reveal(tester, find.textContaining('Evet'));
    final ltrMine = tester.getCenter(find.textContaining('Tamam, görüşürüz')).dx;
    final ltrOther = tester.getCenter(find.textContaining('Evet')).dx;
    expect(ltrMine, greaterThan(ltrOther));
    await unmount(tester);
    await pumpVisual(tester, _chatPage(makeSession(_chatBe())), size: kPhoneMedium, rtl: true);
    await _reveal(tester, find.textContaining('Evet'));
    final rtlMine = tester.getCenter(find.textContaining('Tamam, görüşürüz')).dx;
    final rtlOther = tester.getCenter(find.textContaining('Evet')).dx;
    expect(rtlMine, lessThan(rtlOther));
    expectNoErrors(tester);
    await unmount(tester);
  });

  // Alt eylem cubugu ve dugmeler icerigi kadar yer kaplar (sinirli yukseklikte tum ekrani kaplamamali).
  for (final size in [kPhoneSmall, kPhoneMedium, kPhoneLarge]) {
    testWidgets('Etkinlik eylem cubugu ekrani kaplamaz ${size.width.toInt()}', (tester) async {
      captureErrors();
      await pumpVisual(tester, EventDetailPage(session: makeSession(_eventDetailBe()), eventId: 5), size: size, scale: 1.5);
      final r = tester.getRect(find.widgetWithText(InkWell, 'Katıl').first);
      expect(r.height, lessThan(110));
      expect(r.bottom, greaterThan(size.height - 140));
      expectNoErrors(tester);
      await unmount(tester);
    });
  }

  // Erisilebilirlik: tik durumlari ve ikon dugmeleri etiketli.
  testWidgets('Semantics: tik etiketleri, medya ve ikon dugmeleri', (tester) async {
    captureErrors();
    final handle = tester.ensureSemantics();
    final be = _chatBe()
      ..on('/conversations/1/messages*', {
        'items': [
          _msg(3, 1, 'Okundu mesajı', min: 3, extra: {'status': 'READ'}),
          _msg(2, 1, 'Iletildi mesajı', min: 2, extra: {'status': 'DELIVERED'}),
          _msg(1, 1, 'Gonderildi mesajı', min: 1, extra: {'status': 'SENT'}),
          _msg(4, 1, null, min: 4, extra: {'attachments': [_att(5, once: true), _att(6)], 'status': 'READ'}),
        ],
        'nextCursor': null,
      });
    final s = makeSession(be);
    await pumpVisual(tester, _chatPage(s), size: kPhoneMedium);
    expect(find.bySemanticsLabel(RegExp('Fotoğraf')), findsWidgets);
    for (final l in ['Okundu', 'İletildi', 'Gönderildi']) {
      expect(find.bySemanticsLabel(RegExp(l)), findsWidgets, reason: l);
    }
    expect(find.bySemanticsLabel(RegExp('Tek gösterimlik fotoğraf')), findsWidgets);
    // Her dokunulabilir ikon dugmesinin etiketi var.
    final unlabeled = <String>[];
    void walk(SemanticsNode n) {
      final d = n.getSemanticsData();
      final tappable = d.hasAction(SemanticsAction.tap);
      if (tappable && d.label.isEmpty && d.tooltip.isEmpty && d.value.isEmpty) {
        unlabeled.add('${n.rect} ${d.flagsCollection}');
      }
      n.visitChildren((c) {
        walk(c);
        return true;
      });
    }

    // ignore: deprecated_member_use
    walk(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
    expect(unlabeled, isEmpty, reason: unlabeled.join('\n'));
    expectNoErrors(tester);
    await unmount(tester);
    handle.dispose();
  });

  testWidgets('Semantics: sohbet listesi ve etkinlik/kulup sayfalari etiketli dugmeler', (tester) async {
    captureErrors();
    final handle = tester.ensureSemantics();
    for (final sc in scenes.where((e) => const ['chat_list', 'clubs_tab', 'events_page', 'event_detail', 'club_detail_owner'].contains(e.name))) {
      final s = makeSession(sc.backend());
      await pumpVisual(tester, sc.page(s), size: kPhoneMedium);
      final unlabeled = <String>[];
      void walk(SemanticsNode n) {
        final d = n.getSemanticsData();
        if (d.hasAction(SemanticsAction.tap) && d.label.isEmpty && d.tooltip.isEmpty && d.value.isEmpty) {
          unlabeled.add('${n.rect}');
        }
        n.visitChildren((c) {
          walk(c);
          return true;
        });
      }

      // ignore: deprecated_member_use
      walk(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
      expect(unlabeled, isEmpty, reason: '${sc.name}: ${unlabeled.join('\n')}');
      await unmount(tester);
    }
    handle.dispose();
  });
}
