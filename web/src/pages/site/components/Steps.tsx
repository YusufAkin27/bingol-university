import type { ReactNode } from 'react';
import { Reveal } from './Reveal';
import styles from './Steps.module.css';

export interface StepItem {
  title: ReactNode;
  /** Boşsa yalnız başlık gösterilir. */
  text?: ReactNode;
}

/**
 * Sade "nasıl çalışır" adımları: numaralı sıralı liste (masaüstünde yan yana, mobilde alt alta).
 * Numara süstür (CSS sayacı); anlam <ol> ve metinde kalır.
 */
export function Steps({ items }: { items: StepItem[] }) {
  return (
    <ol className={styles.steps}>
      {items.map((s, i) => (
        <li key={i}>
          <Reveal delay={i * 90} className={styles.step}>
            <h3 className={`${styles.title} ${s.text ? '' : styles.solo}`}>{s.title}</h3>
            {s.text && <p className={styles.text}>{s.text}</p>}
          </Reveal>
        </li>
      ))}
    </ol>
  );
}
