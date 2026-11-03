import type { ReactNode } from 'react';
import { useStoreLinks } from '../../../api/hooks';
import { ContourBackdrop } from '../../../components/ui';
import { Reveal } from './Reveal';
import { StoreButton } from './StoreButton';
import styles from './CtaBand.module.css';

interface Props {
  title: ReactNode;
  text?: ReactNode;
  /** Rozetlerin altına ek içerik (örn. gizlilik bağlantısı). */
  children?: ReactNode;
}

/**
 * Sayfa sonu çağrısı: lacivert kart içinde (dağ konturu zeminli) başlık + kısa cümle solda, iki mağaza rozeti sağda
 * (mobilde ortalı, alt alta).
 * Bağlantılar `useStoreLinks()` ile gelir; boşsa rozetler "Yakında" olur (uydurma adres yok).
 */
export function CtaBand({ title, text, children }: Props) {
  const stores = useStoreLinks();
  return (
    <section className={styles.wrap} aria-labelledby="cta-title">
      <div className="container">
        <Reveal className={styles.card}>
          <ContourBackdrop className={styles.contour} />
          <div className={styles.copy}>
            <h2 id="cta-title" className={styles.title}>
              {title}
            </h2>
            {text && <p className={styles.text}>{text}</p>}
          </div>
          <div className={styles.action}>
            <div className={styles.badges}>
              <StoreButton store="android" href={stores.android} size="lg" note={false} onDark />
              <StoreButton store="ios" href={stores.ios} size="lg" note={false} onDark />
            </div>
            {children}
          </div>
        </Reveal>
      </div>
    </section>
  );
}
