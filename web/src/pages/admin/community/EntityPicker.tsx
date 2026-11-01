// Kimlik numarası yerine ad ile seçici: yazınca sonuç listesi gelir, birine basınca seçilir.
// Kulüp denetimi, etkinlik başvuruları vb. "bir kayıt seç" adımları için; arama isteği ancak 2+ harf yazılınca gider.
import { useQuery } from '@tanstack/react-query';
import { useId, useState, type ReactNode } from 'react';
import { EmptyState, ErrorState, Input, Skeleton } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { useDebouncedValue } from '../../../lib/hooks';
import styles from './picker.module.css';

export interface PickerProps<T> {
  /** Alan etiketi: "Kulüp ara". */
  label: string;
  placeholder: string;
  /** Sorgu anahtarı öneki (aynı seçici birden çok yerde karışmasın). */
  queryKey: string;
  search: (q: string) => Promise<T[]>;
  itemKey: (item: T) => string | number;
  /** Sonuç satırı: ad + ikinci satır. */
  render: (item: T) => { title: ReactNode; meta?: ReactNode };
  onPick: (item: T) => void;
  /** Bulunamadı cümlesi (ne yapılacağını söylesin). */
  noResult: string;
  /** Henüz yazılmadıysa gösterilen ipucu. */
  hint: string;
  /** Kimlik kutusu gibi ek içerik. */
  footer?: ReactNode;
  anchor?: string;
}

export function EntityPicker<T>({
  label,
  placeholder,
  queryKey,
  search,
  itemKey,
  render,
  onPick,
  noResult,
  hint,
  footer,
  anchor,
}: PickerProps<T>) {
  const { t } = useI18n();
  const [text, setText] = useState('');
  const q = useDebouncedValue(text.trim(), 350);
  const listId = useId();
  const enabled = q.length >= 2;
  const res = useQuery({
    queryKey: ['picker', queryKey, q],
    queryFn: () => search(q),
    enabled,
    staleTime: 15_000,
  });

  return (
    <div className={styles.picker} data-search-anchor={anchor}>
      <label className={styles.label} htmlFor={`${listId}-in`}>
        {label}
      </label>
      <Input
        id={`${listId}-in`}
        type="search"
        autoComplete="off"
        value={text}
        placeholder={placeholder}
        aria-controls={listId}
        onChange={(e) => setText(e.target.value)}
      />
      <div id={listId} className={styles.results} aria-live="polite">
        {!enabled ? (
          <p className={styles.hint}>{hint}</p>
        ) : res.isError ? (
          <ErrorState compact onRetry={() => void res.refetch()} />
        ) : res.isLoading ? (
          <Skeleton height="3rem" width="100%" />
        ) : (res.data ?? []).length === 0 ? (
          <EmptyState compact icon="search" title={noResult} />
        ) : (
          <ul className={styles.list}>
            {(res.data ?? []).map((item) => {
              const r = render(item);
              return (
                <li key={itemKey(item)}>
                  <button type="button" className={styles.option} onClick={() => onPick(item)}>
                    <span className={styles.optTitle}>{r.title}</span>
                    {r.meta && <span className={styles.optMeta}>{r.meta}</span>}
                    <span className={styles.optGo} aria-hidden="true">
                      {t('admin.v2.picker.choose')}
                    </span>
                  </button>
                </li>
              );
            })}
          </ul>
        )}
      </div>
      {footer}
    </div>
  );
}

/** Seçilmiş kaydın çipi: ad + "Değiştir" düğmesi. */
export function PickedChip({ title, meta, onChange }: { title: ReactNode; meta?: ReactNode; onChange: () => void }) {
  const { t } = useI18n();
  return (
    <div className={styles.chip}>
      <div className={styles.chipText}>
        <strong>{title}</strong>
        {meta && <span className={styles.optMeta}>{meta}</span>}
      </div>
      <button type="button" className={styles.change} onClick={onChange}>
        {t('admin.v2.picker.change')}
      </button>
    </div>
  );
}
