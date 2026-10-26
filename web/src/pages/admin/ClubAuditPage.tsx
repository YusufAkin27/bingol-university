// SAYFA: Kulüp yetki ve denetim kaydı (/admin/communities/audit?communityId=)
// API: GET /api/communities/{id}/audit?cursor=&size= (ADMIN tüm kulüplerin kaydını görür; yetki değişikliği, üye kararı, devir, davet) (api/admission.ts).
import { useInfiniteQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { admissionApi, qk } from '../../api';
import {
  Badge,
  Button,
  EmptyState,
  ErrorState,
  FormField,
  Input,
  LoadMore,
  PageHeader,
  Skeleton,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { paths } from '../../paths';
import { adminErrorMessage } from './campaigns/shared';
import { parseId } from './moderation/modLogic';
import styles from './moderation/moderation.module.css';

export default function ClubAuditPage() {
  const i18n = useI18n();
  const { t, td, formatDateTime } = i18n;
  usePageTitle(t('admin.clubAudit.title'));
  const [params, setParams] = useSearchParams();
  const communityId = parseId(params.get('communityId') ?? '');
  const [input, setInput] = useState(params.get('communityId') ?? '');
  const [invalid, setInvalid] = useState(false);

  const query = useInfiniteQuery({
    queryKey: [...qk.admission.clubAudit(communityId ?? 0), 'pages'],
    queryFn: ({ pageParam }) => admissionApi.listClubAudit(communityId as number, { cursor: pageParam, size: 30 }),
    initialPageParam: null as number | null,
    getNextPageParam: (p) => p.nextCursor ?? undefined,
    enabled: communityId !== null,
    retry: false,
  });
  const items = query.data?.pages.flatMap((p) => p.items) ?? [];
  const who = (name: string | null, id: number | null) => (id === null ? '—' : (name ?? t('admin.clubAudit.userId', { id })));

  return (
    <>
      <PageHeader title={t('admin.clubAudit.title')} />
      <div className={styles.stack}>
        <form
          className={styles.toolbar}
          onSubmit={(e) => {
            e.preventDefault();
            const id = parseId(input);
            setInvalid(id === null);
            if (id !== null) setParams({ communityId: String(id) });
          }}
        >
          <FormField label={t('admin.clubAudit.communityId')} error={invalid ? t('admin.admission.invalidId') : null}>
            <Input className="ltr" inputMode="numeric" value={input} onChange={(e) => setInput(e.target.value)} />
          </FormField>
          <Button type="submit">{t('admin.admission.show')}</Button>
          <Link to={paths.admin.communities}>{t('admin.clubAudit.openCommunities')}</Link>
        </form>

        {communityId === null ? (
          <EmptyState icon="community" title={t('admin.clubAudit.empty.title')} description={t('admin.clubAudit.empty.hint')} />
        ) : query.isError ? (
          <ErrorState description={adminErrorMessage(i18n, query.error)} onRetry={() => void query.refetch()} />
        ) : query.isLoading ? (
          <Skeleton height="6rem" width="100%" />
        ) : items.length === 0 ? (
          <EmptyState icon="list" title={t('admin.clubAudit.none.title')} description={t('admin.clubAudit.none.hint')} />
        ) : (
          <>
            <ul className={styles.rowList} aria-label={t('admin.clubAudit.title')}>
              {items.map((a) => (
                <li key={a.id} className={styles.item}>
                  <div className={styles.itemHead}>
                    <Badge tone="primary">{td(`admin.clubAudit.action.${a.action}`, a.action)}</Badge>
                    <span>{t('admin.clubAudit.by', { name: who(a.actorName, a.actorId) })}</span>
                    {a.targetUserId !== null && (
                      <span>{t('admin.clubAudit.target', { name: who(a.targetName, a.targetUserId) })}</span>
                    )}
                    <span className={styles.spacer} />
                    <span className={styles.muted}>{formatDateTime(a.createdAt)}</span>
                  </div>
                  {a.detail && <code className={`${styles.mono} ltr`}>{a.detail}</code>}
                </li>
              ))}
            </ul>
            <LoadMore
              hasMore={!!query.hasNextPage}
              loading={query.isFetchingNextPage}
              onLoadMore={() => void query.fetchNextPage()}
            />
          </>
        )}
      </div>
    </>
  );
}
