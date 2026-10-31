import { useId, type ReactNode } from 'react';
import { useStoreLinks } from '../../../api/hooks';
import { PhoneMockup } from './PhoneMockup';
import { Reveal } from './Reveal';
import type { ShotId } from './screenshots';
import { StoreButton } from './StoreButton';
import styles from './AppCallout.module.css';

interface Props {
  shot: ShotId;
  title: ReactNode;
  text: ReactNode;
  /** Mağaza rozetleri gösterilsin mi (varsayılan evet; yalnız anlamlı yerlerde kullanın). */
  stores?: boolean;
  /** Telefon önce (başlangıç tarafı) mi gelsin; varsayılan telefon bitiş tarafında. */
  phoneFirst?: boolean;
  /** Telefonun gösterilecek üst oranı (PhoneMockup `crop`). */
  crop?: number;
  tilt?: number;
  /** Metnin altına ek içerik (bağlantılar, düğmeler). */
  children?: ReactNode;
}

/**
 * Bilgi sayfalarında "bu da uygulamada" bölümü: yumuşak kart içinde kısa metin + (isteğe bağlı) mağaza rozetleri + kısa telefon.
 * Telefon ekranı gerçek uygulama ekran çıktısıdır (screenshots.ts); mobilde metnin altında, >= 760 px yan yana.
 */
export function AppCallout({ shot, title, text, stores = true, phoneFirst, crop = 0.7, tilt = 0, children }: Props) {
  const id = useId();
  const links = useStoreLinks();
  return (
    <section className={styles.wrap} aria-labelledby={id}>
      <div className="container">
        <Reveal className={`${styles.card} ${phoneFirst ? styles.first : ''}`}>
          <div className={styles.copy}>
            <h2 id={id} className={styles.title}>
              {title}
            </h2>
            <p className={styles.text}>{text}</p>
            {stores && (
              <div className={styles.badges}>
                <StoreButton store="android" href={links.android} note={false} />
                <StoreButton store="ios" href={links.ios} note={false} />
              </div>
            )}
            {children}
          </div>
          <div className={styles.shot}>
            <PhoneMockup shot={shot} crop={crop} tilt={tilt} width="min(58vw, 230px)" />
          </div>
        </Reveal>
      </div>
    </section>
  );
}
