import type { ReactNode } from 'react';
import { Icon, type IconName } from '../../../components/ui';
import { Reveal } from './Reveal';
import styles from './Steps.module.css';

export interface StepItem {
  title: ReactNode;
  /** Boşsa yalnız başlık gösterilir. */
  text?: ReactNode;
  /** İsteğe bağlı süs simgesi (yalnız `stack` olmayan kart görünümünde; anlam başlıkta kalır). */
  icon?: IconName;
}

/**
 * "Nasıl çalışır" adımları: numaralı sıralı liste. Varsayılan görünüm üç kart (masaüstünde yan yana, aralarında bağlayıcı çizgi;
 * mobilde alt alta); `stack`: her zaman tek sütun, kartsız (uzun adım cümleleri için). Numara süstür (CSS sayacı);
 * anlam <ol> ve metinde kalır.
 */
export function Steps({ items, stack }: { items: StepItem[]; stack?: boolean }) {
  // stack: tek sütun, başlıklar paragraf (uzun cümlelik adımlar bölüm başlığı sayılmaz; ekran okuyucu başlık listesi temiz kalır)
  const Title = stack ? 'p' : 'h3';
  return (
    <ol className={`${styles.steps} ${stack ? styles.stack : ''}`}>
      {items.map((s, i) => (
        <li key={i}>
          <Reveal delay={i * 90} className={styles.step}>
            <div className={styles.top}>
              <span className={styles.num} aria-hidden="true" />
              {!stack && s.icon && (
                <span className={styles.ico} aria-hidden="true">
                  <Icon name={s.icon} size={22} />
                </span>
              )}
            </div>
            <Title className={`${styles.title} ${s.text ? '' : styles.solo}`}>{s.title}</Title>
            {s.text && <p className={styles.text}>{s.text}</p>}
          </Reveal>
        </li>
      ))}
    </ol>
  );
}
