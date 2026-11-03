import { useEffect, useRef, type ReactNode } from 'react';
import { useLocation } from 'react-router-dom';
import { Breadcrumbs, type Crumb } from '../../../components/Breadcrumbs';
import { ContourBackdrop } from '../../../components/ui';
import { MaintenanceNotice } from './Notices';
import styles from './PageHero.module.css';

/** Rota değişiminde sayfa başlığına odaklanır (ekran okuyucu ve klavye kullanıcıları için). */
export function useHeadingFocus<T extends HTMLElement>() {
  const ref = useRef<T>(null);
  const { key } = useLocation();
  useEffect(() => {
    // İlk yüklemede (konum anahtarı "default") odak sayfada kalır, atlama bağlantısı ilk Tab ile çalışır;
    // istemci tarafı rota değişimlerinde odak başlığa taşınır.
    if (key !== 'default') ref.current?.focus({ preventScroll: true });
  }, [key]);
  return ref;
}

interface Props {
  title: string;
  lead?: ReactNode;
  children?: ReactNode;
  /** Küçük üst etiket (örn. "Bağımsız öğrenci uygulaması"). */
  eyebrow?: ReactNode;
  /** Ekmek kırıntısı öğeleri ("Ana sayfa" otomatik eklenir). */
  crumbs?: Crumb[];
  /** `compact`: uzun, içerikten gelen başlıklar (haber başlığı) için daha küçük ve geniş başlık. */
  size?: 'default' | 'compact';
}

/**
 * Tüm iç sayfaların minimal başlık bölümü: bol boşluk, büyük başlık, kısa cümle; zemin sayfa rengidir,
 * üstte çok hafif bir kırmızı ışıma ve sağ kenarda çok soluk dağ konturu (süs, ekran okuyucudan gizli).
 */
export function PageHero({ title, lead, children, eyebrow, crumbs, size = 'default' }: Props) {
  const h1 = useHeadingFocus<HTMLHeadingElement>();
  return (
    <section className={styles.hero}>
      <ContourBackdrop className={styles.contour} />
      <div className={`container ${styles.inner}`}>
        <MaintenanceNotice />
        {crumbs && <Breadcrumbs items={crumbs} />}
        {eyebrow && <p className={styles.eyebrow}>{eyebrow}</p>}
        <h1 ref={h1} tabIndex={-1} className={`${styles.title} ${size === 'compact' ? styles.compact : ''}`}>
          {title}
        </h1>
        {lead && <p className={styles.lead}>{lead}</p>}
        {children}
      </div>
    </section>
  );
}
