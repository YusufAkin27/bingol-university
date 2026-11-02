import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as g;
import 'package:latlong2/latlong.dart';

/// Konum izni durumu (paket türlerinden bağımsız).
enum CampusPerm { granted, denied, deniedForever, unsupported }

/// Anlık konum: yalnız ekranda çizim ve mesafe için kullanılır. SUNUCUYA GİTMEZ, DİSKE YAZILMAZ, LOGLANMAZ.
class CampusFix {
  const CampusFix(this.point, {this.accuracy = 0, this.heading});

  final LatLng point;

  /// Metre cinsinden yatay doğruluk.
  final double accuracy;

  /// Hareket yönü (derece, kuzeyden saat yönü); yalnız cihaz hareket ederken geçerlidir.
  final double? heading;
}

/// Konum arayüzü; testte [FakeCampusLocationService] ile değiştirilir (`instance`).
abstract class CampusLocationService {
  static CampusLocationService instance = GeolocatorCampusLocation();

  /// Cihaz konum servisi (GPS/ağ) açık mı.
  Future<bool> serviceEnabled();

  /// İzin durumu (istem ÇIKARMAZ).
  Future<CampusPerm> permission();

  /// Sistem izin istemini gösterir.
  Future<CampusPerm> request();

  /// Tek seferlik konum (zaman aşımı olursa null).
  Future<CampusFix?> current();

  /// Konum akışı: YALNIZ ön plan (arka plan konumu yok); abonelik iptal edilince durur.
  Stream<CampusFix> positions();

  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
}

/// `geolocator` (Android FusedLocation/LocationManager, iOS CoreLocation). Arka plan izni/servisi KULLANILMAZ.
class GeolocatorCampusLocation implements CampusLocationService {
  CampusPerm _map(g.LocationPermission p) => switch (p) {
        g.LocationPermission.always || g.LocationPermission.whileInUse => CampusPerm.granted,
        g.LocationPermission.deniedForever => CampusPerm.deniedForever,
        g.LocationPermission.denied => CampusPerm.denied,
        g.LocationPermission.unableToDetermine => CampusPerm.unsupported,
      };

  CampusFix _fix(g.Position p) => CampusFix(
        LatLng(p.latitude, p.longitude),
        accuracy: p.accuracy,
        heading: (p.heading >= 0 && p.speed > .5) ? p.heading : null,
      );

  @override
  Future<bool> serviceEnabled() async {
    try {
      return await g.Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<CampusPerm> permission() async {
    try {
      return _map(await g.Geolocator.checkPermission());
    } catch (e) {
      debugPrint('Konum izni okunamadi: ${e.runtimeType}');
      return CampusPerm.unsupported;
    }
  }

  @override
  Future<CampusPerm> request() async {
    try {
      return _map(await g.Geolocator.requestPermission());
    } catch (e) {
      debugPrint('Konum izni istenemedi: ${e.runtimeType}');
      return CampusPerm.unsupported;
    }
  }

  @override
  Future<CampusFix?> current() async {
    try {
      return _fix(await g.Geolocator.getCurrentPosition(
        locationSettings: const g.LocationSettings(accuracy: g.LocationAccuracy.high, timeLimit: Duration(seconds: 12)),
      ));
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<CampusFix> positions() => g.Geolocator.getPositionStream(
        // 5 m'den küçük kıpırdamalar yayınlanmaz: pil + gereksiz yeniden çizim.
        locationSettings: const g.LocationSettings(accuracy: g.LocationAccuracy.high, distanceFilter: 5),
      ).map(_fix);

  @override
  Future<bool> openAppSettings() async {
    try {
      return await g.Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> openLocationSettings() async {
    try {
      return await g.Geolocator.openLocationSettings();
    } catch (_) {
      return false;
    }
  }
}

/// Testler için bellekte konum servisi.
class FakeCampusLocationService implements CampusLocationService {
  FakeCampusLocationService({this.enabled = true, this.perm = CampusPerm.denied, this.onRequest = CampusPerm.granted, this.fix});

  bool enabled;
  CampusPerm perm;

  /// `request()` sonucu (izin zaten verilmişse/kalıcı reddedilmişse değişmez).
  CampusPerm onRequest;
  CampusFix? fix;
  int requests = 0, settingsOpened = 0, locationSettingsOpened = 0;
  final _ctl = StreamController<CampusFix>.broadcast();

  void emit(CampusFix f) {
    fix = f;
    _ctl.add(f);
  }

  @override
  Future<bool> serviceEnabled() async => enabled;

  @override
  Future<CampusPerm> permission() async => perm;

  @override
  Future<CampusPerm> request() async {
    requests++;
    if (perm == CampusPerm.granted || perm == CampusPerm.deniedForever) return perm;
    return perm = onRequest;
  }

  @override
  Future<CampusFix?> current() async => fix;

  @override
  Stream<CampusFix> positions() => _ctl.stream;

  @override
  Future<bool> openAppSettings() async {
    settingsOpened++;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    locationSettingsOpened++;
    return true;
  }
}
