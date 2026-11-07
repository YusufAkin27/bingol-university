import type { ReactNode } from 'react';
import { Icon, type IconName } from '../../../components/ui';
import { Reveal } from './Reveal';
import styles from './PointList.module.css';

export interface Point {
  icon: IconName;
  text: ReactNode;
}

interface Props {
  items: Point[];
  /**
   * `2` (varsayılan): >= 700 px iki sütun, simge solda. `4`: dikey kartlar, >= 700 px iki, >= 1040 px dört sütun
   * (simge üstte; kısa 4 güvence için).
   */
  columns?: 2 | 4;
}

/** Simgeli kısa madde ızgarası (güvenlik/gizlilik güvenceleri, değerler). Mobilde tek sütun. */
export function PointList({ items, columns = 2 }: Props) {
  return (
    <ul className={`${styles.list} ${columns === 4 ? styles.four : ''}`}>
      {items.map((p, i) => (
        <li key={i}>
          <Reveal delay={(i % 4) * 70} className={styles.item}>
            <span className={styles.ico}>
              <Icon name={p.icon} size={24} />
            </span>
            <span className={styles.text}>{p.text}</span>
          </Reveal>
        </li>
      ))}
    </ul>
  );
}
