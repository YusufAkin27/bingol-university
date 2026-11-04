import { ContourBackdrop } from '../../../components/ui';
import styles from './AboutArt.module.css';

/**
 * Hakkımızda illüstrasyonu: lacivert zeminde kabartma (kontur) çizgileri, üst üste binen dağ katmanları,
 * nehir çizgisi ve tek kırmızı nokta. Süstür; ekran okuyuculardan gizlenir. Stok/bina fotoğrafı yoktur.
 */
export function AboutArt({ className }: { className?: string }) {
  return (
    <div className={`${styles.art} ${className ?? ''}`} aria-hidden="true">
      <ContourBackdrop className={styles.contour} />
      <svg className={styles.scene} viewBox="0 0 800 420" preserveAspectRatio="xMidYMax slice" focusable="false">
        <circle className={styles.sun} cx="610" cy="96" r="30" />
        <path className={styles.far} d="M0 300 L120 210 L210 262 L350 150 L480 250 L590 190 L710 270 L800 220 V420 H0 Z" />
        <path className={styles.mid} d="M0 340 L90 280 L190 320 L330 214 L470 316 L600 250 L700 316 L800 270 V420 H0 Z" />
        <path className={styles.near} d="M0 380 L140 330 L260 372 L400 300 L540 368 L690 326 L800 358 V420 H0 Z" />
        <path className={styles.river} d="M-10 408 C 150 372, 260 396, 400 378 S 650 346, 810 372" />
      </svg>
    </div>
  );
}
