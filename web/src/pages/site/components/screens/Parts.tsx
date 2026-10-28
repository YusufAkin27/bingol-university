import type { ReactNode } from 'react';
import { Ico, type IcoName } from './Ico';
import { useScreenKit } from './text';
import styles from './screens.module.css';

export type NavTab = 'home' | 'discover' | 'chat' | 'clubs' | 'profile';

const TABS: { id: NavTab; icon: IcoName }[] = [
  { id: 'home', icon: 'home' },
  { id: 'discover', icon: 'compass' },
  { id: 'chat', icon: 'chat' },
  { id: 'clubs', icon: 'users' },
  { id: 'profile', icon: 'user' },
];

/** Mobil uygulamanın yüzen alt gezinme çubuğu; etkin sekme etiketiyle birlikte genişler. */
export function AppNav({ active }: { active: NavTab | null }) {
  const { s } = useScreenKit();
  return (
    <div className={styles.nav}>
      {TABS.map((tab) =>
        tab.id === active ? (
          <div key={tab.id} className={`${styles.ni} ${styles.niOn}`}>
            <Ico name={tab.icon} />
            {s.nav[tab.id]}
          </div>
        ) : (
          <div key={tab.id} className={styles.ni}>
            <Ico name={tab.icon} />
          </div>
        ),
      )}
    </div>
  );
}

/** Ekran başlığı: büyük başlık + isteğe bağlı yuvarlak eylem düğmesi. */
export function ScreenHeader({ title, action }: { title: string; action?: ReactNode }) {
  return (
    <div className={styles.hd}>
      <div className={styles.hdTitle}>{title}</div>
      {action}
    </div>
  );
}

export function IconButton({ name }: { name: IcoName }) {
  return (
    <div className={styles.ib}>
      <Ico name={name} />
    </div>
  );
}

export function Chips({ items, on = 0 }: { items: string[]; on?: number }) {
  return (
    <div className={styles.chips}>
      {items.map((label, i) => (
        <div key={label} className={`${styles.chip} ${i === on ? styles.chipOn : ''}`}>
          {label}
        </div>
      ))}
    </div>
  );
}

/** Gün şeridi (yemek listesi ve etkinlik ekranları): `days` Ekim 2026 gün numaralarıdır. */
export function DayStrip({ days, on, tall }: { days: number[]; on: number; tall?: boolean }) {
  const { date, num } = useScreenKit();
  return (
    <div className={styles.days}>
      {days.map((d) => (
        <div key={d} className={`${styles.day} ${tall ? styles.dayTall : ''} ${d === on ? styles.dayOn : ''}`}>
          {date(d, { weekday: 'short' })}
          <b>{num(d)}</b>
        </div>
      ))}
    </div>
  );
}

export function Toggle({ on }: { on: boolean }) {
  return (
    <span className={`${styles.switch} ${on ? styles.switchOn : ''}`}>
      <b />
    </span>
  );
}
