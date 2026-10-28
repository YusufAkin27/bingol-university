// Kulüp gönderisi + duyurusu birleşik moderasyon listesi. Hem /admin/content-review sayfasında (tüm kulüpler) hem de
// kulüp çekmecesinin Gönderiler / Duyurular sekmelerinde (`communityId` + `kind` sabit) kullanılır.
import { useQuery } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import {
  EMPTY_CONTENT_FILTERS,
  listContent,
  type ContentFilters,
  type ContentKind,
  type ContentState,
} from '../../../api/adminCommunities';
import {
  EmptyState,
  ErrorState,
  FormField,
  Input,
  Pagination,
  Select,
  Skeleton,
  Button,
} from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { useDebouncedValue } from '../../../lib/hooks';
import { adminError } from '../../../lib/errors';
import { ContentRowItem, useContentActions } from './ContentParts';
import styles from './clubs.module.css';

interface Props {
  /** Verilirse yalnız bu kulübün içeriği listelenir. */
  communityId?: number;
  /** Verilirse tür süzgeci sabittir (Gönderiler / Duyurular sekmeleri). */
  kind?: ContentKind;
  onOpenClub?: (communityId: number) => void;
}

const STATES: (ContentState | 'ALL')[] = ['ALL', 'VISIBLE', 'HIDDEN', 'DELETED'];
const KINDS: (ContentKind | 'ALL')[] = ['ALL', 'POST', 'ANNOUNCEMENT'];

export function ContentList({ communityId, kind, onOpenClub }: Props) {
  const i18n = useI18n();
  const { t } = i18n;
  const [filters, setFilters] = useState<ContentFilters>({ ...EMPTY_CONTENT_FILTERS, kind: kind ?? 'ALL', communityId });
  const [page, setPage] = useState(0);
  const set = (p: Partial<ContentFilters>) => {
    setFilters((f) => ({ ...f, ...p }));
    setPage(0);
  };
  const q = useDebouncedValue(filters.q, 400);
  const f = useMemo(() => ({ ...filters, q, communityId, kind: kind ?? filters.kind }), [filters, q, communityId, kind]);
  const actions = useContentActions();

  const list = useQuery({
    queryKey: ['communities', 'admin', 'content-list', f, page],
    queryFn: () => listContent(f, page, 20),
    staleTime: 10_000,
  });
  const data = list.data;

  return (
    <div>
      <div className={styles.filters} role="search" aria-label={t('admin.p06.content.filters')}>
        <FormField label={t('admin.p06.content.filter.status')}>
          <Select value={filters.status} onChange={(e) => set({ status: e.target.value as ContentState | 'ALL' })}>
            {STATES.map((s) => (
              <option key={s} value={s}>
                {t(`admin.p06.content.statusFilter.${s}`)}
              </option>
            ))}
          </Select>
        </FormField>
        {!kind && (
          <FormField label={t('admin.p06.content.filter.kind')}>
            <Select value={filters.kind} onChange={(e) => set({ kind: e.target.value as ContentKind | 'ALL' })}>
              {KINDS.map((k) => (
                <option key={k} value={k}>
                  {t(`admin.p06.content.kindFilter.${k}`)}
                </option>
              ))}
            </Select>
          </FormField>
        )}
        <FormField label={t('admin.p06.content.filter.q')}>
          <Input
            type="search"
            value={filters.q}
            placeholder={t('admin.p06.content.filter.qPlaceholder')}
            onChange={(e) => set({ q: e.target.value })}
          />
        </FormField>
        <FormField label={t('admin.p06.content.filter.minReports')}>
          <Input
            type="text"
            inputMode="numeric"
            value={filters.minReports}
            onChange={(e) => set({ minReports: e.target.value.replace(/\D/g, '') })}
          />
        </FormField>
        <FormField label={t('admin.p06.content.filter.from')}>
          <Input type="date" value={filters.from} onChange={(e) => set({ from: e.target.value })} />
        </FormField>
        <FormField label={t('admin.p06.content.filter.to')}>
          <Input type="date" value={filters.to} onChange={(e) => set({ to: e.target.value })} />
        </FormField>
        <FormField label={t('admin.p06.content.filter.sort')}>
          <Select value={filters.sort} onChange={(e) => set({ sort: e.target.value as ContentFilters['sort'] })}>
            <option value="createdAt">{t('admin.p06.content.sort.createdAt')}</option>
            <option value="reports">{t('admin.p06.content.sort.reports')}</option>
          </Select>
        </FormField>
        <Button variant="ghost" size="sm" onClick={() => { setFilters({ ...EMPTY_CONTENT_FILTERS, kind: kind ?? 'ALL', communityId }); setPage(0); }}>
          {t('admin.p06.filter.reset')}
        </Button>
      </div>

      {list.isError ? (
        <ErrorState description={adminError(i18n, list.error)} onRetry={() => void list.refetch()} />
      ) : list.isPending ? (
        <Skeleton height="12rem" width="100%" />
      ) : data && data.items.length === 0 ? (
        <EmptyState icon="list" title={t('admin.p06.content.empty')} description={t('admin.p06.content.emptyHint')} />
      ) : (
        data && (
          <>
            <p className={styles.meta} aria-live="polite">
              {t('admin.p06.content.count', { n: data.total })}
            </p>
            <ul className={styles.list} data-testid="content-list">
              {data.items.map((r) => (
                <ContentRowItem key={r.id} row={r} actions={actions} showClub={!communityId} onOpenClub={onOpenClub} />
              ))}
            </ul>
            {data.totalPages > 1 && (
              <div className={styles.pager}>
                <Pagination page={data.page} totalPages={data.totalPages} totalItems={data.total} onPageChange={setPage} />
              </div>
            )}
          </>
        )
      )}
      {actions.dialogs}
    </div>
  );
}
