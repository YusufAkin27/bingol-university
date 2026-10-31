import type { ReactNode } from 'react';
import { PhoneMockup } from './PhoneMockup';
import type { ShotId } from './screenshots';
import { Reveal } from './Reveal';
import styles from './FeatureRow.module.css';

interface Props {
  /** Ana ekran görüntüsü (telefon). */
  shot: ShotId;
  /** İkinci, daha geride duran telefon (örn. etkinlik + QR). */
  secondShot?: ShotId;
  title: ReactNode;
  text: ReactNode;
  /** Başlığın altına ek içerik (bağlantı, madde listesi...). */
  children?: ReactNode;
  /** `true`: telefon metnin karşı tarafında (zikzak). RTL'de otomatik aynalanır. */
  flip?: boolean;
  /** İlk ekrandaki satır için; telefon `fetchpriority=high` ile yüklenir. */
  priority?: boolean;
  id?: string;
}

/**
 * Özellik satırı: telefon + başlık + kısa metin, iki sütun (mobilde alt alta, önce metin). `flip` ile zikzak.
 * Başlık h2'dir; satırları bir <ul><li> içine koyun (liste anlamı korunur).
 */
export function FeatureRow({ shot, secondShot, title, text, children, flip, priority, id }: Props) {
  return (
    <article className={`${styles.row} ${flip ? styles.flip : ''}`} id={id}>
      <Reveal className={styles.copy}>
        <h2 className={styles.title}>{title}</h2>
        <p className={styles.text}>{text}</p>
        {children}
      </Reveal>
      <Reveal className={styles.visual} delay={80}>
        <div className={`${styles.phones} ${secondShot ? styles.pair : ''}`}>
          {secondShot && <PhoneMockup shot={secondShot} className={styles.second} tilt={5} />}
          <PhoneMockup shot={shot} className={styles.first} priority={priority} tilt={secondShot ? -2 : 0} />
        </div>
      </Reveal>
    </article>
  );
}
