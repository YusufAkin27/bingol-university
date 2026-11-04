import type { ReactNode } from 'react';
import { Icon } from '../../../components/ui';
import { MaintenanceNotice } from './Notices';
import { useHeadingFocus } from './PageHero';
import { PhoneMockup } from './PhoneMockup';
import styles from './FeaturesHero.module.css';

interface Props {
  eyebrow: ReactNode;
  title: string;
  lead: ReactNode;
  note: ReactNode;
}

/** Özellikler sayfası başlığı: ortalı etiket, başlık, cümle, güven notu ve iki büyük gerçek uygulama ekranı. */
export function FeaturesHero({ eyebrow, title, lead, note }: Props) {
  const h1 = useHeadingFocus<HTMLHeadingElement>();
  return (
    <section className={styles.hero}>
      <div className={`container ${styles.inner}`}>
        <MaintenanceNotice />
        <p className={styles.eyebrow}>
          <span className={styles.dot} aria-hidden="true" />
          {eyebrow}
        </p>
        <h1 ref={h1} tabIndex={-1} className={styles.title}>
          {title}
        </h1>
        <p className={styles.lead}>{lead}</p>
        <p className={styles.note}>
          <Icon name="lock" size={18} />
          <span>{note}</span>
        </p>
        <div className={styles.phones}>
          <PhoneMockup shot="home" className={styles.a} priority />
          <PhoneMockup shot="support" className={styles.b} />
        </div>
      </div>
    </section>
  );
}
