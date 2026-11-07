import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/api.dart';
import '../../core/locale_controller.dart';
import '../../core/notify/local_reminders.dart';
import '../../l10n/app_localizations.dart';

/// Günlük menü hatırlatıcısı tercihi (cihazda; varsayılan KAPALI, 11:30).
class MenuReminderSettings {
  const MenuReminderSettings({this.enabled = false, this.minutes = defaultMinutes});

  static const defaultMinutes = 11 * 60 + 30;

  final bool enabled;

  /// Gün başından dakika (0..1439), cihazın yerel saati.
  final int minutes;

  MenuReminderSettings copyWith({bool? enabled, int? minutes}) =>
      MenuReminderSettings(enabled: enabled ?? this.enabled, minutes: minutes ?? this.minutes);

  Map<String, Object?> toJson() => {'on': enabled, 'm': minutes};

  factory MenuReminderSettings.fromJson(Map<String, dynamic> j) {
    final m = j['m'];
    return MenuReminderSettings(
      enabled: j['on'] == true,
      minutes: m is int && m >= 0 && m < 1440 ? m : defaultMinutes,
    );
  }

  @override
  bool operator ==(Object other) => other is MenuReminderSettings && other.enabled == enabled && other.minutes == minutes;

  @override
  int get hashCode => Object.hash(enabled, minutes);
}

abstract class MenuReminderStore {
  Future<MenuReminderSettings> load();
  Future<void> save(MenuReminderSettings s);
}

class SecureMenuReminderStore implements MenuReminderStore {
  const SecureMenuReminderStore();
  static const _key = 'menu_reminder';

  @override
  Future<MenuReminderSettings> load() async {
    try {
      final raw = await const FlutterSecureStorage().read(key: _key);
      if (raw == null) return const MenuReminderSettings();
      return MenuReminderSettings.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
    } catch (_) {
      return const MenuReminderSettings();
    }
  }

  @override
  Future<void> save(MenuReminderSettings s) async {
    try {
      await const FlutterSecureStorage().write(key: _key, value: jsonEncode(s.toJson()));
    } catch (_) {}
  }

  /// Çıkış: kayıt silinir (kullanıcıya özel).
  Future<void> clear() async {
    try {
      await const FlutterSecureStorage().delete(key: _key);
    } catch (_) {}
  }
}

class MemoryMenuReminderStore implements MenuReminderStore {
  MemoryMenuReminderStore([this.value = const MenuReminderSettings()]);
  MenuReminderSettings value;

  @override
  Future<MenuReminderSettings> load() async => value;

  @override
  Future<void> save(MenuReminderSettings s) async => value = s;
}

/// Günlük menü bildirimini yerel hatırlatma altyapısıyla ([LocalReminders]) kurar: önümüzdeki [days] gün için her gün
/// seçilen saatte bir kayıt; uygulama her açılışta pencereyi yeniler. Dokunuşta `targetType=MENU` (bukampus://menu).
/// Hiçbir metot exception sızdırmaz.
class MenuReminderService {
  MenuReminderService({MenuReminderStore? store, LocalReminders? reminders, DateTime Function()? clock})
      : store = store ?? const SecureMenuReminderStore(),
        _reminders = reminders,
        _clock = clock ?? DateTime.now;

  static MenuReminderService instance = MenuReminderService();

  static const group = 'menu';
  static const days = 14;

  final MenuReminderStore store;
  final LocalReminders? _reminders;
  final DateTime Function() _clock;

  LocalReminders get _rem => _reminders ?? LocalReminders.instance;

  /// Plan: bugün seçilen saat geçtiyse yarından başlayarak [days] gün. Saf mantık (testte doğrudan denenir).
  @visibleForTesting
  List<LocalReminder> plan(MenuReminderSettings s, AppLocalizations l) {
    if (!s.enabled) return const [];
    final now = _clock();
    final out = <LocalReminder>[];
    for (var i = 0; i <= days; i++) {
      final base = DateTime(now.year, now.month, now.day + i);
      final at = DateTime(base.year, base.month, base.day, s.minutes ~/ 60, s.minutes % 60);
      if (!at.isAfter(now)) continue;
      if (out.length >= days) break;
      out.add(LocalReminder(
        id: 9000000 + at.year * 10000 + at.month * 100 + at.day,
        at: at,
        title: l.menuRemNotifTitle,
        body: l.menuRemNotifBody,
        channel: ReminderChannel.academic,
        payload: const {'targetType': 'MENU'},
      ));
    }
    return out;
  }

  AppLocalizations get _l => lookupAppLocalizations(LocaleController.current?.locale ?? const Locale('tr'));

  /// Kayıtlı tercihe göre grubu yeniden kurar (kapalıysa siler). Açılışta ve tercih değişince çağrılır.
  Future<void> sync() async {
    try {
      final s = await store.load();
      if (!s.enabled) {
        await _rem.cancelGroup(group);
        return;
      }
      await _rem.replaceGroup(group, plan(s, _l));
    } catch (e) {
      debugPrint('menu reminder sync failed: $e');
    }
  }

  /// Tercihi kaydeder ve zamanlar. Açarken bildirim izni yoksa [requestPermission] çağrılır; verilmezse
  /// tercih KAPALI kalır ve false döner.
  Future<bool> apply(MenuReminderSettings next, {Future<bool> Function()? requestPermission}) async {
    try {
      if (next.enabled && !await _rem.backend.notificationsAllowed()) {
        final ok = requestPermission == null ? false : await requestPermission();
        if (!ok) {
          await store.save(next.copyWith(enabled: false));
          await sync();
          return false;
        }
      }
      await store.save(next);
      await sync();
      return true;
    } catch (e) {
      debugPrint('menu reminder apply failed: $e');
      return false;
    }
  }

  /// Açılışta `LocalReminders.rescheduleAll` bu sağlayıcıyı da çağırsın (cihaz saati/yeniden başlatma sonrası).
  void registerProvider() {
    _rem.registerProvider(group, () async {
      final s = await store.load();
      return plan(s, _l);
    });
  }

  /// Çıkış: tercih sıfırlanır ve bildirimler silinir.
  Future<void> clearUserData() async {
    try {
      await _rem.cancelGroup(group);
      final st = store;
      if (st is SecureMenuReminderStore) {
        await st.clear();
      } else {
        await st.save(const MenuReminderSettings());
      }
    } catch (_) {}
  }
}

/// Açılışta haftalık menüyü sessizce önbelleğe alır (bu ay; ay sonuna 7 günden az kaldıysa gelecek ay da).
/// Çevrimdışıyken menü sayfası bu kayıttan açılır ([CachePolicy]: `/menu` diske 7 gün yazılır). Hata sızdırmaz.
Future<void> prefetchMenu(ApiClient api, {DateTime? now}) async {
  final n = now ?? DateTime.now();
  String ym(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';
  final months = <DateTime>[DateTime(n.year, n.month)];
  if (n.add(const Duration(days: 7)).month != n.month) months.add(DateTime(n.year, n.month + 1));
  for (final m in months) {
    try {
      await api.getResponse('/menu?month=${ym(m)}');
    } catch (_) {}
  }
}
