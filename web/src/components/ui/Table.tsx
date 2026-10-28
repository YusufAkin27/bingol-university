import { useEffect, useRef, type KeyboardEvent, type ReactNode } from 'react';
import { useI18n } from '../../i18n/I18nProvider';
import { Icon } from './Icon';
import { EmptyState, ErrorState, Skeleton } from './Feedback';
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
  /** Yükleme hatası: tablo yerine hata durumu ve (onRetry varsa) "Tekrar dene" gösterilir. */
  error?: boolean;
  onRetry?: () => void;
  /** Satır seçimi (toplu işlemler): ikisi birlikte verilirse ilk sütun onay kutusu olur. */
  selectedKeys?: ReadonlySet<string | number>;
  onSelectionChange?: (next: Set<string | number>) => void;
  /** Daha geniş satır aralığı (varsayılan: yoğun). */
  comfortable?: boolean;
}

/** Başlıktaki "tümünü seç" kutusu: kısmi seçimde karışık (indeterminate) durumdadır. */
function SelectAll({
  checked,
  partial,
  label,
  onChange,
}: {
  checked: boolean;
  partial: boolean;
  label: string;
  onChange: () => void;
}) {
  const ref = useRef<HTMLInputElement>(null);
  useEffect(() => {
    if (ref.current) ref.current.indeterminate = partial;
  }, [partial]);
  return (
    <input
      ref={ref}
      type="checkbox"
      className={styles.check}
      aria-label={label}
      checked={checked}
      onChange={onChange}
    />
  );
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
  error,
  onRetry,
  selectedKeys,
  onSelectionChange,
  comfortable,
}: TableProps<T>) {
  const { t } = useI18n();
  const selectable = !!selectedKeys && !!onSelectionChange;
  const keys = rows?.map(rowKey) ?? [];
  const selectedCount = keys.filter((k) => selectedKeys?.has(k)).length;

  function toggleAll() {
    if (!selectedKeys || !onSelectionChange) return;
    const next = new Set(selectedKeys);
    if (selectedCount === keys.length) keys.forEach((k) => next.delete(k));
    else keys.forEach((k) => next.add(k));
    onSelectionChange(next);
  }
  function toggleRow(k: string | number) {
    if (!selectedKeys || !onSelectionChange) return;
    const next = new Set(selectedKeys);
    if (next.has(k)) next.delete(k);
    else next.add(k);
    onSelectionChange(next);
  }

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

  if (error && !loading) {
    return (
      <div className={styles.wrap}>
        <ErrorState compact onRetry={onRetry} />
      </div>
    );
  }

  const isEmpty = !loading && rows && rows.length === 0;

  return (
    <div className={`${styles.wrap} ${comfortable ? styles.comfortable : ''}`}>
      <div className={styles.scroll} tabIndex={0} role={caption ? 'region' : undefined} aria-label={caption}>
        <table className={styles.table}>
          {caption && <caption className="sr-only">{caption}</caption>}
          <thead>
            <tr>
              {selectable && (
                <th scope="col" className={styles.selectCell}>
                  <SelectAll
                    checked={keys.length > 0 && selectedCount === keys.length}
                    partial={selectedCount > 0 && selectedCount < keys.length}
                    label={t('admin.table.selectAll')}
                    onChange={toggleAll}
                  />
                </th>
              )}
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
                  {selectable && <td className={styles.selectCell} />}
                  {columns.map((c) => (
                    <td key={c.key}>
                      <Skeleton width={`${50 + ((i * 17 + c.key.length * 11) % 45)}%`} />
                    </td>
                  ))}
                </tr>
              ))}
            {!loading &&
              rows?.map((row) => {
                const k = rowKey(row);
                const picked = !!selectedKeys?.has(k);
                return (
                  <tr
                    key={k}
                    data-selected={picked || undefined}
                    className={onRowClick ? styles.clickable : undefined}
                    onClick={onRowClick ? () => onRowClick(row) : undefined}
                    onKeyDown={onRowClick ? (e) => onKey(e, row) : undefined}
                    tabIndex={onRowClick ? 0 : undefined}
                  >
                    {selectable && (
                      <td className={styles.selectCell} onClick={(e) => e.stopPropagation()}>
                        <input
                          type="checkbox"
                          className={styles.check}
                          aria-label={t('admin.table.selectRow')}
                          checked={picked}
                          onChange={() => toggleRow(k)}
                        />
                      </td>
                    )}
                    {columns.map((c) => (
                      <td key={c.key} className={styles[c.align ?? 'start']}>
                        {c.render ? c.render(row) : String((row as Record<string, unknown>)[c.key] ?? '')}
                      </td>
                    ))}
                  </tr>
                );
              })}
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
