@Tags(['store-shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bu_kampus/core/locale_controller.dart';
import 'package:bu_kampus/features/chat/chat_info_members.dart';
import 'package:bu_kampus/features/chat/chat_info_media.dart';
import 'package:bu_kampus/features/chat/chat_info_page.dart';
import 'package:bu_kampus/features/chat/chat_info_parts.dart';
import 'package:bu_kampus/features/chat/chat_sheet_parts.dart';
import 'package:bu_kampus/features/chat/forward_sheet.dart';
import 'package:bu_kampus/features/chat/sohbety_add_members.dart';
import 'package:bu_kampus/l10n/app_localizations.dart';
import 'package:bu_kampus/widgets/bu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import '../support/store_shots_images.dart';

/// N3 ekran goruntuleri: sohbet bilgisi, uyeler, medya (Stitch grup 24).
/// Varsayilan `flutter test`te ATLANIR. Uretim:
///   STORE_SHOTS_OUT='C:/Users/Toprak Çevik/bu-release/redesign/n3/uygulama' flutter test test/redesign/n3_shots_test.dart
/// Istege bagli: N3_LANG=tr|en|ar, N3_MODES=light,dark,x13, N3_ONLY=01,03
const _dpr = 1.0;
String _lang = 'tr';

Map<String, dynamic> _mem(int id, String name, {String? dept, bool admin = false, bool photo = true}) => {
      'userId': id,
      'displayName': name,
      if (dept != null) 'department': dept,
      if (photo) 'avatarUrl': '/files/avatars/u$id.jpg',
      'role': admin ? 'ADMIN' : 'MEMBER',
    };

Map<String, dynamic> _att(int id, {bool video = false, int ms = 0}) => {
      'id': id,
      'kind': video ? 'VIDEO' : 'IMAGE',
      'url': '/api/conversations/5/media/$id',
      'thumbUrl': '/api/conversations/5/media/$id/thumb',
      if (video) 'durationMs': ms,
    };

Map<String, dynamic> _msg(int id, {bool video = false, int ms = 0}) => {
      'id': id,
      'senderId': 11,
      'createdAt': '2026-10-20T10:00:00Z',
      'attachments': [_att(id, video: video, ms: ms)],
    };

List<Map<String, dynamic>> _msgs(int n, {Set<int> videos = const {}}) => [
      for (var i = n; i > 0; i--) _msg(i, video: videos.contains(i), ms: 42000 + i * 7000),
    ];

class _Sc {
  _Sc(this.file, this.height, this.build, {this.messages, this.after, this.fail = false});
  final String file;
  final double height;
  final Widget Function(FakeBackend be) build;
  final Map<String, dynamic>? messages;
  final Future<void> Function(WidgetTester t)? after;
  final bool fail;
}

const _direct = {
  'id': 5,
  'type': 'DIRECT',
  'title': 'Mehmet Kaya',
  'peer': {'id': 11, 'displayName': 'Mehmet Kaya', 'avatarUrl': '/files/avatars/u14.jpg'},
};

Map<String, dynamic> _group({bool admin = true}) =>
    {'id': 5, 'type': 'GROUP', 'title': 'Algoritma & Proje Ekibi', 'memberCount': 12, 'admin': admin, 'avatarUrl': '/files/avatars/u21.jpg'};

final _groupMembers = [
  _mem(1, 'Ahmet Yılmaz', dept: 'Bilgisayar Mühendisliği', admin: true),
  _mem(12, 'Zeynep Arslan', dept: 'Yazılım Kulübü Başkanı', admin: true),
  _mem(13, 'Mehmet Kaya'),
  _mem(14, 'Elif Demir'),
  for (var i = 15; i < 23; i++) _mem(i, 'Üye $i'),
];

final _pageMembers = [
  _mem(1, 'Mehmet Kaya', dept: 'Bilgisayar Mühendisliği · 4. Sınıf', admin: true),
  _mem(12, 'Zeynep Arslan', dept: 'Moleküler Biyoloji · 3. Sınıf'),
  _mem(13, 'Canan Öztürk', dept: 'İktisadi ve İdari Bilimler · 2. Sınıf'),
  _mem(14, 'Barış Yıldız', dept: 'Mimarlık Bölümü · 1. Sınıf'),
];

Widget _info(FakeBackend be, Map<String, dynamic> conv, {List<Map<String, dynamic>> members = const [], VoidCallback? room}) =>
    ChatInfoPage(session: makeSession(be), conversation: Map.of(conv), members: members, onOpenRoom: room);

Widget _membersPage(FakeBackend be, {List<Map<String, dynamic>>? members, bool admin = true, bool reloadFails = false}) {
  return Builder(
    builder: (ctx) => ChatMembersPage(
      members: members ?? _pageMembers.map((e) => Map<String, dynamic>.from(e)).toList(),
      selfId: 1,
      onRemove: admin
          ? (m) {
              final l = ctx.l10n;
              final name = m['displayName'] as String;
              return showChatInfoConfirm(ctx,
                  icon: LucideIcons.userMinus,
                  title: l.chatInfoRemoveMemberTitle,
                  body: l.chatInfoRemoveMemberBody(name),
                  bold: name,
                  confirmLabel: l.chatInfoRemove,
                  confirmIcon: LucideIcons.trash2,
                  cancelLabel: l.chatInfoCancel);
            }
          : null,
      onAdd: admin ? () async => null : null,
      onReload: () async {
        if (reloadFails) throw StateError('x');
        return _pageMembers;
      },
      onOpenProfile: (m) {},
    ),
  );
}

ChatMediaGridPage _grid(FakeBackend be, {bool load = true}) {
  final s = makeSession(be);
  final feed = ChatMediaFeed(api: s.api, conversationId: 5, senderName: (m) => null);
  if (load) feed.load(first: true);
  return ChatMediaGridPage(feed: feed, headers: const {}, onOpen: (i) {});
}

/// Acilista verilen islevi calistirip bos bir sohbet zemini birakir (alt sayfa/diyalog ekran goruntuleri).
class _Opener extends StatefulWidget {
  const _Opener(this.open);
  final void Function(BuildContext context) open;

  @override
  State<_Opener> createState() => _OpenerState();
}

class _OpenerState extends State<_Opener> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.open(context);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: context.bu.bg, body: const SizedBox.expand());
}

