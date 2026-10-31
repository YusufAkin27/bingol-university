// A15 denetimi: mesaj onbellegi, ETag/disk onbellegi, hesap degisimi sizintisi, cikista temizlik.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bu_kampus/core/api.dart';
import 'package:bu_kampus/core/cache/disk_cache.dart';
import 'package:bu_kampus/core/cache/image_disk_cache.dart';
import 'package:bu_kampus/core/cache/message_cache.dart';
import 'package:bu_kampus/core/connectivity/connectivity_service.dart';
import 'package:bu_kampus/core/outbox/outbox.dart';
import 'package:bu_kampus/core/pending_verification.dart';
import 'package:bu_kampus/core/session.dart';
import 'package:bu_kampus/core/user_data.dart';
import 'package:bu_kampus/features/chat/photo_autosave.dart';
import 'package:bu_kampus/features/search/recent_searches.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/fake_app.dart' show mockSecureStorage;

const _t176 = 'T-176 / W3-G: mesaj onbellegi LRU okuma zamani (DUSUK) bu dalgada degil';
const _t102 = 'T-102 / W2-G: silinen icerik kalintilari (ORTA) bu dalgada degil';
const _t106 = 'T-106 / W2-G: ApiClient ORTA paketi (yanit tavani, yazma/GET yarisi) bu dalgada degil';

