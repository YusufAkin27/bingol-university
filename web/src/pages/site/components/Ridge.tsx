import styles from './Ridge.module.css';

/**
 * Katmanlı sıradağ siluetleri: Bingöl'ün vadi ve doruk hattı. Son katman sayfa zemin rengidir,
 * böylece koyu bir bölümden içeriğe yumuşak geçiş yapar. Yalnızca süstür.
 */
export function Ridge({ className }: { className?: string }) {
  return (
    <svg
      className={`${styles.ridge} ${className ?? ''}`}
      viewBox="0 0 1440 140"
      preserveAspectRatio="none"
      aria-hidden="true"
      focusable="false"
    >
      <path
        className={styles.far}
        d="M0 96 L90 60 L170 84 L280 30 L380 78 L470 52 L590 96 L700 40 L790 70 L900 22 L1010 74 L1110 48 L1220 88 L1320 44 L1440 82 V140 H0Z"
      />
      <path
        className={styles.mid}
        d="M0 112 L120 82 L210 104 L330 62 L430 100 L560 70 L660 108 L790 76 L890 106 L1000 64 L1120 102 L1240 78 L1340 108 L1440 90 V140 H0Z"
      />
      <path
        className={styles.near}
        d="M0 128 L140 112 L260 124 L400 104 L540 126 L700 110 L860 128 L1010 108 L1160 126 L1300 112 L1440 124 V140 H0Z"
      />
    </svg>
  );
}