final _convs = {
  'items': [
    {'id': 1, 'type': 'CLUB', 'title': 'Mühendislik Fakültesi 3. Sınıf', 'memberCount': 324},
    {'id': 2, 'type': 'GROUP', 'title': 'Yazılım Kulübü Yönetim', 'memberCount': 18},
    {'id': 3, 'type': 'EVENT', 'title': 'Doğa Sporları ve Dağcılık', 'memberCount': 89},
    {'id': 4, 'type': 'DIRECT', 'peer': {'id': 4, 'displayName': 'Zeynep Kaya', 'avatarUrl': '/files/avatars/u4.jpg'}},
    {'id': 5, 'type': 'DIRECT', 'peer': {'id': 5, 'displayName': 'Mehmet Demir', 'avatarUrl': '/files/avatars/u5.jpg'}},
  ],
  'nextCursor': null,
};

final _people = {
  'items': [
    for (final e in [('Zeynep Kaya', 41), ('Emre Demir', 42), ('Büşra Çelik', 43), ('Caner Yıldız', 44), ('Seda Öztürk', 45)])
      {'id': e.$2, 'displayName': e.$1, 'department': 'Bilgisayar Mühendisliği', 'avatarUrl': '/files/avatars/u${e.$2}.jpg'},
  ],
  'nextCursor': null,
};

