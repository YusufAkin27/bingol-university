import { useEffect, useId, useState } from 'react';
import { Icon } from '../../../components/ui';
import { useMediaQuery } from '../../../lib/useMediaQuery';
import styles from './ReadingToc.module.css';

export interface TocItem {
  id: string;
  title: string;
}

/**
 * Kaydırırken hangi bölümün başlığının okuma bandında olduğunu izler (içindekilerde "şu an" işareti).
 * IntersectionObserver yoksa (test, eski tarayıcı) null döner; gezinme çalışmaya devam eder.
 */
export function useActiveSection(ids: string[]): string | null {
  const [active, setActive] = useState<string | null>(null);
  const key = ids.join('|');
  useEffect(() => {
    if (typeof IntersectionObserver === 'undefined' || ids.length === 0) return undefined;
    const els = ids.map((id) => document.getElementById(id)).filter((e): e is HTMLElement => !!e);
    if (els.length === 0) return undefined;
    const visible = new Set<string>();
    const io = new IntersectionObserver(
      (entries) => {
        for (const e of entries) {
          if (e.isIntersecting) visible.add(e.target.id);
          else visible.delete(e.target.id);
        }
        const first = ids.find((id) => visible.has(id));
        if (first) setActive(first);
      },
      // üstte sabit başlık payı + ekranın üst üçte biri: okunan bölüm
      { rootMargin: '-96px 0px -66% 0px' },
    );
    els.forEach((el) => io.observe(el));
    return () => io.disconnect();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key]);
  return active;
}

/** Yazdırma görünümü: site üst/alt bilgisi gizlenir (ReadingToc.module.css `html.print-doc`). */
export function usePrintDoc() {
  useEffect(() => {
    document.documentElement.classList.add('print-doc');
    return () => document.documentElement.classList.remove('print-doc');
  }, []);
}

interface Props {
  items: TocItem[];
  /** nav landmark adı */
  navLabel: string;
  /** Geniş ekranda liste başlığı */
  heading: string;
  /** Dar ekranda açılır düğme metni */
  buttonLabel: string;
  /** Bu genişliğin altında açılır menü olur (px) */
  compactBelow: number;
}

/** Okuma sayfalarının içindekileri: geniş ekranda yapışkan, aktif bölüm işaretli liste; dar ekranda açılır menü. */
export function ReadingToc({ items, navLabel, heading, buttonLabel, compactBelow }: Props) {
  const compact = useMediaQuery(`(max-width: ${compactBelow}px)`);
  const [open, setOpen] = useState(false);
  const panelId = useId();
  const active = useActiveSection(items.map((i) => i.id));
  const links = (
    <ol className={styles.list}>
      {items.map((e) => (
        <li key={e.id}>
          <a
            href={`#${e.id}`}
            className={styles.link}
            aria-current={active === e.id ? 'location' : undefined}
            onClick={() => setOpen(false)}
          >
            {e.title}
          </a>
        </li>
      ))}
    </ol>
  );
  if (compact) {
    return (
      <nav className={`${styles.toc} ${styles.compact}`} aria-label={navLabel}>
        <button
          type="button"
          className={styles.btn}
          aria-expanded={open}
          aria-controls={panelId}
          onClick={() => setOpen((v) => !v)}
        >
          <span>{buttonLabel}</span>
          <Icon name="chevronDown" size={20} className={`${styles.chev} ${open ? styles.chevOpen : ''}`} />
        </button>
        <div id={panelId} hidden={!open} className={styles.panel}>
          {links}
        </div>
      </nav>
    );
  }
  return (
    <nav className={`${styles.toc} ${styles.wide}`} aria-label={navLabel}>
      <p className={styles.title}>{heading}</p>
      {links}
    </nav>
  );
}
