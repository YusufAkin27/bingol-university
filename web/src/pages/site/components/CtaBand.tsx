import type { ReactNode } from 'react';
import { useStoreLinks } from '../../../api/hooks';
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
 * Sayfa sonu çağrısı: yumuşak bir kart içinde başlık + kısa cümle + iki mağaza rozeti.
 * Bağlantılar `useStoreLinks()` ile gelir; boşsa rozetler "Yakında" olur (uydurma adres yok).
 */
export function CtaBand({ title, text, children }: Props) {
  const stores = useStoreLinks();
  return (
    <section className={styles.wrap} aria-labelledby="cta-title">
      <div className="container">
        <Reveal className={styles.card}>
          <h2 id="cta-title" className={styles.title}>
            {title}
          </h2>
          {text && <p className={styles.text}>{text}</p>}
          <div className={styles.badges}>
            <StoreButton store="android" href={stores.android} size="lg" note={false} />
            <StoreButton store="ios" href={stores.ios} size="lg" note={false} />
          </div>
          {children}
        </Reveal>
      </div>
    </section>
  );
}
