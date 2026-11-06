// QA-5 (forum + destek + sözleşme + kabuk) regresyon testleri: bulgu kimlikleri docs/qa/QA_forum.md ile aynıdır.
import 'dart:io';

import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/app_gate.dart';
import 'package:bu_kampus/features/forum/data/forum_api.dart';
import 'package:bu_kampus/features/forum/data/forum_draft_store.dart';
import 'package:bu_kampus/features/forum/presentation/widgets/comment_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_app.dart';
import '../support/fake_forum.dart';
import '../support/fake_forum_comments.dart';

void main() {
  setUpAll(loadTestFonts);

  group('QA5-01 uygulama sürümü varsayılanı pubspec ile aynı', () {
    test('appVersion varsayılanı pubspec sürüm adı (zorunlu güncelleme eşiği yanlış hesaplanmasın)', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final m = RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+', multiLine: true).firstMatch(pubspec);
      expect(m, isNotNull);
      // --dart-define verilmediyse (debug/test) varsayılan devrede: pubspec'ten geride kalmamalı.
      expect(compareVersions(appVersion, m!.group(1)!), 0, reason: 'app_gate.dart + push_service.dart varsayılanı $appVersion, pubspec ${m.group(1)}');
      final push = File('lib/core/push/push_service.dart').readAsStringSync();
      expect(push.contains("defaultValue: '${m.group(1)}'"), isTrue, reason: 'push_service.dart varsayılanı da aynı olmalı');
    });
  });

  group('QA5-02 compareVersions yapı numarası / ön sürüm eki', () {
    test('artı ve tire sonrası karşılaştırmaya katılmaz', () {
      expect(compareVersions('2.2.0+22006', '2.2.0'), 0);
      expect(compareVersions('2.2.0+22006', '2.1.3'), 1);
      expect(compareVersions('2.1.3-beta', '2.1.3'), 0);
      expect(compareVersions('2.1.2+99999', '2.1.3'), -1);
      expect(compareVersions('2.10.0', '2.9.9'), 1);
      expect(compareVersions('abc', '0.0.1'), -1);
      expect(compareVersions('', ''), 0);
    });

    test('2.1.3 eşiği: altı zorunlu, eşit ve üstü değil (updateRequired sunucudan gelir)', () {
      expect(decideGate({'updateRequired': true}, null, current: '2.1.2').kind, GateKind.updateRequired);
      expect(decideGate({'updateRequired': false, 'latestVersion': '2.1.3'}, null, current: '2.1.3').kind, GateKind.none);
      expect(decideGate({'updateRequired': false, 'latestVersion': '2.1.3'}, null, current: '2.2.0').kind, GateKind.none);
      expect(decideGate({'latestVersion': '2.1.3'}, null, current: '2.1.2').kind, GateKind.updateAvailable);
    });
  });

  group('QA5-03 kısmi kesintide zorunlu güncelleme kapısı kalkmaz', () {
    testWidgets('yalnız /app/version düşer, /app/info gelir: ekran kapalı kalmaz (kapı sürer)', (tester) async {
      mockSecureStorage();
      final b = FakeBackend();
      b.on('/app/version*', {'updateRequired': true, 'updateAvailable': true, 'latestVersion': '9.9.9', 'storeUrl': 'https://play.google.com/x'});
      b.on('/app/info', {'banner': null});
      await tester.pumpWidget(buildApp(AppGate(api: ApiClient(client: b.client, retryDelay: Duration.zero), child: const Text('uygulama'))));
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Güncelleme gerekli'), findsOneWidget);

      b.fail('/app/version*', status: 503, code: 'SERVER_ERROR');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester, const Duration(milliseconds: 500));
      expect(find.text('Güncelleme gerekli'), findsOneWidget, reason: 'sürüm ucu hata verdi: önceki karar korunur');
      expect(find.text('uygulama'), findsNothing);
      await unmount(tester);
    });
  });

  group('QA5-04 forum taslağı çıkışta silinir (KVKK)', () {
    testWidgets('clearAll tüm kullanıcıların taslağını siler, başka anahtarlara dokunmaz', (tester) async {
      mockSecureStorage();
      const s = FlutterSecureStorage();
      final store = ForumDraftStore(storage: s);
      await store.save(7, const ForumDraft(title: 'gizli baslik', body: 'taslak metin'));
      await store.save(9, const ForumDraft(title: 'baska hesap', body: 'x'));
      await s.write(key: 'theme_mode', value: 'dark');
      expect((await store.load(7))?.title, 'gizli baslik');

      await ForumDraftStore.clearAll(storage: s);

      expect(await store.load(7), isNull);
      expect(await store.load(9), isNull);
      expect(await s.read(key: 'theme_mode'), 'dark', reason: 'cihaza özel anahtar kalır');
    });
  });

  group('QA5-05 yorum silme çift sayılmaz', () {
    test('aynı yorum için eşzamanlı iki remove: sunucuya bir istek, sayaç bir kez düşer', () async {
      final b = FakeBackend();
      final f = fakeForum(b, count: 3);
      fakeForumComments(b, f);
      var delta = 0;
      final cc = CommentsController(api: ForumApi(makeSession(b)), topicId: 500, collapseDuration: Duration.zero, onCountDelta: (d) => delta += d);
      await cc.load();
      final mine = await cc.create(body: 'silinecek', anonymous: false, key: 'qa5-key-0001');
      delta = 0;
      b.delay = const Duration(milliseconds: 20);
      final a = cc.remove(mine);
      final c = cc.remove(mine);
      await Future.wait([a, c]);
      expect(delta, -1);
      expect(b.count('DELETE /forum/comments/${mine.id}'), 1);
      expect(cc.find(mine.id), isNull);
      cc.dispose();
    });
  });
}
