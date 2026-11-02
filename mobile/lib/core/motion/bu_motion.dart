import 'package:flutter/widgets.dart';

/// BÜ Kampüs hareket sistemi: tek merkez (docs/MOBILE_MOTION.md).
///
/// Kişilik: "kurumsal + sıcak". Hızlı 200 ms, standart 300 ms, yavaş 450 ms; abartılı sekme/elastik yok.
/// Başarı geri bildirimi %5-10 taşabilir ([BuCurves.success]), hata taşmaz (sarsıntı için `BuShake`).
/// Yalnız `transform`/`opacity` canlandırılır. "Animasyonları azalt" (erişilebilirlik) açıksa süreler 0 olur
/// ([of]); yeni bileşenler kayma/ölçek yerine yalnız kısa solma kullanır ([reducedFade]).
///
/// ```dart
/// AnimatedOpacity(
///   duration: BuMotion.of(context, BuMotion.durations.quick),
///   curve: BuMotion.curves.standard,
///   ...
/// )
/// ```
abstract final class BuMotion {
  /// Süre kademeleri (ms): micro 120, quick 200, standard 300, slow 450, page 400, dramatic 700.
  static const BuDurations durations = BuDurations();

  /// Eğriler: giriş yavaşlayan, çıkış hızlanan, ekran içi standart.
  static const BuCurves curves = BuCurves();

  /// Etkileşimli (sürükle-bırak, kaydırıp bırakma) yaylar; sabit süreli geçişlerde kullanılmaz.
  static const BuSprings springs = BuSprings();

  // --- Geriye uyumlu adlar (eski kod ve diğer modüller; yeni kodda `durations`/`curves` tercih edin) ---

  /// Mikro etkileşim (anahtar, çip seçimi, alt sayfa kapanışı). = [BuDurations.quick].
  static const Duration short = Duration(milliseconds: 200);

  /// Bileşen geçişi (durum, alt sayfa/diyalog girişi). = [BuDurations.standard].
  static const Duration medium = Duration(milliseconds: 300);

  /// Sayfa/ekran giriş geçişi. = [BuDurations.page].
  static const Duration long = Duration(milliseconds: 400);

  /// Standart: çoğu geçiş için (M3 standard).
  static const Curve standard = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Girişte yavaşlayan vurgulu eğri (öğe belirir).
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Çıkışta hızlanan vurgulu eğri (öğe kaybolur).
  static const Curve emphasizedAccelerate = Cubic(0.3, 0.0, 0.8, 0.15);

  /// İki yönlü vurgulu eğri (konum/boyut değişimi).
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;

  /// Giriş (yavaşlayan) eğri. MD3 "decelerate".
  static const Curve decelerate = Cubic(0.0, 0.0, 0.0, 1.0);

  /// Çıkış (hızlanan) eğri. MD3 "accelerate".
  static const Curve accelerate = Cubic(0.3, 0.0, 1.0, 1.0);

  /// Basma/bırakma ve beğeni gibi mikro geri bildirimde yerleşme: ~%3 taşma.
  static const Curve settle = Cubic(0.34, 1.3, 0.64, 1.0);

  /// Başarı geri bildirimi (onay işareti, kayıt tamam, seçim işareti): ~%7 taşma. Hata için kullanılmaz.
  static const Curve success = Cubic(0.34, 1.56, 0.64, 1.0);

  /// Liste/kademeli girişte öğe gecikmesi: `step × min(index, max)`. Varsayılan 60 ms × en çok 6 = 360 ms
  /// (kademe bütçesi [staggerBudget] altında). [max]'tan sonraki öğeler aynı gecikmeyi alır; uzun listede
  /// yalnız ilk görünür öğeleri canlandırın.
  static Duration stagger(int index, {Duration step = const Duration(milliseconds: 60), int max = 6}) {
    final i = index < 0 ? 0 : (index > max ? max : index);
    final d = step * i;
    return d > staggerBudget ? staggerBudget : d;
  }

  /// Kademeli girişte toplam gecikme üst sınırı (kural: < 500 ms).
  static const Duration staggerBudget = Duration(milliseconds: 480);

  /// Çıkış süresi: girişin %70'i (giriş >= çıkış kuralı).
  static Duration exit(Duration enter) => Duration(milliseconds: (enter.inMilliseconds * 0.7).round());

  /// "Animasyonları azalt" (erişilebilirlik) açık mı? (`MediaQuery.disableAnimations`)
  static bool reduced(BuildContext context) => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  /// [d] süresi; hareket azaltılmışsa sıfır.
  static Duration of(BuildContext context, [Duration d = medium]) => reduced(context) ? Duration.zero : d;

  /// Kayma/ölçek yerine yalnız solma kullanan bileşenler için süre: azaltılmışsa [BuDurations.reducedFade], değilse [d].
  static Duration fadeOf(BuildContext context, [Duration d = medium]) => reduced(context) ? durations.reducedFade : d;

