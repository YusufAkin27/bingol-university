import type { ReactNode } from 'react';
import styles from './SectionHeading.module.css';

interface Props {
  title: ReactNode;
  lead?: ReactNode;
  /** Küçük üst etiket (örn. "Özellikler"). */
  eyebrow?: ReactNode;
  /** Başlık düzeyi (varsayılan 2; sayfada tek h1 PageHero/Hero'dadır). */
  level?: 2 | 3;
  /** `center`: ortalı (varsayılan başlangıç hizalı). */
  align?: 'start' | 'center';
  id?: string;
  className?: string;
}

/** Bölüm başlığı: isteğe bağlı üst etiket + başlık + kısa cümle. Tüm vitrin bölümleri aynı ritmi bununla kurar. */
export function SectionHeading({ title, lead, eyebrow, level = 2, align = 'start', id, className }: Props) {
  const H = level === 2 ? 'h2' : 'h3';
  return (
    <header className={`${styles.head} ${align === 'center' ? styles.center : ''} ${className ?? ''}`}>
      {eyebrow && <p className={styles.eyebrow}>{eyebrow}</p>}
      <H id={id} className={styles.title}>
        {title}
      </H>
      {lead && <p className={styles.lead}>{lead}</p>}
    </header>
  );
}
