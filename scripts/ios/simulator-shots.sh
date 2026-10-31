#!/usr/bin/env bash
# App Store ekran goruntuleri icin iOS simulatoru yardimcisi (macOS). DOGRULANAMADI: Windows'ta calistirilamaz.
# Kullanim:
#   scripts/ios/simulator-shots.sh prepare "iPhone 17 Pro Max"      # simulatoru ac, durum cubugunu 9:41/tam sarj yap
#   scripts/ios/simulator-shots.sh shot 01_ana_sayfa_tr             # acik simulatorden PNG al -> $OUT/<ad>.png
#   scripts/ios/simulator-shots.sh reset                            # durum cubugu ayarlarini kaldir
# Uygulama: flutter run --release -d <simulator> --dart-define=API_BASE=http://localhost:18080 --dart-define=ALLOW_INSECURE_API=true
#   (yerel tohum yigini: docs/DEV_SEED.md; hesap seed.ayse@bingol.edu.tr; gercek kisi verisi KULLANMAYIN)
# Boyutlar (Apple, 2026): 6.9" iPhone = 1320x2868 (ZORUNLU grup; iPhone 16/17 Pro Max simulatoru dogrudan verir).
#   6.5" yedek (1284x2778) yalniz 6.9" yuklenmezse gerekir. iPad ekran goruntusu: uygulama iPhone-only oldugundan GEREKMEZ.
# NOT: simulatorde APNs yok; push gorselleri Figma/mockup ile yapilmaz, gercek cihaz ekran goruntusu kullanilir.
set -euo pipefail

OUT="${OUT:-store-assets/ios}"
cmd="${1:-}"
case "$cmd" in
  prepare)
    dev="${2:?simulator adi gerekli, orn: iPhone 17 Pro Max}"
    xcrun simctl boot "$dev" 2>/dev/null || true
    open -a Simulator
    xcrun simctl bootstatus "$dev" -b
    xcrun simctl status_bar "$dev" override --time "9:41" --batteryState charged --batteryLevel 100 \
      --cellularMode active --cellularBars 4 --wifiMode active --wifiBars 3 --operatorName ""
    echo "Hazir. Uygulamayi acin, sonra: $0 shot <ad>"
    ;;
  shot)
    name="${2:?dosya adi gerekli}"
    mkdir -p "$OUT"
    xcrun simctl io booted screenshot --type=png "$OUT/$name.png"
    echo "kaydedildi: $OUT/$name.png"
    ;;
  reset)
    xcrun simctl status_bar booted clear
    ;;
  *)
    echo "kullanim: $0 prepare <simulator> | shot <ad> | reset" >&2
    exit 2
    ;;
esac
