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
}: {
  activeCount: number;
  children: ReactNode;
  label?: string;
  anchor?: string;
}) {
  const { t, formatNumber } = useI18n();
  const narrow = useIsNarrow(640);
  const [userOpen, setUserOpen] = useState<boolean | null>(null);
  const open = userOpen ?? !narrow;
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
