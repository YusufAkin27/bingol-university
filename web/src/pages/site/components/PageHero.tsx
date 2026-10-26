import { useEffect, useRef, type ReactNode } from 'react';
import { useLocation } from 'react-router-dom';
import { Breadcrumbs, type Crumb } from '../../../components/Breadcrumbs';
import { ContourBackdrop } from '../../../components/ui';
import { MaintenanceNotice } from './Notices';
import { Ridge } from './Ridge';
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
  /** Ekmek kırıntısı öğeleri ("Ana sayfa" otomatik eklenir). */
  crumbs?: Crumb[];
}

/** İç sayfaların lacivert başlık bölümü: topografik çizgiler, serif başlık, sıradağ geçişi. */
export function PageHero({ title, lead, children, crumbs }: Props) {
  const h1 = useHeadingFocus<HTMLHeadingElement>();
  return (
    <section className={styles.hero}>
      <ContourBackdrop className={styles.art} />
      <div className={`container ${styles.inner}`}>
        <MaintenanceNotice />
        {crumbs && <Breadcrumbs items={crumbs} />}
        <h1 ref={h1} tabIndex={-1} className={styles.title}>
          {title}
        </h1>
        {lead && <p className={styles.lead}>{lead}</p>}
        {children}
      </div>
      <Ridge />
    </section>
  );
}
