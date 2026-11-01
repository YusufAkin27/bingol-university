import type { KeyboardEvent, ReactNode } from 'react';
import { useI18n } from '../../i18n/I18nProvider';
import { EmptyState, ErrorState, Skeleton } from './Feedback';
import { Icon } from './Icon';
import { Table, type Column, type TableProps } from './Table';
import { useIsNarrow } from './useIsNarrow';
import styles from './ResponsiveTable.module.css';

export interface ResponsiveTableProps<T> extends TableProps<T> {
  /** auto (varsayılan): dar ekranda kart, geniş ekranda tablo. always/never: zorla. */
  cards?: 'auto' | 'always' | 'never';
  /** Kartlara geçiş genişliği (px, varsayılan 640). */
  breakpoint?: number;
  /** Kartlarda "Diğer bilgiler" açık başlasın. */
  expandDetails?: boolean;
}

function labelOf<T>(c: Column<T>): string {
  if (c.card?.label) return c.card.label;
  if (c.headerLabel) return c.headerLabel;
  return typeof c.header === 'string' ? c.header : c.key;
}

function cellOf<T>(c: Column<T>, row: T): ReactNode {
  return c.render ? c.render(row) : String((row as Record<string, unknown>)[c.key] ?? '');
}

interface Layout<T> {
  title?: Column<T>;
  meta: Column<T>[];
  details: Column<T>[];
  actions: Column<T>[];
}

/** Sütun ipuçlarından kart düzeni: 1 başlık, 2-3 öncelikli alan, kalanı "Diğer bilgiler", eylemler altta. */
function layoutOf<T>(columns: Column<T>[]): Layout<T> {
  const shown = columns.filter((c) => !c.card?.hide);
  const actions = shown.filter((c) => c.card?.actions);
  const rest = shown.filter((c) => !c.card?.actions);
  const hasPriority = rest.some((c) => c.card?.priority);
  const ranked = hasPriority
    ? rest.filter((c) => c.card?.priority).sort((a, b) => (a.card?.priority ?? 9) - (b.card?.priority ?? 9))
    : rest.slice(0, 3);
  const [title, ...meta] = ranked;
  const details = rest.filter((c) => !ranked.includes(c));
  return { title, meta, details, actions };
}

/**
 * Tablo; dar ekranda (varsayılan <640 px) satırları kart yığınına çevirir. Table ile aynı props'u alır
 * (sıralama, seçim, satır tıklama, yükleniyor/boş/hata). Sütunlara `card` ipucu verilmezse ilk 3 sütun kartın üstünde olur.
 * Mevcut `Table` kullanan sayfalar etkilenmez: yalnız bu bileşene geçen sayfa kart görünümü kazanır.
 */
export function ResponsiveTable<T>({
  cards = 'auto',
  breakpoint = 640,
  expandDetails,
  ...table
}: ResponsiveTableProps<T>) {
  const narrow = useIsNarrow(breakpoint);
  const asCards = cards === 'always' || (cards === 'auto' && narrow);
  if (!asCards) return <Table {...table} />;
  return <DataCards {...table} expandDetails={expandDetails} />;
}