Map<String, dynamic> msg(int id, {String text = 'm', Map<String, dynamic>? extra}) =>
    {'id': id, 'conversationId': 5, 'senderId': 2, 'text': '$text$id', 'createdAt': '2026-10-30T10:00:00Z', ...?extra};

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('a15_c_');
  });
  tearDown(() async {
    try {
      await root.delete(recursive: true);
    } catch (_) {}
  });

  MessageCache mc([Directory? d]) => MessageCache(
      dirProvider: () async => d ?? Directory('${root.path}/msg_cache'), flushDelay: const Duration(milliseconds: 20));

  group('S2 mesaj onbellegi', () {
    test('S2.1 20 siniri: sunucu+onbellek birlesimi, duzenleme, silme, siralama', () async {
      final c = mc();
      c.saveMessages(5, [for (var i = 100; i >= 81; i--) msg(i)]);
      await c.upsertMessage(5, msg(101));
      await c.upsertMessage(5, msg(95, text: 'duzenlendi', extra: {'edited': true}));
      await c.markGone(5, 90);
      await c.flush();
      await c.settle();
      final c2 = mc();
      final r = await c2.readMessages(5);
      expect(r.length, 20);
      expect(r.first['id'], 101);
      expect(r.last['id'], 82);
      expect(r.firstWhere((m) => m['id'] == 95)['text'], 'duzenlendi95');
      final g = r.firstWhere((m) => m['id'] == 90);
      expect(g['deleted'], true);
      expect(g['text'], '');
      expect([for (final m in r) m['id']], [for (var i = 101; i >= 82; i--) i]);
    });

    test('S2.1b upsert, kaydi olmayan sohbete yazmaz; yerel (id yok) mesaj yazilmaz', () async {
      final c = mc();
      await c.upsertMessage(77, msg(1));
      c.saveMessages(5, [msg(3), {'id': null, 'text': 'yerel', 'clientId': 'x'}]);
      await c.flush();
      await c.settle();
      final files = Directory('${root.path}/msg_cache').listSync().map((e) => e.uri.pathSegments.last).toList();
      expect(files.contains('c77.json'), isFalse);
      final raw = File('${root.path}/msg_cache/c5.json').readAsStringSync();
      expect(raw.contains('yerel'), isFalse);
    });

    test('S2.2 es zamanli 40 upsert (STOMP) + saveMessages + flush: kayip guncelleme/bozuk dosya yok', () async {
      final c = mc();
      c.saveMessages(5, [msg(1)]);
      await c.flush();
      final fs = <Future<void>>[];
      for (var i = 2; i <= 41; i++) {
        fs.add(c.upsertMessage(5, msg(i)));
        if (i % 7 == 0) fs.add(c.flush());
        if (i % 11 == 0) c.saveMessages(5, [for (var k = i; k >= 1; k--) msg(k)]);
      }
      await Future.wait(fs);
      await c.flush();
      await c.settle();
      final r = await mc().readMessages(5);
      expect(r.map((m) => m['id']).toList(), [for (var i = 41; i >= 22; i--) i]);
      final tmpLeft = Directory('${root.path}/msg_cache').listSync().where((e) => e.path.endsWith('.tmp')).length;
      expect(tmpLeft, 0);
    });

    test('S2.3 debounce (1.5 sn) icinde uygulama oldurulur -> son mesajlar KAYIP (yalniz onbellek; eski dosya kalir)', () async {
      final c = MessageCache(dirProvider: () async => Directory('${root.path}/msg_cache'), flushDelay: const Duration(milliseconds: 1500));
      c.saveMessages(5, [msg(1), msg(2)]);
      await c.flush();
      c.saveMessages(5, [msg(3), msg(2), msg(1)]); // yazma bekliyor
      await Future<void>.delayed(const Duration(milliseconds: 100));
      // process olur: flush calismaz
      final r = await mc().readMessages(5);
      // ignore: avoid_print
      print('S2.3 olum sonrasi onbellekte: ${r.map((m) => m['id']).toList()} (3 yok)');
      expect(r.map((m) => m['id']), [2, 1]);
    });

    test('S2.4a kesik/bozuk JSON dosyasi: cokme yok, dosya silinir', () async {
      Directory('${root.path}/msg_cache').createSync(recursive: true);
      File('${root.path}/msg_cache/c5.json').writeAsStringSync('{"v":1,"m":[{"id":1,"te');
      final r = await mc().readMessages(5);
      expect(r, isEmpty);
      expect(File('${root.path}/msg_cache/c5.json').existsSync(), isFalse);
    });

    test('S2.4b surum uyumsuz / tip-bozuk kayit: dogrulama YOK -> chat sayfasi _key/sort icinde TypeError (spinner kilitlenir)', () async {
      Directory('${root.path}/msg_cache').createSync(recursive: true);
      File('${root.path}/msg_cache/c5.json').writeAsStringSync(jsonEncode({
        'v': 99, // gelecekteki/eski surum: 'v' hic kontrol edilmiyor
        'm': [
          {'id': '7', 'text': 5}, // id String
        ]
      }));
      final c = mc();
      final r = await c.readMessages(5);
      // ignore: avoid_print
      print('S2.4b okunan: $r');
      // chat_detail_page._boot ayni listeyi _msgs.sort((a,b)=>_key(b)...) ile siralar: (m["id"] as num?) -> TypeError
      var threw = false;
      try {
        await c.upsertMessage(5, msg(8));
      } catch (_) {
        threw = true;
      }
      // ignore: avoid_print
      print('S2.4b upsert TypeError firlatti mi: $threw ; okunan tip-bozuk kayit sayisi: ${r.length}');
      expect(threw, isFalse, reason: 'STOMP upsert yolunda yakalanmamis TypeError (main.dart unawaited)');
      expect(r, isEmpty, reason: 'v!=1 veya tip-bozuk kayit atilmali');
    });

    test('S2.5 tavan: 60 sohbet -> en fazla 50 dosya, EN ESKI yazilan silinir; son acilan(okunan) eski sohbet korunmaz', skip: _t176, () async {
      final c = MessageCache(dirProvider: () async => Directory('${root.path}/msg_cache'), flushDelay: const Duration(milliseconds: 5));
      for (var i = 1; i <= 60; i++) {
        c.saveMessages(1000 + i, [msg(i)]);
        await c.flush();
        await Future<void>.delayed(const Duration(milliseconds: 3));
        if (i == 30) await c.readMessages(1001); // kullanici eski sohbeti ACTI (yalniz okuma)
      }
      await c.settle();
      final names = Directory('${root.path}/msg_cache').listSync().map((e) => e.uri.pathSegments.last).where((n) => n.startsWith('c')).toList();
      // ignore: avoid_print
      print('S2.5 kalan dosya: ${names.length}; c1001 var mi: ${names.contains("c1001.json")}; c1060 var mi: ${names.contains("c1060.json")}');
      expect(names.length, lessThanOrEqualTo(50));
      expect(names.contains('c1060.json'), isTrue);
      expect(names.contains('c1001.json'), isTrue, reason: 'yeni ACILMIS sohbet (okuma) LRU sayilmiyor: en eski mtime ile once silinir');
    });

    test('S2.6 3 MB bayt tavani: buyuk sohbetler eskiden budanir, yeni yazilan korunur', () async {
      final c = MessageCache(dirProvider: () async => Directory('${root.path}/msg_cache'), flushDelay: const Duration(milliseconds: 5));
      final big = 'x' * 40000;
      for (var i = 1; i <= 12; i++) {
        c.saveMessages(2000 + i, [for (var k = 0; k < 20; k++) msg(k + 1, text: big)]);
        await c.flush();
        await Future<void>.delayed(const Duration(milliseconds: 3));
      }
      await c.settle();
      final files = Directory('${root.path}/msg_cache').listSync().whereType<File>().where((f) => f.path.contains('${Platform.pathSeparator}c')).toList();
      final total = files.fold<int>(0, (a, f) => a + f.lengthSync());
      // ignore: avoid_print
      print('S2.6 dosya=${files.length} toplam=${(total / 1024 / 1024).toStringAsFixed(2)}MB');
      expect(total, lessThanOrEqualTo(3 * 1024 * 1024));
      expect(File('${root.path}/msg_cache/c2012.json').existsSync(), isTrue);
    });

    test('S2.7 tek gosterimlik / silinen / kaldirilan icerik dosyaya yazilmaz (URL ve metin kalintisi taramasi)', skip: _t102, () async {
      final c = mc();
      c.saveMessages(5, [
        msg(1, text: 'GIZLIMETIN', extra: {
          'attachments': [
            {'id': 9, 'kind': 'image', 'viewOnce': true, 'url': 'https://x/SECRETURL', 'thumbUrl': 'https://x/SECRETTHUMB', 'width': 4}
          ]
        }),
        msg(2, text: 'SILINENMETIN', extra: {
          'deleted': true,
          'attachments': [{'id': 10, 'url': 'https://x/DELURL'}],
          'replyTo': {'id': 1, 'text': 'REPLYSECRET'}
        }),
        msg(3, text: 'KALDIRILAN', extra: {'removed': true, 'reactions': [{'e': 'x'}], 'attachments': [{'id': 11, 'url': 'https://x/REMURL'}]}),
        msg(4, text: 'yanit', extra: {'replyTo': {'id': 1, 'senderId': 3, 'text': 'REPLYONCE', 'viewOnce': true}}),
      ]);
      c.saveConversations([
        {
          'id': 5,
          'unreadCount': 3,
          'lastMessage': {'id': 1, 'text': 'LISTGIZLI', 'attachments': [{'id': 9, 'kind': 'image', 'viewOnce': true, 'url': 'https://x/LISTURL'}]}
        }
      ]);
      await c.flush();
      await c.settle();
      final all = Directory('${root.path}/msg_cache').listSync().whereType<File>().map((f) => f.readAsStringSync()).join('\n');
      final leaks = [for (final bad in ['GIZLIMETIN', 'SECRETURL', 'SECRETTHUMB', 'SILINENMETIN', 'DELURL', 'REPLYSECRET', 'KALDIRILAN', 'REMURL', 'REPLYONCE', 'LISTGIZLI', 'LISTURL']) if (all.contains(bad)) bad];
      // ignore: avoid_print
      print('S2.7 diskte kalan: $leaks');
      expect(leaks, isEmpty);
    });

    test('S2.8 clear(): bellek + disk tamamen silinir; clear ile yarisan yukleme ESKI veriyi bellege geri koymaz', () async {
      final c = mc();
      c.saveMessages(5, [msg(1)]);
      await c.flush();
      final c2 = mc();
      final pending = c2.readMessages(5); // diskten yukleme siraya girdi
      final cl = c2.clear();
      await Future.wait([pending, cl]);
      final after = await c2.readMessages(5);
      // ignore: avoid_print
      print('S2.8 clear sonrasi readMessages: ${after.length}');
      expect(after, isEmpty, reason: 'clear sonrasi eski hesabin mesaji bellekte kalmamali');
      expect(Directory('${root.path}/msg_cache').listSync().whereType<File>(), isEmpty);
    });
  });

  group('S2/S5 hesap degisimi + cikis temizligi', () {
    Future<(Session, Outbox, List<Directory>)> world(MockClient client) async {
      mockSecureStorage();
      final api_ = Directory('${root.path}/api_cache');
      final msg_ = Directory('${root.path}/msg_cache');
      final img_ = Directory('${root.path}/img_cache');
      final ob_ = Directory('${root.path}/outbox_media');
      final api = ApiClient(
        client: client,
        retryDelay: Duration.zero,
        diskCache: DiskCache(dirProvider: () async => api_),
        connectivity: ConnectivityService(),
      );
      final outbox = Outbox(store: const SecureOutboxStore(), mediaDirProvider: () async => ob_, autoSchedule: false);
      api.outbox = outbox;
      MessageCache.instance = MessageCache(dirProvider: () async => msg_, flushDelay: const Duration(milliseconds: 5));
      ImageDiskCache.instance = ImageDiskCache(dirProvider: () async => img_);
      // Kullanıcıya özel TÜM yerel depolar tek kayıt noktasından (core/user_data.dart) temizlenir.
      PhotoAutoSave.instance = PhotoAutoSave(store: FileAutoSaveStore(dirProvider: () async => root), supported: true);
      registerUserDataCleaners(api);
      final s = Session(api)..pending = PendingVerificationStore.memory();
      return (s, outbox, [api_, msg_, img_, ob_]);
    }

    List<String> listAll(List<Directory> ds) => [
          for (final d in ds)
            if (d.existsSync()) for (final f in d.listSync(recursive: true).whereType<File>()) f.path.replaceFirst(root.path, '')
        ];

    test('S2.9 cikis: dosya listesi karsilastirmasi (api_cache, msg_cache, img_cache, outbox_media, kuyruk) + atlanan depolar', () async {
      final client = MockClient((r) async => http.Response(jsonEncode({'items': []}), 200, headers: {'etag': '"1"', 'content-type': 'application/json'}));
      final (s, outbox, dirs) = await world(client);
      s.api.tokens = Tokens(_jwt(7), 'r1');
      await s.api.get('/events');
      await s.api.get('/me/communities');
      MessageCache.instance.saveMessages(5, [msg(1)]);
      await MessageCache.instance.flush();
      await ImageDiskCache.instance.write('https://x/a.png', Uint8List.fromList([1, 2, 3]));
      await outbox.enqueueMedia(conversationId: 5, clientId: 'cm', text: 'k', sources: [OutboxMediaSource(kind: 'image', mime: 'image/jpeg', bytes: Uint8List.fromList([1, 2]))]);
      outbox.enqueue(conversationId: 5, clientId: 'ct', text: 'bekleyen');
      await s.api.diskCache!.flush();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // diger kullanici-ozel depolar
      const st = FlutterSecureStorage();
      await st.write(key: 'recent_searches', value: jsonEncode(['ali yilmaz']));
      await st.write(key: 'academic_reminders', value: '{"x":1}');
      await st.write(key: 'synced_language', value: '7|tr');
      await st.write(key: 'legal_later', value: '7|sig');
      final photo = File('${root.path}/photo_autosave.json')..writeAsStringSync('{"saved":[1,2,3],"enabled":true,"since":1}');
      await PhotoAutoSave.instance.setEnabled(true); // bellekte de dolu olsun
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final before = listAll(dirs);
      expect(before.isNotEmpty, isTrue);
      await s.signOut(remote: false);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final after = listAll(dirs);
      // ignore: avoid_print
      print('S2.9 cikis oncesi dosyalar: ${before.length}; sonrasi: $after ; kuyruk: ${outbox.items.length}');
      expect(after, isEmpty);
      expect(outbox.items, isEmpty);
      final recent = await st.read(key: 'recent_searches');
      // ignore: avoid_print
      print('S2.9 recent_searches cikis sonrasi: $recent ; photo_autosave.json duruyor: ${photo.existsSync()}');
      expect(recent, isNull, reason: 'onceki hesabin arama gecmisi sonraki hesaba gorunur');
      expect(photo.existsSync(), isFalse, reason: 'photo_autosave.json (kaydedilen ek kimlikleri) cikista silinmiyor');
      expect(await st.read(key: 'academic_reminders'), isNull);
      expect(await st.read(key: 'synced_language'), isNull);
      expect(await st.read(key: 'legal_later'), isNull);
      expect(await PhotoAutoSave.instance.enabled(), isFalse, reason: 'ayar bellekte de sifirlanir');
      expect(await RecentSearches.load(), isEmpty);
    });

    // Cihaza ozel (hesaptan bagimsiz) anahtarlar: cikista KALIR. Yeni bir kullaniciya ozel anahtar eklenirse bu envanter
    // testi kirilir (temizleyici + docs/MOBILE_UI.md 4.2 guncellenmeli).
    const deviceKeys = {'device_id', 'welcome_seen', 'perms_onboarded', 'theme_mode', 'app_language', 'crash_reports_enabled', 'update_notice_shown', 'pending_verification'};

    test('S2.9b cikis sonrasi guvenli depoda yalniz CIHAZA OZEL anahtarlar kalir (belirtecler, kuyruk, arama gecmisi...)', () async {
      final client = MockClient((r) async => http.Response(jsonEncode({'items': []}), 200, headers: {'etag': '"1"', 'content-type': 'application/json'}));
      final (s, outbox, _) = await world(client);
      const st = FlutterSecureStorage();
      await s.api.setTokens(Tokens(_jwt(7), 'r1')); // access/refresh guvenli depoya yazilir
      for (final k in deviceKeys) {
        await st.write(key: k, value: 'cihaz');
      }
      for (final k in ['recent_searches', 'academic_reminders', 'synced_language', 'legal_later']) {
        await st.write(key: k, value: 'x');
      }
      outbox.enqueue(conversationId: 5, clientId: 'bekleyen', text: 'gonderilmemis mesaj');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final all0 = await st.readAll();
      expect(all0.keys, containsAll(['access', 'refresh', 'outbox_v1']));
      await s.signOut(remote: false);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final left = (await st.readAll()).keys.toSet();
      // ignore: avoid_print
      print('S2.9b cikis sonrasi kalan guvenli depo anahtarlari: $left');
      expect(left.difference(deviceKeys), isEmpty, reason: 'cikista kullaniciya ozel anahtar kalmamali: $left');
      for (final k in ['access', 'refresh', 'outbox_v1', 'outbox_v1_corrupt', 'recent_searches', 'academic_reminders', 'synced_language', 'legal_later']) {
        expect(left.contains(k), isFalse, reason: '$k cikista silinmedi');
      }
      for (final k in deviceKeys) {
        expect(left.contains(k), isTrue, reason: 'cihaza ozel $k silinmemeli');
        await st.delete(key: k);
      }
    });

    test('S2.10 hesap degisimi: A cikis, B giris -> A verisi onbellekten B\'ye SIZMAZ (sirali durum)', () async {
      var serve = 'A';
      final client = MockClient((r) async => http.Response(jsonEncode({'who': serve}), 200, headers: {'etag': '"$serve"'}));
      final (s, _, _) = await world(client);
      await s.api.setTokens(Tokens(_jwt(1), 'rA'));
      expect((await s.api.get('/events'))['who'], 'A');
      await s.signOut(remote: false);
      serve = 'B';
      await s.api.setTokens(Tokens(_jwt(2), 'rB'));
      expect((await s.api.get('/events'))['who'], 'B');
    });

    test('S2.11 KOSUL: A\'nin ucustaki GET isteği cikis+B girisinden SONRA doner -> yanit B\'nin onbellegine yazilir (anahtarda kullanici yok)', () async {
      final gate = Completer<void>();
      var n = 0;
      final client = MockClient((r) async {
        n++;
        if (n == 1) {
          await gate.future; // A'nin yavas istegi
          return http.Response(jsonEncode({'who': 'A', 'joined': true}), 200, headers: {'etag': '"A1"'});
        }
        return http.Response(jsonEncode({'who': 'B', 'joined': false}), 200, headers: {'etag': '"B1"'});
      });
      final (s, _, _) = await world(client);
      await s.api.setTokens(Tokens(_jwt(1), 'rA'));
      final inflight = s.api.get('/events'); // A'nin istegi havada
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await s.signOut(remote: false);
      await s.api.setTokens(Tokens(_jwt(2), 'rB')); // B giris
      gate.complete();
      // A'nin yaniti artik atilir: SESSION_CHANGED (B'nin onbellegine yazilmaz).
      await expectLater(inflight, throwsA(isA<ApiError>().having((e) => e.code, 'code', 'SESSION_CHANGED')));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final b = await s.api.get('/events'); // B ayni ekrani acti
      // ignore: avoid_print
      print('S2.11 B\'nin gordugu: $b ; ag istegi sayisi: $n');
      expect(b['who'], 'B', reason: 'A\'nin yaniti B\'ye (20 dk taze pencere) servis edildi');
    });

    test('S2.12 SESSION_CHANGED: ucustaki GET, cikista iptal olur ve onbellege YAZILMAZ', () async {
      final gate = Completer<void>();
      var n = 0;
      final client = MockClient((r) async {
        n++;
        if (n == 1) await gate.future;
        return http.Response(jsonEncode({'who': n == 1 ? 'A' : 'B'}), 200, headers: {'etag': '"e$n"'});
      });
      final (s, _, _) = await world(client);
      await s.api.setTokens(Tokens(_jwt(1), 'rA'));
      final inflight = s.api.get('/events');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await s.signOut(remote: false);
      gate.complete();
      await expectLater(inflight, throwsA(isA<ApiError>().having((e) => e.code, 'code', 'SESSION_CHANGED')));
      final peek = await s.api.peekCache('/events');
      expect(peek, isNull, reason: 'eski oturumun yaniti onbellege girmemeli');
    });

    test('S2.13 tek ucus: ayni GET eszamanli iki kez cagrilirsa TEK ag istegi; force ayri istek', () async {
      var n = 0;
      final gate = Completer<void>();
      final client = MockClient((r) async {
        n++;
        await gate.future;
        return http.Response(jsonEncode({'n': n}), 200, headers: {'etag': '"x"'});
      });
      final (s, _, _) = await world(client);
      await s.api.setTokens(Tokens(_jwt(1), 'rA'));
      final a = s.api.get('/me/summary');
      final b = s.api.get('/me/summary');
      await Future<void>.delayed(const Duration(milliseconds: 300)); // disk onbellegi aramasi gercek IO
      expect(n, 1);
      final c = s.api.get('/me/summary', force: true);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(n, 2);
      gate.complete();
      final r = await Future.wait([a, b, c]);
      expect(r[0], r[1]);
    });

    test('S5.x REFRESH yarisi: cikis sirasinda suren refresh sonucu belirtecleri GERI YAZAR (cikis yapilmis oturum hortlar)', () async {
      final gate = Completer<void>();
      final client = MockClient((r) async {
        if (r.url.path.endsWith('/auth/refresh')) {
          await gate.future;
          return http.Response(jsonEncode({'accessToken': _jwt(1), 'refreshToken': 'r2'}), 200);
        }
        return http.Response('{}', 200);
      });
      final (s, _, _) = await world(client);
      s.api.tokens = Tokens(_jwt(1), 'r1');
      s.state = SessionState.signedIn;
      final rf = s.api.refresh();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await s.signOut(remote: false);
      expect(s.api.tokens, isNull);
      gate.complete();
      // Yenileme sonucu atilir: cagirana SESSION_CHANGED doner, belirtec geri yazilmaz.
      await expectLater(rf, throwsA(isA<ApiError>().having((e) => e.code, 'code', 'SESSION_CHANGED')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // ignore: avoid_print
      print('S5.x cikis sonrasi tokens: ${s.api.tokens == null ? "null" : "DOLU (hortladi)"} state=${s.state}');
      final stored = await const FlutterSecureStorage().read(key: 'refresh');
      // ignore: avoid_print
      print('S5.x secure storage refresh: $stored');
      expect(s.api.tokens, isNull);
      expect(stored, isNull);
    });
  });

  group('S3 ETag / onbellek', () {
    ApiClient mk(MockClient c, {DiskCache? disk}) => ApiClient(client: c, retryDelay: Duration.zero, diskCache: disk, connectivity: ConnectivityService());

    test('S3.1 taze pencere (20 dk): ikinci GET agi KULLANMAZ; force ag; yazma sonrasi ag', () async {
      var n = 0;
      final api = mk(MockClient((r) async {
        n++;
        return http.Response('{"n":$n}', 200, headers: {'etag': '"e$n"'});
      }));
      await api.get('/news');
      await api.get('/news');
      expect(n, 1);
      await api.get('/news', force: true);
      expect(n, 2);
      await api.post('/events/1/rsvp', {});
      await api.get('/events');
      await api.get('/events');
      expect(n, 4); // news, news(force), post, events
    });

    test('S3.2 yazma->liste gecersizleme matrisi', () async {
      final calls = <String>[];
      final api = mk(MockClient((r) async {
        calls.add('${r.method} ${r.url.path}');
        return http.Response('{"ok":true}', 200, headers: {'etag': '"x"'});
      }));
      final cases = <(String, String, String, String?)>[
        // (yazma yontemi, yazma yolu, etkilenen liste, not)
        ('POST', '/events/1/rsvp', '/events', null),
        ('DELETE', '/events/1/rsvp', '/events', null),
        ('POST', '/events/1/applications', '/events', null),
        ('POST', '/events/1/check-in', '/events', null),
        ('POST', '/communities/1/join', '/communities', null),
        ('DELETE', '/communities/1/membership', '/communities', null),
        ('POST', '/communities/1/requests/5/approve', '/communities', null),
        ('POST', '/communities/1/chat-room/join', '/communities', null),
        ('POST', '/events', '/events?communityId=1', null),
        ('PATCH', '/events/1', '/events', null),
        ('POST', '/communities', '/communities', null),
        ('POST', '/communities/1/events', '/events?communityId=1', 'farkli segment'),
        ('POST', '/legal/accept', '/legal/documents', null),
        ('POST', '/polls/3/vote', '/menu/today', 'menu puani menu govdesinde ise'),
        ('POST', '/bookmarks/news/4', '/news', 'favori isareti haber listesinde ise'),
        ('PATCH', '/users/me', '/communities', 'kulup listesi kullaniciya gore degisir mi'),
        ('POST', '/users/9/block', '/events', 'engellenen kullanicinin etkinlikleri'),
        ('POST', '/users/me/avatar', '/communities', 'n/a'),
      ];
      final rows = <String>[];
      for (final (m, w, list, note) in cases) {
        calls.clear();
        await api.get(list); // onbellege al
        calls.clear();
        await api.get(list); // taze: ag yok
        final freshOk = calls.isEmpty;
        await api.send(m, w);
        calls.clear();
        await api.get(list);
        final refetched = calls.any((c) => c.startsWith('GET'));
        rows.add('${refetched ? "YENILER" : "BAYAT  "} | $m $w -> GET $list | ilk-taze:$freshOk | ${note ?? ""}');
        api.clearCache();
      }
      // ignore: avoid_print
      print('S3.2 matris:\n${rows.join("\n")}');
    });

    test('S3.3 YARIS: GET havadayken yazma biter -> eski yanit "taze" damgalanir (yazma sonrasi 20 dk bayat)', skip: _t106, () async {
      final gate = Completer<void>();
      var listVersion = 'old';
      var n = 0;
      final api = mk(MockClient((r) async {
        if (r.method == 'GET') {
          final snapshot = listVersion; // sunucu isteği yazmadan ONCE isledi
          n++;
          await gate.future;
          return http.Response('{"v":"$snapshot"}', 200, headers: {'etag': '"$snapshot"'});
        }
        listVersion = 'new';
        return http.Response('{}', 200);
      }));
      final g = api.get('/events');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await api.post('/events/1/rsvp', {});
      await Future<void>.delayed(const Duration(milliseconds: 40));
      gate.complete();
      await g;
      final again = await api.get('/events');
      // ignore: avoid_print
      print('S3.3 yazma sonrasi liste: $again ; GET sayisi: $n');
      expect(again['v'], 'new');
    });

    test('S3.3b POST zaman asimi (sunucu isledi, yanit yok) -> gecersizleme YOK: liste 20 dk bayat', skip: _t106, () async {
      var n = 0;
      var failPost = true;
      final api = mk(MockClient((r) async {
        if (r.method == 'POST' && failPost) throw http.ClientException('timeout');
        n++;
        return http.Response('{"v":$n}', 200, headers: {'etag': '"$n"'});
      }));
      await api.get('/events');
      try {
        await api.post('/events/1/rsvp', {});
      } catch (_) {}
      failPost = false;
      final before = n;
      await api.get('/events');
      // ignore: avoid_print
      print('S3.3b liste agdan yenilendi mi: ${n > before}');
      expect(n > before, isTrue);
    });

    test('S3.4 5xx: onbellek varsa BAYAT sunulur (503 once 1 tekrar); yoksa ApiError', () async {
      var mode = 'ok';
      var gets = 0;
      final api = mk(MockClient((r) async {
        gets++;
        if (mode == 'ok') return http.Response('{"a":1}', 200, headers: {'etag': '"1"'});
        return http.Response('{"code":"X","message":"m"}', mode == '503' ? 503 : 500);
      }));
      await api.get('/me/communities'); // canli uc (taze degil)
      mode = '503';
      final r = await api.getResponse('/me/communities');
      expect(r.fromCache, isTrue);
      mode = '500';
      final r2 = await api.getResponse('/me/communities');
      expect(r2.fromCache, isTrue);
      final fresh = mk(MockClient((r) async => http.Response('{"code":"SERVER_ERROR","message":"m"}', 500)));
      await expectLater(fresh.get('/me/communities'), throwsA(isA<ApiError>().having((e) => e.status, 'status', 500)));
      expect(gets >= 3, isTrue);
    });

    test('S3.5 CAPTIVE PORTAL: 200 + HTML govde -> body null "basari", diske null yazilir, 20 dk taze pencerede null servis edilir', () async {
      var portal = true;
      var n = 0;
      final api = mk(
          MockClient((r) async {
            n++;
            if (portal) return http.Response('<html><body>Wi-Fi giris</body></html>', 200, headers: {'content-type': 'text/html'});
            return http.Response(jsonEncode({'items': [1]}), 200, headers: {'etag': '"g"'});
          }),
          disk: DiskCache(dirProvider: () async => Directory('${root.path}/api_cache')));
      // JSON olmayan 200 govde hata sayilir (BAD_RESPONSE), onbellege/diske YAZILMAZ ve baglanti "cevrimici" sayilmaz.
      await expectLater(api.get('/news?page=0'), throwsA(isA<ApiError>().having((e) => e.code, 'code', 'BAD_RESPONSE')));
      portal = false;
      final second = await api.get('/news?page=0');
      // ignore: avoid_print
      print('S3.5 portal gittikten sonra: $second ; ag istegi: $n');
      expect(second, isNotNull);
      expect((second as Map)['items'], [1]);
      expect(n, 2, reason: 'portal yaniti taze pencerede servis edilmemeli: ikinci istek AGA gider');
    });

    test('S3.6 304 govdesiz yanit + onbellek yok (proxy hatasi) -> ApiError, bos veri degil', () async {
      final api = mk(MockClient((r) async => http.Response('', 304)));
      try {
        final v = await api.get('/news');
        // ignore: avoid_print
        print('S3.6 304 cached=null donen: $v');
        fail('beklenen ApiError, donen: $v');
      } on ApiError catch (e) {
        expect(e.status, 304);
      }
    });

    test('S3.7 DiskCache tavanlari: 400 kayit, 512KB girdi, 16MB toplam', () async {
      final d = DiskCache(dirProvider: () async => Directory('${root.path}/dc'));
      for (var i = 0; i < 450; i++) {
        await d.write('k$i', {'i': i}, {'etag': '"$i"'}, const Duration(days: 1));
      }
      expect(d.length, 400);
      expect(await d.read('k0'), isNull);
      expect(await d.read('k449'), isNotNull);
      await d.write('big', {'s': 'x' * 600000}, {}, const Duration(days: 1));
      expect(await d.read('big'), isNull);
      for (var i = 0; i < 40; i++) {
        await d.write('m$i', {'s': 'y' * 500000}, {}, const Duration(days: 1));
      }
      expect(d.totalBytes, lessThanOrEqualTo(16 * 1024 * 1024));
      // dizin diske yazilmadan oldurulur (2 sn debounce): artik dosyalar yeni acilista temizlenir
      final d2 = DiskCache(dirProvider: () async => Directory('${root.path}/dc'));
      final r = await d2.read('m39');
      // ignore: avoid_print
      print('S3.7 dizin flush edilmeden olum sonrasi okunan: ${r == null ? "YOK (veri diskte var ama yok sayilip silinir)" : "var"}');
    });

    test('S3.8 buyuk yanit: >256KB izolat cozumu dogru; Content-Length YOK iken 20MB tavani uygulanmaz', skip: _t106, () async {
      final bigList = {'items': List.generate(8000, (i) => {'id': i, 'title': 'baslik ' * 6})};
      final api = mk(MockClient((r) async => http.Response(jsonEncode(bigList), 200, headers: {'etag': '"b"'})));
      final v = await api.get('/news');
      expect((v['items'] as List).length, 8000);
      // chunked (contentLength null) 25MB
      final huge = MockClient.streaming((req, body) async {
        final s = Stream<List<int>>.fromIterable(List.generate(25, (_) => Uint8List(1024 * 1024)..fillRange(0, 1024 * 1024, 32)));
        return http.StreamedResponse(s, 200, headers: {'content-type': 'application/json'});
      });
      final api2 = mk(huge);
      Object? out;
      try {
        out = await api2.get('/news');
      } catch (e) {
        out = e;
      }
      // ignore: avoid_print
      print('S3.8 25MB chunked yanit sonucu: ${out.runtimeType}');
      expect(out, isA<ApiError>(), reason: 'RESPONSE_TOO_LARGE yalniz Content-Length varken');
    });

    test('S3.9 token yenilemede onbellek korunur; ilk giris/cikista temizlenir', () async {
      var n = 0;
      final api = mk(MockClient((r) async {
        n++;
        return http.Response('{"n":$n}', 200, headers: {'etag': '"e"'});
      }));
      await api.setTokens(Tokens('a', 'r'));
      await api.get('/news');
      await api.setTokens(Tokens('a2', 'r2')); // refresh
      await api.get('/news');
      expect(n, 1);
      await api.setTokens(null);
      await api.setTokens(Tokens('b', 'rb'));
      await api.get('/news');
      expect(n, 2);
    });
  });
}

String _jwt(int sub) {
  String b(Map m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${b({'alg': 'none'})}.${b({'sub': '$sub', 'exp': DateTime.now().add(const Duration(minutes: 15)).millisecondsSinceEpoch ~/ 1000})}.sig';
}

extension on ApiClient {
  Future<dynamic> send(String m, String p) => switch (m) {
        'POST' => post(p, {}),
        'DELETE' => delete(p),
        'PATCH' => patch(p, {}),
        _ => put(p, {}),
      };
}
