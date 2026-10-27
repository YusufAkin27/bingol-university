import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// ORTAK YEREL HATIRLATMA SERVİSİ (ders/sınav vb.). Sunucu bu bildirimleri göndermez.
///
/// KULLANIM (özet):
/// ```dart
/// // 1) Bir grubun tüm hatırlatmalarını tek seferde değiştir (eskiler silinir):
/// await LocalReminders.instance.replaceGroup('academic', [
///   LocalReminder(id: 101, at: DateTime(2026, 11, 3, 8, 50), title: 'Algoritmalar', body: '10 dk sonra',
///       channel: ReminderChannel.academic, payload: {'targetType': 'TIMETABLE'}),
/// ]);
/// // 2) Tek hatırlatma: schedule(group, r) / cancel(group, id) / cancelGroup(group) / cancelAll()
/// // 3) Açılışta/cihaz saati değişince yeniden kurma için sağlayıcı kaydet:
/// LocalReminders.instance.registerProvider('academic', () async => [...]);
/// await LocalReminders.instance.rescheduleAll(); // her sağlayıcıyı çağırıp grubu yeniden kurar
/// ```
/// Kurallar: `id` grup içinde benzersiz (int, 31 bit); geçmiş zamanlı kayıtlar sessizce atlanır; en çok
/// [maxPerGroup] kayıt (en yakınlar tutulur); hiçbir metot exception sızdırmaz. Android: AlarmManager
/// (yaklaşık zaman, tam alarm izni gerekmez) + açılışta yeniden kurma alıcısı. iOS'ta native kod yoksa
/// no-op (desteklenmez, uygulama etkilenmez). Dokunuşta `payload`, [PushRouter] ile aynı anahtarlarla
/// (targetType/targetId...) yönlendirilir; tanınmayan yük Bildirimler listesine düşer.
/// Aynı yöntem kanalı eski `ReminderService` (academic/reminders.dart) için de çalışır
/// (`bu_kampus/academic` -> `replaceReminders` = 'academic' grubu).

/// Android bildirim kanalı kimlikleri (MainActivity'de oluşturulur).
class ReminderChannel {
  ReminderChannel._();
  static const academic = 'academic';
  static const social = 'social';
  static const poll = 'poll';
  static const event = 'event';
}

class LocalReminder {
  const LocalReminder({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
    this.channel = ReminderChannel.academic,
    this.payload = const {},
  });

  final int id;

  /// Gerçek anlık (UTC/yerel fark etmez; epoch ms'e çevrilir).
  final DateTime at;
  final String title, body, channel;
  final Map<String, String> payload;

  Map<String, dynamic> toMap() => {
        'id': id & 0x7fffffff,
        'at': at.millisecondsSinceEpoch,
        'title': title,
        'body': body,
        'channel': channel,
        'payload': payload,
      };

  @override
  String toString() => 'LocalReminder($id, $at, $title)';
}

/// Zamanlama arka ucu (testte sahtesi kullanılır).
abstract class LocalReminderBackend {
  Future<void> replaceGroup(String group, List<LocalReminder> items);

  /// Grubun diğer kayıtlarına dokunmadan ekler/günceller.
  Future<void> upsert(String group, LocalReminder item);
  Future<void> cancel(String group, int id);
  Future<void> cancelGroup(String group);
  Future<void> cancelAll();

  /// Sistem bildirim izni verilmiş mi? (Bilinmiyorsa true.)
  Future<bool> notificationsAllowed();

  /// Uygulama bildirime dokunularak açıldıysa yük (bir kez okunur), yoksa null.
  Future<Map<String, String>?> takeLaunchPayload();
}

class ChannelReminderBackend implements LocalReminderBackend {
  const ChannelReminderBackend();

  static const channel = MethodChannel('bu_kampus/notify');

  Future<T?> _call<T>(String m, [Object? args]) async {
    try {
      return await channel.invokeMethod<T>(m, args);
    } on MissingPluginException {
      return null; // iOS / platform kodu yok
    } on PlatformException catch (e) {
      debugPrint('local reminders $m: ${e.code}');
      return null;
    }
  }

