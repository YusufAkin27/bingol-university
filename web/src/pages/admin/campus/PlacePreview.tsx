// Şematik önizleme: gerçek harita karosu YOK (yeni bağımlılık ve harici istek eklememek için). Kampüs sınırını, bina izini ve
// noktayı aynı ölçekte çizer; nokta sınırın dışına düştüyse ya da iz noktadan uzaksa hata gözle hemen görülür.
// Gerçek zemin için "Haritada kontrol et" bağlantısı OpenStreetMap'i yeni sekmede açar.
import { useMemo } from 'react';
import type { LatLng } from '../../../api/adminCampus';
import styles from './campus.module.css';

interface Props {
  /** Erişilebilir ad (ekran okuyucu); durum cümlesi dışarıdan verilir. */
  label: string;
  boundary?: LatLng[];
  footprint?: LatLng[];
  point?: { lat: number; lng: number } | null;
  /** Ek sınıf (yerleşim için). Ayar sekmesinde merkez de `point` olarak çizilir. */
  className?: string;
}

const W = 320;
const PAD = 14;

export function PlacePreview({ label, boundary = [], footprint = [], point, className }: Props) {
  const model = useMemo(() => {
    const all: LatLng[] = [...boundary, ...footprint];
    if (point) all.push([point.lat, point.lng]);
    if (all.length === 0) return null;
    let minLat = Infinity;
    let maxLat = -Infinity;
    let minLng = Infinity;
    let maxLng = -Infinity;
    for (const [la, ln] of all) {
      minLat = Math.min(minLat, la);
      maxLat = Math.max(maxLat, la);
      minLng = Math.min(minLng, ln);
      maxLng = Math.max(maxLng, ln);
    }
    // tek nokta ya da çok küçük kutu: görünür bir pencere aç
    const MIN_SPAN = 0.0015;
    if (maxLat - minLat < MIN_SPAN) {
      const c = (maxLat + minLat) / 2;
      minLat = c - MIN_SPAN / 2;
      maxLat = c + MIN_SPAN / 2;
    }
    if (maxLng - minLng < MIN_SPAN) {
      const c = (maxLng + minLng) / 2;
      minLng = c - MIN_SPAN / 2;
      maxLng = c + MIN_SPAN / 2;
    }
    const k = Math.cos((((minLat + maxLat) / 2) * Math.PI) / 180) || 1; // boylam derecesi enlemde daralır
    const spanX = (maxLng - minLng) * k;
    const spanY = maxLat - minLat;
    const scale = (W - 2 * PAD) / Math.max(spanX, spanY);
    const width = spanX * scale + 2 * PAD;
    const height = spanY * scale + 2 * PAD;
    const project = ([la, ln]: LatLng): [number, number] => [
      PAD + (ln - minLng) * k * scale,
      PAD + (maxLat - la) * scale,
    ];
    const poly = (pts: LatLng[]) => pts.map((p) => project(p).map((n) => n.toFixed(1)).join(',')).join(' ');
    return {
      width,
      height,
      boundary: boundary.length >= 3 ? poly(boundary) : null,
      footprint: footprint.length >= 3 ? poly(footprint) : null,
      point: point ? project([point.lat, point.lng]) : null,
    };
  }, [boundary, footprint, point]);

  if (!model) return null;
  return (
    <svg
      className={`${styles.preview} ${className ?? ''}`}
      viewBox={`0 0 ${model.width.toFixed(1)} ${model.height.toFixed(1)}`}
      role="img"
      aria-label={label}
      data-testid="campus-preview"
    >
      {model.boundary && <polygon points={model.boundary} className={styles.pvBoundary} />}
      {model.footprint && <polygon points={model.footprint} className={styles.pvFootprint} />}
      {model.point && (
        <>
          <circle cx={model.point[0]} cy={model.point[1]} r={9} className={styles.pvHalo} />
          <circle cx={model.point[0]} cy={model.point[1]} r={4.5} className={styles.pvDot} />
        </>
      )}
    </svg>
  );
}
