import { useCallback, useEffect, useRef, useState, type ReactNode } from 'react';
import { useI18n } from '../../i18n/I18nProvider';
import styles from './Mobile.module.css';

export interface ScrollShadowProps {
  children: ReactNode;
  /** Bölgenin erişilebilir adı (varsayılan: "Yana kaydırılabilir alan"). */
  ariaLabel?: string;
  /** Taşma varken ve henüz kaydırılmamışken "yana kaydırın" ipucunu göster (yalnız dar ekran/dokunmatik). */
  hint?: boolean;
  className?: string;
}

/**
 * Yatay kaydırmalı kap: geniş içerik (tablo, geniş grafik) sayfayı yatay taşırmaz, kendi içinde kayar.
 * Taşan kenarda gölge belirir; klavye ile odaklanıp ok tuşlarıyla kaydırılır. RTL'de başlangıç kenarı sağdır.
 */
export function ScrollShadow({ children, ariaLabel, hint = true, className }: ScrollShadowProps) {
  const { t } = useI18n();
  const ref = useRef<HTMLDivElement>(null);
  const [edge, setEdge] = useState({ start: false, end: false, scrolled: false });

  const update = useCallback(() => {
    const el = ref.current;
    if (!el) return;
    const max = el.scrollWidth - el.clientWidth;
    // RTL'de scrollLeft negatiftir: mutlak değer, başlangıç kenarından uzaklıktır
    const pos = Math.abs(el.scrollLeft);
    setEdge((prev) => {
      const next = { start: pos > 1, end: max > 1 && pos < max - 1, scrolled: prev.scrolled || pos > 8 };
      return next.start === prev.start && next.end === prev.end && next.scrolled === prev.scrolled ? prev : next;
    });
  }, []);

  useEffect(() => {
    update();
    const el = ref.current;
    if (!el) return undefined;
    const RO = (globalThis as { ResizeObserver?: typeof ResizeObserver }).ResizeObserver;
    const ro = RO ? new RO(update) : null;
    ro?.observe(el);
    if (el.firstElementChild) ro?.observe(el.firstElementChild);
    window.addEventListener('resize', update);
    return () => {
      ro?.disconnect();
      window.removeEventListener('resize', update);
    };
  }, [update]);

  return (
    <div className={`${styles.shadowWrap} ${className ?? ''}`} data-start={edge.start} data-end={edge.end}>
      <div
        ref={ref}
        className={styles.scroller}
        tabIndex={0}
        role="region"
        aria-label={ariaLabel ?? t('admin.kit.scroll.region')}
        onScroll={update}
      >
        {children}
      </div>
      <span className={`${styles.shade} ${styles.shadeStart}`} aria-hidden="true" />
      <span className={`${styles.shade} ${styles.shadeEnd}`} aria-hidden="true" />
      {hint && edge.end && !edge.scrolled && (
        <p className={styles.scrollHint} aria-hidden="true">
          {t('admin.kit.scroll.hint')}
        </p>
      )}
    </div>
  );
}
