// MOD ortak parçalar (Moderasyon + Destek): katlanabilir süzgeç kutusu. Sayfa ajanı kapsamında; components/ui kitine dokunmaz.
import { useState, type ReactNode } from 'react';
import { useI18n } from '../../../i18n/I18nProvider';
import { useIsNarrow } from '../../../components/ui';
import styles from './v2.module.css';

/**
 * "Filtreler (2 etkin)" kutusu: telefonda kapalı başlar (veri ilk ekranda görünsün), geniş ekranda açık.
 * Etkin süzgeç varsa sayı rozetle gösterilir; içerik kapalıyken de DOM'da kalır.
 */
export function FilterFold({
  activeCount,
  children,
  label,
  anchor,
  defaultOpen,
}: {
  activeCount: number;
  children: ReactNode;
  label?: string;
  anchor?: string;
  /** Telefonda da açık başlasın (örn. süzgeç zorunlu olan sayfa). */
  defaultOpen?: boolean;
}) {
  const { t, formatNumber } = useI18n();
  const narrow = useIsNarrow(640);
  const [userOpen, setUserOpen] = useState<boolean | null>(null);
  const open = userOpen ?? (defaultOpen || !narrow);
  return (
    <details
      className={styles.fold}
      open={open}
      onToggle={(e) => setUserOpen((e.currentTarget as HTMLDetailsElement).open)}
      data-search-anchor={anchor}
    >
      <summary>
        <span>{label ?? t('admin.v2m.filters')}</span>
        {activeCount > 0 && (
          <span className={styles.foldCount}>{t('admin.v2m.filtersActive', { n: formatNumber(activeCount) })}</span>
        )}
      </summary>
      <div className={styles.foldBody}>{children}</div>
    </details>
  );
}

/** Bayt sayısını Türkçe yerel biçimle yazar ("7,57 GB"); ondalık ayırıcı noktadan virgüle döner (X-9). */
export function formatBytesLocal(n: number, formatNumber: (n: number, o?: Intl.NumberFormatOptions) => string): string {
  if (!Number.isFinite(n) || n < 0) return '—';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  let i = 0;
  let x = n;
  while (x >= 1024 && i < units.length - 1) {
    x /= 1024;
    i += 1;
  }
  return `${formatNumber(x, { maximumFractionDigits: i === 0 ? 0 : i >= 3 ? 2 : 1 })} ${units[i]}`;
}