  /// Kaydırma animasyonu (listeyi başa/sona/alıntıya götürme): "animasyonları azalt" açıksa anında atlar
  /// (vestibüler tetikleyici yok); aksi halde [duration] (varsayılan 300 ms) süreyle standart eğriyle kayar.
  /// Denetleyicinin ucu yoksa sessizce geçer.
  static Future<void> scrollTo(BuildContext context, ScrollController controller, double offset,
      {Duration duration = medium, Curve curve = standard}) async {
    if (!controller.hasClients) return;
    final pos = controller.position;
    final target = offset.clamp(pos.minScrollExtent, pos.maxScrollExtent).toDouble();
    if (reduced(context)) {
      controller.jumpTo(target);
      return;
    }
    await controller.animateTo(target, duration: duration, curve: curve);
  }

  /// Süresiz/uzun döngülü (iskelet, yazıyor göstergesi, tarama çizgisi) hareket çalışabilir mi?
  /// Azaltılmış harekette döngüler durur; durum başka yolla (metin/renk) belirtilmelidir.
  static bool loopsAllowed(BuildContext context) => !reduced(context);
}

/// Süre kademeleri.
class BuDurations {
  const BuDurations();

  /// Basma geri bildirimi, ipucu (80-120 ms).
  final Duration micro = const Duration(milliseconds: 120);

  /// Düğme/anahtar/çip, ikon geçişi, alt sayfa çıkışı (150-250 ms).
  final Duration quick = const Duration(milliseconds: 200);

  /// Kart/alt sayfa/diyalog girişi, durum değişimi (250-350 ms).
  final Duration standard = const Duration(milliseconds: 300);

  /// Büyük yüzey, iskelet-içerik, sayaç (400-500 ms).
  final Duration slow = const Duration(milliseconds: 450);

  /// Sayfa geçişi (400 ms; çıkış 0.7×).
  final Duration page = const Duration(milliseconds: 400);

  /// Nadir, vurgulu açılış (splash, kutlama; 600-1200 ms).
  final Duration dramatic = const Duration(milliseconds: 700);

  /// Hata sarsıntısı (300-400 ms aralığının alt ucu; hafif, 2-3 salınım).
  final Duration shake = const Duration(milliseconds: 320);

  /// Azaltılmış harekette tek izin verilen geçiş: kısa solma.
  final Duration reducedFade = const Duration(milliseconds: 100);

  /// Ortam (ambient) döngü periyodu (iskelet ışıltısı vb.; 2-20 sn aralığının alt ucu).
  final Duration ambient = const Duration(milliseconds: 1400);
}

/// Eğri kümeleri (hepsi 0 -> 0, 1 -> 1 uçlu).
class BuCurves {
  const BuCurves();

  /// Ekran içi hareket: MD3 Standard (0.2, 0, 0, 1).
  final Curve standard = BuMotion.standard;

  /// İki yönlü vurgulu (konum/boyut).
  final Curve emphasized = BuMotion.emphasized;

  /// Giriş: vurgulu yavaşlayan (0.05, 0.7, 0.1, 1).
  final Curve emphasizedDecelerate = BuMotion.emphasizedDecelerate;

  /// Çıkış: vurgulu hızlanan.
  final Curve emphasizedAccelerate = BuMotion.emphasizedAccelerate;

  /// Giriş: MD3 Decelerate (0, 0, 0, 1).
  final Curve decelerate = BuMotion.decelerate;

  /// Çıkış: MD3 Accelerate (0.3, 0, 1, 1).
  final Curve accelerate = BuMotion.accelerate;

  /// Basma/bırakma ve beğeni gibi mikro geri bildirimde yerleşme: ~%3 taşma.
  final Curve settle = BuMotion.settle;

  /// Başarı geri bildirimi (onay işareti, kayıt tamam): ~%7 taşma. Hata için kullanılmaz.
  final Curve success = BuMotion.success;

  /// Yalnız ilerleme çubuğu / dönme için (uzamsal harekette kullanmayın).
  final Curve linear = Curves.linear;
}

/// Yay parametreleri (kütle 1). Yalnız etkileşimli, süresi önceden bilinmeyen hareket (sürükle-bırak,
/// kaydırıp bırakma, geri dönüş) içindir; `SpringSimulation(spec, from, to, velocity)` ile kullanılır.
class BuSprings {
  const BuSprings();

  /// Çok sert, taşmasız: ~%0 taşma (sürükleme bırakma).
  final SpringDescription crisp = const SpringDescription(mass: 1, stiffness: 400, damping: 40);

  /// Standart: hafif taşma (rigidlik 300, sönüm 24 -> ~%5).
  final SpringDescription standard = const SpringDescription(mass: 1, stiffness: 300, damping: 24);

  /// Yumuşak, taşmasız (rigidlik 140, sönüm 24 -> kritik üstü).
  final SpringDescription gentle = const SpringDescription(mass: 1, stiffness: 140, damping: 24);
}
