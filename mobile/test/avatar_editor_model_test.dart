import 'dart:math' as math;
import 'dart:ui';

import 'package:bu_kampus/features/media_crop/avatar_editor_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Profil fotoğrafı düzenleyicisinin saf mantığı: geometri, sınırlandırma, çıktı yerleşimi, geri al/yinele, renk matrisleri.
void main() {
  const wide = AvatarGeometry(600, 400); // yatay
  const tall = AvatarGeometry(300, 900); // dikey
  const f = AvatarGeometry.frame;

  group('ölçekler', () {
    test('doldur: kısa kenar çerçeveyi kaplar; sığdır: uzun kenar çerçeveye sığar', () {
      expect(wide.fillScale(0), closeTo(f / 400, 1e-9));
      expect(wide.fitScale(0), closeTo(f / 600, 1e-9));
      expect(tall.fillScale(0), closeTo(f / 300, 1e-9));
      expect(tall.fitScale(0), closeTo(f / 900, 1e-9));
      // 90 derece: kare çerçevede aynı
      expect(wide.fillScale(math.pi / 2), closeTo(wide.fillScale(0), 1e-9));
      expect(wide.fitScale(math.pi / 2), closeTo(wide.fitScale(0), 1e-9));
    });

    test('açı verilince doldurma ölçeği büyür (köşe boşluğu kalmasın)', () {
      final a = 10 * math.pi / 180;
      expect(wide.fillScale(a), greaterThan(wide.fillScale(0)));
      final s = const AvatarEditState().copyWith(fine: 10);
      expect(wide.hasBlank(s), isFalse, reason: 'zoom 1 = doldur: boşluk yok');
    });

    test('uzaklaştırma: zoom < 1 izinli ve boşluk görünür; alt sınır sığdırmanın yarısı', () {
      final minZ = wide.minZoom(0);
      expect(minZ, lessThan(wide.fitZoom(0)));
      expect(minZ, closeTo(0.5 * wide.fitScale(0) / wide.fillScale(0), 1e-9));
      expect(wide.clampZoom(0.01, 0), minZ);
      expect(wide.clampZoom(99, 0), AvatarGeometry.maxZoom);
      final out = const AvatarEditState().copyWith(zoom: wide.fitZoom(0));
      expect(wide.hasBlank(out), isTrue, reason: 'yatay görsel sığdırılınca üst/alt boşluk kalır');
    });
  });

  group('ofset sınırlandırma', () {
    test('doldur: kısa kenar yönünde kayma yok, uzun kenarda sınırlı kayma', () {
      const s = AvatarEditState();
      final c = wide.clampOffset(s, const Offset(500, 500));
      expect(c.dy, closeTo(0, 1e-9));
      // görsel genişliği 600*(300/400)=450; çerçeve 300 -> en çok 75
      expect(c.dx, closeTo(75, 1e-6));
      expect(wide.clampOffset(s, const Offset(-500, 0)).dx, closeTo(-75, 1e-6));
    });

    test('döndürülmüş doldurmada sınırlanan her ofsette köşe boşluğu olmaz', () {
      for (final deg in [-40.0, -12.5, 3.0, 25.0, 45.0]) {
        for (final z in [1.0, 1.7, 3.2]) {
          final s = AvatarEditState(fine: deg, zoom: z);
          for (final raw in const [Offset(400, 400), Offset(-400, 250), Offset(0, -500), Offset(123, -77)]) {
            final c = wide.clampOffset(s, raw);
            expect(wide.hasBlank(s.copyWith(offset: c)), isFalse, reason: 'açı $deg zoom $z ham $raw');
          }
        }
      }
    });

    test('uzaklaştırılmışta görsel çerçeve içinde kalır', () {
      final z = tall.fitZoom(0);
      final s = AvatarEditState(zoom: z * .8);
      final c = tall.clampOffset(s, const Offset(400, 400));
      final w = 300 * tall.scale(s), h = 900 * tall.scale(s);
      expect(c.dx.abs() + w / 2, lessThanOrEqualTo(f / 2 + 1e-6));
      expect(c.dy.abs() + h / 2, lessThanOrEqualTo(f / 2 + 1e-6));
    });

    test('normalize: zoom ve ofset aralığa girer', () {
      final n = wide.normalize(const AvatarEditState(zoom: 50, offset: Offset(900, 900)));
      expect(n.zoom, AvatarGeometry.maxZoom);
      expect(wide.clampOffset(n, n.offset), n.offset);
    });
  });

  group('yumuşak sınır (rubber-band)', () {
    test('sınır içinde aynen; dışında taşma sönümlenir ve kısıtlanır', () {
      const s = AvatarEditState();
      expect(wide.rubber(s, const Offset(10, 0)), const Offset(10, 0));
      final r = wide.rubber(s, const Offset(175, 0)); // sınır 75, taşma 100 -> 35
      expect(r.dx, closeTo(75 + 35, 1e-6));
      final far = wide.rubber(s, const Offset(5000, 0));
      expect(far.dx, closeTo(75 + 40, 1e-6), reason: 'maxOver ile kısılır');
    });
  });

  group('hareketler', () {
    test('çift dokunma: doldur <-> sığdır', () {
      const s = AvatarEditState();
      final fit = wide.toggledFit(s);
      expect(fit.zoom, closeTo(wide.fitZoom(0), 1e-9));
      expect(fit.offset, Offset.zero);
      expect(wide.toggledFit(fit).zoom, 1);
    });

    test('90 derece döndürme: tur sayısı dolaşır, zoom/ofset sıfırlanır', () {
      var s = const AvatarEditState(zoom: 2, offset: Offset(10, 4));
      s = wide.rotated(s, 1);
      expect(s.turns, 1);
      expect(s.zoom, 1);
      expect(s.offset, Offset.zero);
      expect(wide.rotated(const AvatarEditState(), -1).turns, 3);
      expect(wide.rotated(wide.rotated(const AvatarEditState(), 1), 3).turns, 0);
    });

    test('ince açı: -45..45 aralığına kırpılır; doldurma korunur', () {
      expect(wide.withFine(const AvatarEditState(), 80).fine, 45);
      expect(wide.withFine(const AvatarEditState(), -80).fine, -45);
      final s = wide.withFine(const AvatarEditState(), 17);
      expect(s.zoom, 1);
      expect(wide.hasBlank(s), isFalse);
    });

    test('zoomedAbout: odak noktası sabit kalır (sınır içinde)', () {
      const s = AvatarEditState(zoom: 2);
      const focal = Offset(20, -10);
      final z = wide.zoomedAbout(s, 3, focal: focal);
      expect(z.zoom, 3);
      // odak altındaki görsel noktası: (focal - offset)/ölçek aynı olmalı (kenara çarpmadıysa)
      final before = (focal - s.offset) / wide.scale(s);
      final after = (focal - z.offset) / wide.scale(z);
      expect(after.dx, closeTo(before.dx, 1e-6));
      expect(after.dy, closeTo(before.dy, 1e-6));
    });
  });

  group('çıktı yerleşimi', () {
    test('1024 çıktıda merkez ve ölçek orantılanır', () {
      const s = AvatarEditState(zoom: 2, offset: Offset(30, -15));
      final p = wide.placement(s, 1024);
      final k = 1024 / f;
      expect(p.cx, closeTo(512 + 30 * k, 1e-9));
      expect(p.cy, closeTo(512 - 15 * k, 1e-9));
      expect(p.scale, closeTo(wide.scale(s) * k, 1e-9));
    });

    test('varsayılanda görselin kısa kenarı tam çıktıyı kaplar', () {
      final p = wide.placement(const AvatarEditState(), 1024);
      expect(400 * p.scale, closeTo(1024, 1e-6));
    });
  });

  group('geri al / yinele', () {
    test('işle, geri al, yinele; yeni işlem yinele listesini temizler; aynı durum yok sayılır', () {
      const a = AvatarEditState(), b = AvatarEditState(flip: true), c = AvatarEditState(turns: 1);
      final h = AvatarHistory(a);
      expect(h.canUndo, isFalse);
      h.push(a); // aynı: yok say
      expect(h.canUndo, isFalse);
      h.push(b);
      h.push(c);
      expect(h.current, c);
      expect(h.undo(), b);
      expect(h.undo(), a);
      expect(h.canUndo, isFalse);
      expect(h.undo(), a, reason: 'boşken sabit');
      expect(h.redo(), b);
      h.push(const AvatarEditState(fine: 5));
      expect(h.canRedo, isFalse);
    });

    test('en az son 10 işlem tutulur (varsayılan 20)', () {
      final h = AvatarHistory(const AvatarEditState());
      for (var i = 1; i <= 30; i++) {
        h.push(AvatarEditState(fine: i.toDouble()));
      }
      expect(h.undoDepth, 20);
      var n = 0;
      while (h.canUndo) {
        h.undo();
        n++;
      }
      expect(n, 20);
      expect(h.current.fine, 10, reason: 'en eski tutulan durum');
    });
  });

  group('renk matrisleri', () {
    test('nötr: özdeşlik; orijinal filtre özdeşlik', () {
      expect(isIdentityMatrix(avatarColorMatrix(AvatarFilter.original, const AvatarAdjust())), isTrue);
      expect(isIdentityMatrix(filterMatrix(AvatarFilter.vivid)), isFalse);
    });

    Color apply(List<double> m, Color c) {
      final r = c.r * 255, g = c.g * 255, b = c.b * 255;
      double ch(int row) => (m[row * 5] * r + m[row * 5 + 1] * g + m[row * 5 + 2] * b + m[row * 5 + 4]).clamp(0, 255);
      return Color.fromARGB(255, ch(0).round(), ch(1).round(), ch(2).round());
    }

    test('siyah-beyaz: gri çıkar; doygunluk -1 de gri', () {
      final m = filterMatrix(AvatarFilter.mono);
      final o = apply(m, const Color(0xFF3070C0));
      expect((o.r - o.g).abs() * 255, lessThan(2));
      expect((o.g - o.b).abs() * 255, lessThan(2));
      final s = apply(avatarColorMatrix(AvatarFilter.original, const AvatarAdjust(saturation: -1)), const Color(0xFF3070C0));
      expect((s.r - s.b).abs() * 255, lessThan(2));
    });

    test('parlaklık artınca açılır; sıcaklık kırmızıyı artırır maviyi azaltır; kontrast ortayı sabit tutar', () {
      const mid = Color(0xFF808080);
      final br = apply(avatarColorMatrix(AvatarFilter.original, const AvatarAdjust(brightness: .5)), mid);
      expect(br.r, greaterThan(mid.r));
      final wm = apply(avatarColorMatrix(AvatarFilter.original, const AvatarAdjust(warmth: 1)), mid);
      expect(wm.r, greaterThan(mid.r));
      expect(wm.b, lessThan(mid.b));
      final ct = apply(avatarColorMatrix(AvatarFilter.original, const AvatarAdjust(contrast: 1)), const Color(0xFF808080));
      expect((ct.r - mid.r).abs() * 255, lessThan(2));
      final ctDark = apply(avatarColorMatrix(AvatarFilter.original, const AvatarAdjust(contrast: 1)), const Color(0xFF404040));
      expect(ctDark.r, lessThan(const Color(0xFF404040).r));
    });

    test('matris çarpımı: önce a sonra b', () {
      final a = filterMatrix(AvatarFilter.warm);
      final id = multiplyColorMatrix(kIdentityMatrix, a);
      for (var i = 0; i < 20; i++) {
        expect(id[i], closeTo(a[i], 1e-9));
      }
    });
  });
}
