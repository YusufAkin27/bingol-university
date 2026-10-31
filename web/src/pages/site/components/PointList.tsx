import type { ReactNode } from 'react';
import { Icon, type IconName } from '../../../components/ui';
import { Reveal } from './Reveal';
import styles from './PointList.module.css';

export interface Point {
  icon: IconName;
  text: ReactNode;
}

/** Simgeli kısa madde ızgarası (güvenlik/gizlilik güvenceleri, değerler). Mobilde tek, >=700 px iki sütun. */
export function PointList({ items }: { items: Point[] }) {
  return (
    <ul className={styles.list}>
      {items.map((p, i) => (
        <li key={i}>
          <Reveal delay={(i % 2) * 70} className={styles.item}>
            <span className={styles.ico}>
              <Icon name={p.icon} size={20} />
            </span>
            <span className={styles.text}>{p.text}</span>
          </Reveal>
        </li>
      ))}
    </ul>
  );
}