final _scenarios = <_Sc>[
  _Sc('07_ilet', 844, (be) => _Opener((c) => showForwardSheet(c, makeSession(be).api)), after: (t) async {
    await t.tap(find.byKey(const ValueKey('fwd-1')));
    await t.tap(find.byKey(const ValueKey('fwd-2')));
    await settle(t, const Duration(milliseconds: 300));
  }),
  _Sc('08_sessize', 844, (be) => _Opener((c) => showChatMuteSheet(c, chatName: 'Ahmet Yılmaz ile sohbet')), after: (t) async {
    await t.tap(find.text(lookupAppLocalizations(Locale(_lang)).chatInfoMute1w));
    await settle(t, const Duration(milliseconds: 300));
  }),
  _Sc('09_uye_ekle', 844, (be) => _Opener((c) => showAddMembersSheet(c, makeSession(be), exclude: {1}, max: 49)), after: (t) async {
    await t.enterText(find.byType(TextField), 'ey');
    await t.pump(const Duration(milliseconds: 400));
    await settle(t, const Duration(milliseconds: 400));
    await t.tap(find.byKey(const ValueKey('add-41')));
    await t.tap(find.byKey(const ValueKey('add-42')));
    await settle(t, const Duration(milliseconds: 300));
  }),
  _Sc('10_grup_adi', 844, (be) => _Opener((c) => showChatRenameDialog(c, initial: 'Kampüs Fotoğrafçıları'))),
  _Sc('10b_grup_adi_bos', 844, (be) => _Opener((c) => showChatRenameDialog(c, initial: '')), ),
  _Sc('11_grup_foto', 844,
      (be) => _Opener((c) => showChatPhotoSheet(c, name: 'Kampüs Fotoğrafçıları', avatarUrl: '/files/avatars/u21.jpg', removable: true, error: c.l10n.chatInfoImageTypeOnly))),
  _Sc('12_ayril', 844, (be) => _Opener((c) {
        final l = c.l10n;
        showChatInfoConfirm(c,
            icon: LucideIcons.logOut,
            title: l.chatInfoLeaveTitle,
            body: l.chatInfoLeaveBody,
            confirmLabel: l.chatInfoLeave,
            confirmIcon: LucideIcons.logOut,
            layout: ChatConfirmLayout.iconBeside,
            cancelLabel: l.chatInfoCancel);
      })),
  _Sc('12b_sil', 844, (be) => _Opener((c) {
        final l = c.l10n;
        showChatInfoConfirm(c,
            icon: LucideIcons.trash2,
            title: l.chatInfoDeleteConvTitle,
            body: l.chatInfoDeleteConvDirect,
            confirmLabel: l.chatInfoDelete,
            confirmIcon: LucideIcons.trash2,
            layout: ChatConfirmLayout.iconAbove,
            cancelLabel: l.chatInfoCancel);
      })),

  _Sc('01_birebir', 844, (be) => _info(be, _direct), messages: {'items': _msgs(12, videos: {2}), 'nextCursor': null}),
  _Sc('01b_birebir_sessiz', 844, (be) => _info(be, {..._direct, 'muted': true, 'mutedForever': true, 'blocked': false}),
      messages: {'items': _msgs(12), 'nextCursor': null}),
  _Sc('01c_birebir_medya_yok', 844, (be) => _info(be, _direct), messages: {'items': [], 'nextCursor': null}),
  _Sc('02_grup_yonetici', 1114, (be) => _info(be, _group(), members: _groupMembers), messages: {'items': _msgs(8), 'nextCursor': null}),
  _Sc('02b_grup_uye', 1114, (be) => _info(be, _group(admin: false), members: _groupMembers), messages: {'items': _msgs(8), 'nextCursor': null}),
  _Sc('03_kulup_odasi', 893, (be) => _info(be, {'id': 5, 'type': 'CLUB', 'title': 'Robotik Kulübü', 'memberCount': 86}, members: _groupMembers, room: () {}),
      messages: {'items': _msgs(5), 'nextCursor': null}),
  _Sc('03b_etkinlik_kapali', 893,
      (be) => _info(be, {'id': 5, 'type': 'EVENT', 'title': 'Bahar Hackathonu 2025 Odası', 'memberCount': 42, 'closed': true}, members: _groupMembers, room: () {}),
      messages: {'items': [], 'nextCursor': null}),
  _Sc('04_uyeler', 844, (be) => _membersPage(be), messages: {'items': [], 'nextCursor': null}),
  _Sc('04b_uyeler_sonuc_yok', 844, (be) => _membersPage(be), messages: {'items': [], 'nextCursor': null}, after: (t) async {
    await t.enterText(find.byType(TextField), 'zzz');
    await settle(t, const Duration(milliseconds: 300));
  }),
  _Sc('04c_uyeler_hata', 844, (be) => _membersPage(be, members: const [], reloadFails: true), messages: {'items': [], 'nextCursor': null}),
  _Sc('04d_uyeler_uye', 844, (be) => _membersPage(be, admin: false), messages: {'items': [], 'nextCursor': null}),
  _Sc('05_cikar_onay', 844, (be) => _membersPage(be), messages: {'items': [], 'nextCursor': null}, after: (t) async {
    await t.tap(find.text(lookupAppLocalizations(Locale(_lang)).chatInfoRemoveFromGroup).first);
    await settle(t, const Duration(milliseconds: 500));
  }),
  _Sc('06_medya', 560, (be) => _grid(be), messages: {'items': _msgs(9, videos: {2, 4, 6}), 'nextCursor': null}),
  _Sc('06b_medya_yukleniyor', 560, (be) => _grid(be, load: false)),
  _Sc('06c_medya_bos', 560, (be) => _grid(be), messages: {'items': [], 'nextCursor': null}),
  _Sc('06d_medya_hata', 560, (be) => _grid(be), fail: true),
];

