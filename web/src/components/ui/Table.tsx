import type { KeyboardEvent, ReactNode } from 'react';
import { useI18n } from '../../i18n/I18nProvider';
import { Icon } from './Icon';
import { Skeleton } from './Feedback';
import { EmptyState } from './Feedback';
import styles from './Table.module.css';

export interface Column<T> {
  key: string;
  header: ReactNode;
  /** Hücre içeriği. Verilmezse row[key] yazılır. */
  render?: (row: T) => ReactNode;
  sortable?: boolean;
  align?: 'start' | 'end' | 'center';
  width?: string;
  /** Erişilebilir sıralama düğmesi adı için düz metin başlık. */
  headerLabel?: string;
}

export interface SortState {
  key: string;
  dir: 'asc' | 'desc';
}

interface TableProps<T> {
  columns: Column<T>[];
  rows: T[] | undefined;
  rowKey: (row: T) => string | number;
  loading?: boolean;
  /** Yükleme iskeletindeki satır sayısı */
  skeletonRows?: number;
  empty?: ReactNode;
  sort?: SortState | null;
  onSortChange?: (next: SortState) => void;
  onRowClick?: (row: T) => void;
  caption?: string;
}

export function Table<T>({
  columns,
  rows,
  rowKey,
  loading,
  skeletonRows = 6,
  empty,
  sort,
  onSortChange,
  onRowClick,
  caption,
}: TableProps<T>) {
  const { t } = useI18n();

  function toggle(col: Column<T>) {
    if (!onSortChange) return;
    const dir = sort?.key === col.key && sort.dir === 'asc' ? 'desc' : 'asc';
    onSortChange({ key: col.key, dir });
  }

  function onKey(e: KeyboardEvent<HTMLTableRowElement>, row: T) {
    if (e.target !== e.currentTarget) return;
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      onRowClick?.(row);
    }
  }

  const isEmpty = !loading && rows && rows.length === 0;

  return (
    <div className={styles.wrap}>
      <div className={styles.scroll} tabIndex={0} role={caption ? 'region' : undefined} aria-label={caption}>
        <table className={styles.table}>
          {caption && <caption className="sr-only">{caption}</caption>}
          <thead>
            <tr>
              {columns.map((c) => {
                const active = sort?.key === c.key;
                return (
                  <th
                    key={c.key}
                    scope="col"
                    style={{ width: c.width }}
                    className={styles[c.align ?? 'start']}
                    aria-sort={
                      c.sortable
                        ? active
                          ? sort.dir === 'asc'
                            ? 'ascending'
                            : 'descending'
                          : 'none'
                        : undefined
                    }
                  >
                    {c.sortable ? (
                      <button
                        type="button"
                        className={styles.sortBtn}
                        onClick={() => toggle(c)}
                        title={t('common.table.sortBy', {
                          column: c.headerLabel ?? (typeof c.header === 'string' ? c.header : c.key),
                        })}
                      >
                        {c.header}
                        <span
                          className={`${styles.sortIcon} ${active ? styles.sortActive : ''}`}
                          aria-hidden="true"
                        >
                          <Icon name={active && sort.dir === 'desc' ? 'arrowDown' : 'arrowUp'} size={14} />
                        </span>
                      </button>
                    ) : (
                      c.header
                    )}
                  </th>
                );
              })}
            </tr>
          </thead>
          <tbody>
            {loading &&
              Array.from({ length: skeletonRows }, (_, i) => (
                <tr key={`sk-${i}`} aria-hidden="true">
                  {columns.map((c) => (
                    <td key={c.key}>
                      <Skeleton width={`${50 + ((i * 17 + c.key.length * 11) % 45)}%`} />
                    </td>
                  ))}
                </tr>
              ))}
            {!loading &&
              rows?.map((row) => (
                <tr
                  key={rowKey(row)}
                  className={onRowClick ? styles.clickable : undefined}
                  onClick={onRowClick ? () => onRowClick(row) : undefined}
                  onKeyDown={onRowClick ? (e) => onKey(e, row) : undefined}
                  tabIndex={onRowClick ? 0 : undefined}
                >
                  {columns.map((c) => (
                    <td key={c.key} className={styles[c.align ?? 'start']}>
                      {c.render ? c.render(row) : String((row as Record<string, unknown>)[c.key] ?? '')}
                    </td>
                  ))}
                </tr>
              ))}
          </tbody>
        </table>
      </div>
      {isEmpty &&
        (empty ?? (
          <EmptyState
            icon="search"
            title={t('common.noResults')}
            description={t('common.state.emptyHint')}
            compact
          />
        ))}
    </div>
  );
}
