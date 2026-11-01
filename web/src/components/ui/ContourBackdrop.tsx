import styles from './ContourBackdrop.module.css';

/**
 * Bingöl dağlarının kabartma (topografik) çizgilerinden esinlenen dekoratif zemin. Çizgiler statik bir SVG
 * dosyasıdır (src/assets/contour.svg; beyaz, opaklığı kullanan sınıf belirler): DOM'a 25+ yol düğümü eklemez,
 * önbelleğe alınır, ilk boyamayı engellemez. Üretici: web/scripts/gen-contour.mjs.
 */
export function ContourBackdrop({ className }: { className?: string }) {
  return <span className={[styles.art, className].filter(Boolean).join(' ')} aria-hidden="true" />;
}