Widget _app(Widget home, bool dark, GlobalKey key, double scale) => RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: BuTheme.forLocale(Brightness.light, _lang),
        darkTheme: BuTheme.forLocale(Brightness.dark, _lang),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        locale: Locale(_lang),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: home,
      ),
    );

Future<void> _loadFonts(bool arabic) async {
  if (!arabic) return loadTestFonts();
  final f = FontLoader('Inter');
  for (final n in ['arial.ttf', 'arialbd.ttf']) {
    final file = File('C:/Windows/Fonts/$n');
    if (file.existsSync()) f.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await f.load();
  await loadIconFonts();
}

void main() {
  final out = Platform.environment['STORE_SHOTS_OUT'];
  final skip = out == null ? 'STORE_SHOTS_OUT tanimli degil (yalniz ekran goruntusu uretimi icin)' : null;
  _lang = Platform.environment['N3_LANG'] ?? 'tr';
  final only = (Platform.environment['N3_ONLY'] ?? '').split(',').where((e) => e.isNotEmpty).toList();
  final modes = (Platform.environment['N3_MODES'] ?? 'light').split(',');
  final variants = <(String, bool, double)>[
    if (modes.contains('light')) ('', false, 1.0),
    if (modes.contains('dark')) ('_koyu', true, 1.0),
    if (modes.contains('x13')) ('_x1.3', false, 1.3),
  ];

  setUpAll(() => _loadFonts(_lang == 'ar'));

  for (final v in variants) {
    for (final sc in _scenarios) {
      if (only.isNotEmpty && !only.any((o) => sc.file.startsWith(o))) continue;
      final name = '${sc.file}${v.$1}_$_lang';
      testWidgets('n3 $name', skip: skip != null, (tester) async {
        debugNetworkImageHttpClientProvider = () => StoreImageHttpClient();
        addTearDown(() => debugNetworkImageHttpClientProvider = null);
        tester.view.devicePixelRatio = _dpr;
        tester.view.physicalSize = Size(390 * _dpr, sc.height * _dpr);
        tester.view.padding = const FakeViewPadding(top: 0, bottom: 0);
        tester.view.viewPadding = const FakeViewPadding(top: 0, bottom: 0);
        addTearDown(tester.view.reset);
        LocaleController.current = LocaleController(deviceLocales: () => [Locale(_lang)])..pref = _lang;
        addTearDown(() => LocaleController.current = null);

        final be = FakeBackend();
        if (sc.fail) {
          be.fail('/conversations/5/messages?size=40');
        } else if (sc.messages != null) {
          be.on('/conversations/5/messages?size=40', sc.messages);
        }
        be.on('/conversations*', _convs);
        be.on('/users/search*', _people);
        be.on('/users/11', {'id': 11, 'displayName': 'Mehmet Kaya', 'department': 'Bilgisayar Mühendisliği', 'classYear': 3});
        final key = GlobalKey();
        await tester.pumpWidget(_app(sc.build(be), v.$2, key, v.$3));
        await settle(tester, const Duration(milliseconds: 600));
        if (sc.after != null) await sc.after!(tester);
        for (var i = 0; i < 3; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
          await settle(tester, const Duration(milliseconds: 200));
        }
        final err = tester.takeException();
        if (err != null) fail('Istisna: $err');
        await tester.runAsync(() async {
          final ro = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await ro.toImage(pixelRatio: _dpr);
          final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
          final dir = Directory(out!)..createSync(recursive: true);
          File('${dir.path}/$name.png').writeAsBytesSync(data.buffer.asUint8List());
        });
        await unmount(tester);
        debugNetworkImageHttpClientProvider = null;
      });
    }
  }
}
