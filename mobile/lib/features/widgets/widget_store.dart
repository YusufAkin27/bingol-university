/// Widget paylaşımlı deposu soyutlaması. Üretimde `home_widget` eklentisi (iOS: App Group UserDefaults,
/// Android: SharedPreferences `HomeWidgetPreferences`); testlerde bellek içi. Hata ASLA yukarı sızmaz.
library;

import 'dart:io' show Platform;
import '../../core/swallow.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:home_widget/home_widget.dart';

import 'widget_snapshots.dart';

/// iOS App Group kimliği (BUWidgets uzantısı ve Runner aynı grubu kullanır; Apple Developer'da tanımlanmalı).
const String kWidgetAppGroup = 'group.tr.com.bukampus.app';

abstract class WidgetStore {
  Future<void> put(String key, String value);
  Future<void> remove(String key);
  Future<String?> get(String key);

  /// Widget zaman çizelgelerini yenilettir (iOS reloadTimelines / Android updateAll).
  Future<void> reload(Iterable<WidgetSlug> slugs);

  /// Android: gece yarısından hemen sonra (00:05 İstanbul) menü/ders/etkinlik widget'larını tetikleyecek alarm.
  /// iOS'ta zaman çizelgesi girişleri bunu üstlenir; orada no-op.
  Future<void> scheduleMidnight(DateTime at, Iterable<WidgetSlug> slugs);
}

class HomeWidgetStore implements WidgetStore {
  bool _ready = false;

  bool get _supported => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  Future<bool> _init() async {
    if (!_supported) return false;
    if (_ready) return true;
    try {
      if (Platform.isIOS) await HomeWidget.setAppGroupId(kWidgetAppGroup);
      _ready = true;
    } catch (e) {
      swallow('widget.init', e);
    }
    return _ready;
  }

  @override
  Future<void> put(String key, String value) async {
    if (!await _init()) return;
    try {
      await HomeWidget.saveWidgetData<String>(key, value);
    } catch (e) {
      swallow('widget.put', e);
    }
  }

  @override
  Future<void> remove(String key) async {
    if (!await _init()) return;
    try {
      await HomeWidget.saveWidgetData<String>(key, null);
    } catch (e) {
      swallow('widget.remove', e);
    }
  }

  @override
  Future<String?> get(String key) async {
    if (!await _init()) return null;
    try {
      return await HomeWidget.getWidgetData<String>(key);
    } catch (e) {
      swallow('widget.get', e);
      return null;
    }
  }

  @override
  Future<void> reload(Iterable<WidgetSlug> slugs) async {
    if (!await _init()) return;
    for (final s in slugs) {
      try {
        await HomeWidget.updateWidget(iOSName: s.iosKind, qualifiedAndroidName: s.androidQualified);
      } catch (_) {
        // Widget henüz eklenmemiş / sağlayıcı bulunamadı: sessiz.
      }
    }
  }

  @override
  Future<void> scheduleMidnight(DateTime at, Iterable<WidgetSlug> slugs) async {
    if (!await _init() || !Platform.isAndroid) return;
    for (final s in slugs) {
      try {
        await HomeWidget.scheduleWidgetUpdates([at], qualifiedAndroidName: s.androidQualified);
      } catch (_) {
        // Sağlayıcı/alıcı henüz kayıtlı değil (-6): native aşama tamamlanınca çalışır.
      }
    }
  }
}

/// Testler ve eklenti olmayan ortamlar için bellek içi depo.
class MemoryWidgetStore implements WidgetStore {
  final Map<String, String> data = {};
  final List<Set<WidgetSlug>> reloads = [];
  final List<DateTime> scheduled = [];

  @override
  Future<void> put(String key, String value) async => data[key] = value;

  @override
  Future<void> remove(String key) async => data.remove(key);

  @override
  Future<String?> get(String key) async => data[key];

  @override
  Future<void> reload(Iterable<WidgetSlug> slugs) async => reloads.add(slugs.toSet());

  @override
  Future<void> scheduleMidnight(DateTime at, Iterable<WidgetSlug> slugs) async => scheduled.add(at);
}

/// Hızlı Erişim kısayol sırası (kullanıcıya özel; çıkışta silinir). Boş = varsayılan 8'li liste.
class QuickAccessPrefs {
  static const key = 'widget_quickaccess';
  static const _storage = FlutterSecureStorage();

  static Future<List<String>> load() async {
    try {
      final v = await _storage.read(key: key);
      if (v == null || v.isEmpty) return const [];
      return v.split(',').where((e) => e.isNotEmpty).toList();
    } catch (e) {
      swallow('qa.load', e);
      return const [];
    }
  }

  static Future<void> save(List<String> ids) async {
    try {
      await _storage.write(key: key, value: ids.join(','));
    } catch (e) {
      swallow('qa.save', e);
    }
  }

  static Future<void> clear() async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      swallow('qa.clear', e);
    }
  }
}
