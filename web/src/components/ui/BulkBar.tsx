import type { ReactNode } from 'react';
import { useI18n } from '../../i18n/I18nProvider';
import { Button } from './Button';
import styles from './BulkBar.module.css';

interface Props {
  /** Seçili satır sayısı; 0 iken çubuk çizilmez. */
  count: number;
  onClear: () => void;
  /** Toplu eylem düğmeleri (ör. gizle, askıya al). Yıkıcı olanlar GuardedAction ile sarılmalı. */
  children?: ReactNode;
}

/** Tablo seçimi için toplu işlem çubuğu: seçim varken tablonun altında yapışık durur. */
export function BulkBar({ count, onClear, children }: Props) {
  const { t } = useI18n();
  if (count <= 0) return null;
  return (
    <div className={styles.bar} role="region" aria-label={t('admin.table.bulkBar')}>
      <span className={styles.count} role="status">
        {t('admin.table.selected', { count })}
      </span>
      <div className={styles.actions}>{children}</div>
      <Button size="sm" variant="ghost" onClick={onClear}>
        {t('admin.table.clearSelection')}
      </Button>
    </div>
  );
}
