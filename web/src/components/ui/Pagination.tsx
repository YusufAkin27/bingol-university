import { useI18n } from '../../i18n/I18nProvider';
import { Button, IconButton } from './Button';
import { Icon } from './Icon';
import styles from './Pagination.module.css';

interface PaginationProps {
  /** 0 tabanlı geçerli sayfa */
  page: number;
  totalPages: number;
  onPageChange: (page: number) => void;
  totalItems?: number;
}

/** Sayfa tabanlı sayfalama (`{items,page,totalPages,totalItems}` yanıtları için). */
export function Pagination({ page, totalPages, onPageChange, totalItems }: PaginationProps) {
  const { t, dir, formatNumber } = useI18n();
  if (totalPages <= 1 && totalItems === undefined) return null;
  const prevIcon = dir === 'rtl' ? 'chevronRight' : 'chevronLeft';
  const nextIcon = dir === 'rtl' ? 'chevronLeft' : 'chevronRight';
  return (
    <nav className={styles.nav} aria-label={t('common.pagination.label')}>
      {totalItems !== undefined && <span className={styles.total}>{formatNumber(totalItems)}</span>}
      <div className={styles.controls}>
        <IconButton
          label={t('common.pagination.prev')}
          variant="secondary"
          size="sm"
          disabled={page <= 0}
          onClick={() => onPageChange(page - 1)}
        >
          <Icon name={prevIcon} size={18} />
        </IconButton>
        <span className={styles.page} aria-live="polite">
          {t('common.pagination.page', {
            page: formatNumber(page + 1),
            total: formatNumber(Math.max(totalPages, 1)),
          })}
        </span>
        <IconButton
          label={t('common.pagination.next')}
          variant="secondary"
          size="sm"
          disabled={page + 1 >= totalPages}
          onClick={() => onPageChange(page + 1)}
        >
          <Icon name={nextIcon} size={18} />
        </IconButton>
      </div>
    </nav>
  );
}

interface LoadMoreProps {
  hasMore: boolean;
  loading?: boolean;
  onLoadMore: () => void;
}

/** İmeç tabanlı "daha fazla yükle" (`nextCursor` yanıtları için). Sonraki sayfa yoksa hiçbir şey çizmez. */
export function LoadMore({ hasMore, loading, onLoadMore }: LoadMoreProps) {
  const { t } = useI18n();
  if (!hasMore) return null;
  return (
    <div className={styles.more}>
      <Button variant="secondary" loading={loading} onClick={onLoadMore}>
        {t('common.loadMore')}
      </Button>
    </div>
  );
}