  @override
  Future<void> replaceGroup(String group, List<LocalReminder> items) =>
      _call<void>('replaceGroup', {'group': group, 'items': [for (final i in items) i.toMap()]});

  @override
  Future<void> upsert(String group, LocalReminder item) =>
      _call<void>('upsert', {'group': group, 'item': item.toMap()});

  @override
  Future<void> cancel(String group, int id) => _call<void>('cancel', {'group': group, 'id': id & 0x7fffffff});

  @override
  Future<void> cancelGroup(String group) => _call<void>('cancelGroup', {'group': group});

  @override
  Future<void> cancelAll() => _call<void>('cancelAll');

  @override
  Future<bool> notificationsAllowed() async => (await _call<bool>('notificationsAllowed')) ?? true;

  @override
  Future<Map<String, String>?> takeLaunchPayload() async {
    final r = await _call<Map<Object?, Object?>>('takeLaunchPayload');
    if (r == null || r.isEmpty) return null;
    return {for (final e in r.entries) '${e.key}': '${e.value}'};
  }
}

typedef ReminderProvider = Future<List<LocalReminder>> Function();

class LocalReminders {
  LocalReminders(this.backend, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static LocalReminders instance = LocalReminders(const ChannelReminderBackend());

  static const maxPerGroup = 60;

  final LocalReminderBackend backend;
  final DateTime Function() _clock;
  final Map<String, ReminderProvider> _providers = {};

  /// Geçmiş olanları atar, zamana göre sıralar, [maxPerGroup] ile sınırlar, kimlik tekrarında sonuncuyu tutar.
  @visibleForTesting
  List<LocalReminder> normalize(Iterable<LocalReminder> items) {
    final now = _clock();
    final byId = <int, LocalReminder>{};
    for (final r in items) {
      if (r.at.isAfter(now)) byId[r.id & 0x7fffffff] = r;
    }
    final out = byId.values.toList()..sort((a, b) => a.at.compareTo(b.at));
    return out.length > maxPerGroup ? out.sublist(0, maxPerGroup) : out;
  }

  Future<void> replaceGroup(String group, List<LocalReminder> items) async {
    try {
      await backend.replaceGroup(group, normalize(items));
    } catch (e) {
      debugPrint('replaceGroup($group): $e');
    }
  }

  /// Tek kayıt ekler/günceller (aynı id varsa yer değiştirir). Kısa yol; çok kayıt için [replaceGroup].
  Future<void> schedule(String group, LocalReminder r) async {
    if (!r.at.isAfter(_clock())) return;
    try {
      await backend.upsert(group, r);
    } catch (e) {
      debugPrint('schedule($group): $e');
    }
  }

  Future<void> cancel(String group, int id) async {
    try {
      await backend.cancel(group, id);
    } catch (_) {}
  }

  Future<void> cancelGroup(String group) async {
    try {
      await backend.cancelGroup(group);
    } catch (_) {}
  }

  /// Çıkışta çağır: kullanıcıya özel hatırlatmaların hepsi silinir.
  Future<void> cancelAll() async {
    try {
      await backend.cancelAll();
    } catch (_) {}
  }

  /// Bir grubun kaynağını kaydet; [rescheduleAll] bunu çağırır.
  void registerProvider(String group, ReminderProvider provider) => _providers[group] = provider;

  void unregisterProvider(String group) => _providers.remove(group);

  /// Tüm sağlayıcılardan güncel listeyi alıp grupları yeniden kurar (açılış, saat/saat dilimi değişimi,
  /// ders programı düzenleme sonrası). Bir sağlayıcının hatası diğerlerini etkilemez.
  Future<void> rescheduleAll() async {
    for (final e in _providers.entries.toList()) {
      try {
        await replaceGroup(e.key, await e.value());
      } catch (err) {
        debugPrint('rescheduleAll(${e.key}): $err');
      }
    }
  }
}
