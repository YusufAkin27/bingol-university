import 'dart:convert';
import 'dart:io';

import 'package:bu_kampus/core/closed_conversations.dart';
import 'package:bu_kampus/core/push/push_router.dart';
import 'package:bu_kampus/core/push/push_targets.dart';
import 'package:flutter_test/flutter_test.dart';

/// W1-I: yerel güvenlik, native katman ve push yönlendirme güvenliği (T-098, T-100, T-101; T-099 için
/// profil2_test.dart "Verilerim").
///
/// Android dosyaları için statik taramalar: derleme gerektirmez, kırmızı/yeşil davranışı tarif eder.
String _read(String path) => File(path).readAsStringSync();

Map<String, String> _stringsXml(String path) {
  final out = <String, String>{};
  final re = RegExp(r'<string name="([^"]+)">([^<]*)</string>');
  for (final m in re.allMatches(_read(path))) {
    out[m.group(1)!] = m.group(2)!;
  }
  return out;
}

Map<String, dynamic> _arb(String lang) => json.decode(_read('lib/l10n/app_$lang.arb')) as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const manifestPath = 'android/app/src/main/AndroidManifest.xml';
  const kotlinDir = 'android/app/src/main/kotlin/edu/bingol/bu_kampus';

  group('T-098: yerel hatırlatma yükü durum değiştiremez', () {
    test('type=session_replaced artık çıkış üretmez (ölü dal kaldırıldı)', () {
      expect(resolvePushTarget({'type': 'session_replaced'}), const PushTarget(PushDest.notifications));
      expect(resolvePushTarget({'type': 'SESSION_REPLACED'}), const PushTarget(PushDest.notifications));
    });

    test('sanitize: yalnız hedef anahtarları kalır; type/event/target/value atılır', () {
      final out = sanitizeLocalReminderPayload({
        'type': 'session_replaced',
        'event': 'CONVERSATION_CLOSED',
        'target': 'URL',
        'value': 'https://evil.example',
        'commentId': '1',
        'conversationId': '5',
        'targetType': 'TIMETABLE',
        'targetId': 7, // sayı da metne çevrilir
      });
      expect(out, {'conversationId': '5', 'targetType': 'TIMETABLE', 'targetId': '7'});
    });

    test('sanitize: uzun, boş, iç içe ve bozuk değerler atılır; null güvenli', () {
      expect(sanitizeLocalReminderPayload(null), isEmpty);
      expect(sanitizeLocalReminderPayload({'targetType': 'A' * 201}), isEmpty);
      expect(sanitizeLocalReminderPayload({'targetType': 'A' * 200}), {'targetType': 'A' * 200});
      expect(sanitizeLocalReminderPayload({'targetType': '', 'eventId': <String, String>{'a': 'b'}, 'pollId': <int>[1]}), isEmpty);
      expect(sanitizeLocalReminderPayload({1: 'x', 'userId': '3'}), {'userId': '3'});
    });

    test('beyaz liste = spec listesi (Kotlin MainActivity ile aynı)', () {
      const spec = {
        'targetType', 'targetId', 'conversationId', 'eventId', 'postId', 'communityId',
        'newsId', 'ticketId', 'pollId', 'userId', 'announcementId', //
      };
      expect(kLocalReminderPayloadKeys, spec);
      final kt = _read('$kotlinDir/MainActivity.kt');
      final block = RegExp(r'val PAYLOAD_KEYS = setOf\(([^)]*)\)').firstMatch(kt)!.group(1)!;
      final ktKeys = RegExp(r'"([A-Za-z]+)"').allMatches(block).map((m) => m.group(1)!).toSet();
      expect(ktKeys, spec);
    });

    test('yerel kaynaklı sahte CONVERSATION_CLOSED sohbeti kapatmaz; FCM kaynaklı kapatır', () async {
      ClosedConversations.instance.markOpen(4242);
      PushRouter.session = null;
      await PushRouter.open({'event': 'CONVERSATION_CLOSED', 'conversationId': '4242'}, localReminder: true);
      expect(ClosedConversations.instance.isClosed(4242), isFalse, reason: 'yerel yük durum değiştirmemeli');
      await PushRouter.open({'event': 'CONVERSATION_CLOSED', 'conversationId': '4242'});
      expect(ClosedConversations.instance.isClosed(4242), isTrue, reason: 'sunucu push yükü sohbeti kapatır');
      ClosedConversations.instance.markOpen(4242);
    });

    test('yerel yük sanitize sonrası hedefe çözülür (TIMETABLE bozulmaz)', () {
      expect(resolvePushTarget(sanitizeLocalReminderPayload({'targetType': 'TIMETABLE'})), const PushTarget(PushDest.timetable));
      expect(resolvePushTarget(sanitizeLocalReminderPayload({'targetType': 'EXAM'})), const PushTarget(PushDest.exams));
    });

    test('Android: MainActivity imzasız ekstrayı yok sayar, ReminderReceiver imzalar', () {
      final main = _read('$kotlinDir/MainActivity.kt');
      expect(main, contains('LocalReminderStore.verify('));
      // Ham ekstra okuması yalnız trustedPayload içinde olmalı.
      expect('getStringExtra(LocalReminderStore.EXTRA_PAYLOAD)'.allMatches(main).length, 1);
      final rem = _read('$kotlinDir/LocalReminders.kt');
      expect(rem, contains('putExtra(LocalReminderStore.EXTRA_SIG, LocalReminderStore.sign(context, payload))'));
      expect(rem, contains('HmacSHA256'));
    });
  });

  group('T-101: manifest dışa açıklığı', () {
    final manifest = _read(manifestPath);

    test('BootReceiver exported=false', () {
      final m = RegExp(r'<receiver android:name="\.BootReceiver"[^>]*>').firstMatch(manifest)!.group(0)!;
      expect(m, contains('android:exported="false"'));
      expect(m, isNot(contains('android:exported="true"')));
      // Sistem yayınları dinleme listesi yerinde.
      expect(manifest, contains('android.intent.action.BOOT_COMPLETED'));
    });

    test('dışa açık tek bileşen launcher MainActivity', () {
      final exported = RegExp(r'<(activity|receiver|service|provider)\b[^>]*android:exported="true"[^>]*>')
          .allMatches(manifest)
          .map((m) => m.group(0)!)
          .toList();
      expect(exported, hasLength(1), reason: exported.join('\n'));
      expect(exported.single, contains('android:name=".MainActivity"'));
      expect(manifest, contains('android.intent.category.LAUNCHER'));
    });

    test('FileProvider dışa açık değil ve yalnız cache/export/ paylaşır', () {
      final p = RegExp(r'<provider[^>]*>', dotAll: true).firstMatch(manifest)!.group(0)!;
      expect(p, contains('android:exported="false"'));
      expect(p, contains('android:grantUriPermissions="true"'));
      final paths = _read('android/app/src/main/res/xml/export_file_paths.xml');
      expect(RegExp(r'<(cache-path|files-path|external[a-z-]*|root-path)[^>]*>').allMatches(paths).map((m) => m.group(0)!).toList(),
          hasLength(1));
      expect(paths, contains('<cache-path name="export" path="export/" />'));
    });
  });

  group('T-100: Android kanal adları', () {
    const ids = ['chat', 'event', 'announcement', 'social', 'poll', 'academic'];
    final arbKeys = {
      for (final id in ids) id: ('bildirimmobilKanal${id[0].toUpperCase()}${id.substring(1)}', 'p21Chan${id[0].toUpperCase()}${id.substring(1)}Desc'),
    };

    test('Kotlin varsayılanları sabit ASCII-Türkçe metin içermez; kaynak dosyalardan okunur', () {
      final kt = _read('$kotlinDir/LocalReminders.kt');
      // Yalnız kod içindeki dize sabitleri taranır (yorumlar repo kuralı gereği ASCII Türkçe olabilir).
      final code = kt.split('\n').where((l) => !l.trimLeft().startsWith('*') && !l.trimLeft().startsWith('/*')).map((l) {
        final i = l.indexOf('//');
        return i < 0 ? l : l.substring(0, i);
      }).join('\n');
      final literals = RegExp(r'"([^"\n]*)"').allMatches(code).map((m) => m.group(1)!).join('\n').toLowerCase();
      for (final bad in ['begeni', 'hatirlatma', 'sinav', 'kulup', 'sonuclari', 'mesajlari', 'degisiklikler']) {
        expect(literals.contains(bad), isFalse, reason: 'ASCII-leşmiş Türkçe dize: $bad');
      }
      expect(kt, contains('R.string.channel_chat_name'));
      expect(kt, contains('c.getString(defName)'));
    });

    test('values/strings.xml: ASCII-leşmiş Türkçe yok, ARB (tr) ile aynı metin', () {
      final xml = _stringsXml('android/app/src/main/res/values/strings.xml');
      final tr = _arb('tr');
      for (final id in ids) {
        final (nameKey, descKey) = arbKeys[id]!;
        expect(xml['channel_${id}_name'], tr[nameKey], reason: id);
        expect(xml['channel_${id}_desc'], tr[descKey], reason: id);
      }
      for (final v in xml.values) {
        for (final bad in ['begeni', 'hatirlatma', 'sinav', 'kulup', 'sonuclari', 'mesajlari']) {
          expect(v.contains(bad), isFalse, reason: v);
        }
      }
      // Türkçeye özgü diyakritikler gerçekten var.
      expect(xml['channel_social_name'], contains('ğ'));
      expect(xml['channel_academic_name'], contains('ı'));
    });

    for (final lang in ['en', 'ar']) {
      test('values-$lang/strings.xml tüm kanalları ARB ($lang) ile aynı metinle içerir', () {
        final xml = _stringsXml('android/app/src/main/res/values-$lang/strings.xml');
        final arb = _arb(lang);
        for (final id in ids) {
          final (nameKey, descKey) = arbKeys[id]!;
          expect(xml['channel_${id}_name'], arb[nameKey], reason: '$lang $id');
          expect(xml['channel_${id}_desc'], arb[descKey], reason: '$lang $id');
        }
      });
    }
  });
}
