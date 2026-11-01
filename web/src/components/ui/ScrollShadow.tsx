import { useRef, type ReactNode } from 'react';
import { useI18n } from '../../i18n/I18nProvider';
import styles from './Mobile.module.css';
import { useScrollEdges } from './useScrollEdges';

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
  const { edges: edge, onScroll } = useScrollEdges(ref);

  return (
    <div className={`${styles.shadowWrap} ${className ?? ''}`} data-start={edge.start} data-end={edge.end}>
      <div
        ref={ref}
        className={styles.scroller}
        tabIndex={0}
        role="region"
        aria-label={ariaLabel ?? t('admin.kit.scroll.region')}
        onScroll={onScroll}
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
