// QR çizimi: `qrcode-generator` (bağımlılıksız, hata düzeltme M), satır içi SVG. YALNIZ canlı yoklama sayfası parçası içe aktarır.
// Tarayıcıda taranabilirlik: koyu modüller açık zemin üstünde olmalı. Panel koyu temada da çalıştığından QR HER ZAMAN sabit açık bir
// plaka (`--logo-ink-on-dark`, tema bağımsız beyaz) üzerinde, koyu modüllerle (`--logo-ink-on-light`) çizilir; sessiz bölge (4 modül)
// SVG içindedir.
import qrcode from 'qrcode-generator';
import { memo } from 'react';
import styles from './live.module.css';

const QUIET = 4;

export interface QrPath {
  /** Modül sayısı (kenar). */
  modules: number;
  /** Tüm koyu modüllerin birleşik yolu (satır başına yatay çubuklar). */
  d: string;
}

const cache = new Map<string, QrPath>();

/** Metni QR yoluna çevirir (önbellekli: sonraki kod önceden hesaplanır, geçiş anında bekleme olmaz). */
export function qrPath(text: string): QrPath {
  const hit = cache.get(text);
  if (hit) return hit;
  const qr = qrcode(0, 'M');
  qr.addData(text);
  qr.make();
  const n = qr.getModuleCount();
  let d = '';
  for (let r = 0; r < n; r++) {
    let c = 0;
    while (c < n) {
      if (!qr.isDark(r, c)) {
        c++;
        continue;
      }
      let len = 1;
      while (c + len < n && qr.isDark(r, c + len)) len++;
      d += `M${c + QUIET} ${r + QUIET}h${len}v1h-${len}z`;
      c += len;
    }
  }
  const out = { modules: n, d };
  cache.set(text, out);
  if (cache.size > 8) cache.delete(cache.keys().next().value as string);
  return out;
}

export const QrCode = memo(function QrCode({ value, label }: { value: string; label: string }) {
  const { modules, d } = qrPath(value);
  const size = modules + QUIET * 2;
  return (
    <div className={styles.qrPlate}>
      <svg className={styles.qrSvg} viewBox={`0 0 ${size} ${size}`} role="img" aria-label={label} shapeRendering="crispEdges" data-qr={value}>
        <path d={d} fill="currentColor" />
      </svg>
    </div>
  );
});