/** Kart yığını görünümü (ResponsiveTable dar ekranda bunu çizer; doğrudan da kullanılabilir). */
export function DataCards<T>({
  columns,
  rows,
  rowKey,
  loading,
  skeletonRows = 3,
  empty,
  sort,
  onSortChange,
  onRowClick,
  caption,
  error,
  onRetry,
  selectedKeys,
  onSelectionChange,
  expandDetails,
}: TableProps<T> & { expandDetails?: boolean }) {
  const { t } = useI18n();
  const selectable = !!selectedKeys && !!onSelectionChange;
  const layout = layoutOf(columns);
  const sortable = columns.filter((c) => c.sortable);

  function toggleRow(k: string | number) {
    if (!selectedKeys || !onSelectionChange) return;
    const next = new Set(selectedKeys);
    if (next.has(k)) next.delete(k);
    else next.add(k);
    onSelectionChange(next);
  }
  function onKey(e: KeyboardEvent<HTMLElement>, row: T) {
    if (e.target !== e.currentTarget) return;
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      onRowClick?.(row);
    }
  }

  if (error && !loading) return <ErrorState compact onRetry={onRetry} />;

  return (
    <div className={styles.wrap}>
      {sortable.length > 0 && onSortChange && (
        <div className={styles.sortBar}>
          <label className={styles.sortLabel}>
            <span>{t('admin.kit.cards.sortBy')}</span>
            <select
              className={styles.sortSelect}
              value={sort?.key ?? ''}
              onChange={(e) => e.target.value && onSortChange({ key: e.target.value, dir: sort?.dir ?? 'asc' })}
            >
              {!sort && <option value="">{t('admin.kit.cards.noSort')}</option>}
              {sortable.map((c) => (
                <option key={c.key} value={c.key}>
                  {labelOf(c)}
                </option>
              ))}
            </select>
          </label>
          <button
            type="button"
            className={styles.sortDir}
            disabled={!sort}
            title={t(sort?.dir === 'desc' ? 'admin.kit.cards.direction.desc' : 'admin.kit.cards.direction.asc')}
            aria-label={t(sort?.dir === 'desc' ? 'admin.kit.cards.direction.desc' : 'admin.kit.cards.direction.asc')}
            onClick={() => sort && onSortChange({ key: sort.key, dir: sort.dir === 'asc' ? 'desc' : 'asc' })}
          >
            <Icon name={sort?.dir === 'desc' ? 'arrowDown' : 'arrowUp'} size={18} />
          </button>
        </div>
      )}
      <ul className={styles.list} aria-label={caption ?? t('admin.kit.cards.list')} aria-busy={loading || undefined}>
        {loading &&
          Array.from({ length: skeletonRows }, (_, i) => (
            <li key={`sk-${i}`} className={styles.card} aria-hidden="true">
              <Skeleton width="55%" height="1.1rem" />
              <Skeleton width="80%" height="0.9rem" />
              <Skeleton width="40%" height="0.9rem" />
            </li>
          ))}
        {!loading &&
          rows?.map((row) => {
            const k = rowKey(row);
            const picked = !!selectedKeys?.has(k);
            const clickable = !!onRowClick;
            return (
              <li
                key={k}
                className={`${styles.card} ${clickable ? styles.clickable : ''}`}
                data-selected={picked || undefined}
                tabIndex={clickable ? 0 : undefined}
                onClick={clickable ? () => onRowClick?.(row) : undefined}
                onKeyDown={clickable ? (e) => onKey(e, row) : undefined}
              >
                <div className={styles.top}>
                  {selectable && (
                    <label className={styles.pick} onClick={(e) => e.stopPropagation()}>
                      <input
                        type="checkbox"
                        checked={picked}
                        aria-label={t('admin.table.selectRow')}
                        onChange={() => toggleRow(k)}
                      />
                    </label>
                  )}
                  <div className={styles.titleBox}>
                    {layout.title && <div className={styles.title}>{cellOf(layout.title, row)}</div>}
                  </div>
                </div>
                {layout.meta.length > 0 && (
                  <dl className={styles.meta}>
                    {layout.meta.map((c) => (
                      <div key={c.key} className={styles.pair}>
                        <dt>{labelOf(c)}</dt>
                        <dd>{cellOf(c, row)}</dd>
                      </div>
                    ))}
                  </dl>
                )}
                {layout.details.length > 0 && (
                  <details className={styles.details} open={expandDetails || undefined} onClick={(e) => e.stopPropagation()}>
                    <summary>{t('admin.kit.cards.details', { count: String(layout.details.length) })}</summary>
                    <dl className={styles.meta}>
                      {layout.details.map((c) => (
                        <div key={c.key} className={styles.pair}>
                          <dt>{labelOf(c)}</dt>
                          <dd>{cellOf(c, row)}</dd>
                        </div>
                      ))}
                    </dl>
                  </details>
                )}
                {layout.actions.length > 0 && (
                  <div className={styles.actions} onClick={(e) => e.stopPropagation()}>
                    {layout.actions.map((c) => (
                      <div key={c.key} className={styles.actionCell}>
                        {cellOf(c, row)}
                      </div>
                    ))}
                  </div>
                )}
              </li>
            );
          })}
      </ul>
      {!loading &&
        rows &&
        rows.length === 0 &&
        (empty ?? (
          <EmptyState icon="search" title={t('common.noResults')} description={t('common.state.emptyHint')} compact />
        ))}
    </div>
  );
}
