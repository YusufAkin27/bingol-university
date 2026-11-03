import type { ReactNode } from 'react';
import { ContourBackdrop, Icon } from '../../../components/ui';
import { PhoneMockup } from './PhoneMockup';
import { Reveal } from './Reveal';
import type { ShotId } from './screenshots';
import styles from './FeaturesRow.module.css';

interface Props {
  id: string;
  /** Sıra numarası (1'den): "01 / ..." etiketi. */
  index: number;
  category: ReactNode;
  title: ReactNode;
  text: ReactNode;
  points: ReactNode[];
  shot: ShotId;
  /** İkinci (arka) telefon, örn. etkinlik + QR. */
  secondShot?: ShotId;
  /** `true`: telefon metnin karşı tarafında (RTL'de otomatik aynalanır). */
  flip?: boolean;
  /** Sayfanın ilk ekranındaki telefon için (en çok bir). */
  priority?: boolean;
}

/**
 * Özellikler sayfası satırı: sıra numaralı etiket, başlık, metin, üç madde ve zemin paneli içinde büyük gerçek uygulama
 * ekranı. Başlık h2'dir; satırlar <ul><li> içine konur.
 */
export function FeaturesRow({
  id,
  index,
  category,
  title,
  text,
  points,
  shot,
  secondShot,
  flip,
  priority,
}: Props) {
  return (
    <article className={`${styles.row} ${flip ? styles.flip : ''}`} id={id}>
      <Reveal className={styles.copy}>
        <p className={styles.eyebrow}>
          <span className={styles.num}>{String(index).padStart(2, '0')}</span>
          <span className={styles.slash} aria-hidden="true">
            /
          </span>
          <span>{category}</span>
        </p>
        <h2 className={styles.title}>{title}</h2>
        <p className={styles.text}>{text}</p>
        <ul className={styles.points}>
          {points.map((p, i) => (
            <li key={i}>
              <span className={styles.tick}>
                <Icon name="check" size={16} />
              </span>
              <span>{p}</span>
            </li>
          ))}
        </ul>
      </Reveal>
      <Reveal className={styles.visual} delay={80}>
        <div className={styles.panel}>
          <ContourBackdrop className={styles.contour} />
          <div className={`${styles.phones} ${secondShot ? styles.pair : ''}`}>
            {secondShot && <PhoneMockup shot={secondShot} className={styles.second} />}
            <PhoneMockup shot={shot} className={styles.first} priority={priority} />
          </div>
        </div>
      </Reveal>
    </article>
  );
}
