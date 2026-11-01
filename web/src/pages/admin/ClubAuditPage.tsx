// SAYFA: Kulüp yetki ve denetim kaydı (/admin/communities/audit?communityId=)
// API: GET /api/communities/{id}/audit?cursor=&size= (ADMIN tüm kulüplerin kaydını görür; yetki değişikliği, üye kararı, devir, davet) (api/admission.ts),
//      kulüp seçici için GET /api/admin/communities?q= (api/adminCommunities.ts).
import { useInfiniteQuery } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { admissionApi, qk } from '../../api';
import { EMPTY_CLUB_FILTERS, listClubs, type ClubRow } from '../../api/adminCommunities';
import type { ClubAuditRow } from '../../api/types';
import {
  Badge,
  Button,
  EmptyState,
  ErrorState,
  FormField,
  Input,
  Insight,
  LoadMore,
  PageHeader,
  Select,
  Skeleton,
  StatTile,
  type Tone,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { paths } from '../../paths';
import { adminErrorMessage } from './campaigns/shared';
import { EntityPicker, PickedChip } from './community/EntityPicker';
import { SummaryStrip } from './community/Summary';
import { parseId } from './moderation/modLogic';
import styles from './moderation/moderation.module.css';

type Group = 'member' | 'permission' | 'transfer' | 'invite';
const GROUPS: Group[] = ['member', 'permission', 'transfer', 'invite'];

/** Eylem kodu → grup ve rozet tonu (bilinmeyen kod nötr, "diğer" sayılır). */
function groupOf(action: string): Group | null {
  if (action.startsWith('MEMBER_')) return 'member';
  if (action.startsWith('PERMISSIONS_')) return 'permission';
  if (action.startsWith('TRANSFER_')) return 'transfer';
  if (action.startsWith('INVITE_')) return 'invite';
  return null;
}
function toneOf(action: string): Tone {
  if (action === 'MEMBER_APPROVED') return 'success';
  if (action === 'MEMBER_REJECTED' || action === 'MEMBER_REMOVED' || action === 'MEMBER_BANNED') return 'danger';
  if (action.startsWith('TRANSFER_')) return 'warning';
  if (action.startsWith('PERMISSIONS_')) return 'info';
  return 'neutral';
}

export default function ClubAuditPage() {
  const i18n = useI18n();
  const { t, td, formatDateTime, formatDate, formatNumber } = i18n;
  usePageTitle(t('admin.clubAudit.title'));
  const [params, setParams] = useSearchParams();
  const communityId = parseId(params.get('communityId') ?? '');
  const clubName = params.get('name') ?? '';
  const [input, setInput] = useState('');
  const [invalid, setInvalid] = useState(false);
  const [group, setGroup] = useState<Group | ''>('');

  const query = useInfiniteQuery({
    queryKey: [...qk.admission.clubAudit(communityId ?? 0), 'pages'],
    queryFn: ({ pageParam }) => admissionApi.listClubAudit(communityId as number, { cursor: pageParam, size: 30 }),
    initialPageParam: null as number | null,
    getNextPageParam: (p) => p.nextCursor ?? undefined,
    enabled: communityId !== null,
    retry: false,
  });
  const all = useMemo(() => query.data?.pages.flatMap((p) => p.items) ?? [], [query.data]);
  const items = useMemo(() => (group ? all.filter((a) => groupOf(a.action) === group) : all), [all, group]);
  const who = (name: string | null, id: number | null) => (id === null ? '—' : (name ?? t('admin.clubAudit.userId', { id })));

  /** Gün başlığı: Bugün / Dün / tarih. */
  const dayLabel = (iso: string) => {
    const d = new Date(iso);
    const today = new Date();
    const y = new Date();
    y.setDate(today.getDate() - 1);
    if (d.toDateString() === today.toDateString()) return t('admin.v2.audit.today');
    if (d.toDateString() === y.toDateString()) return t('admin.v2.audit.yesterday');
    return formatDate(iso);
  };
  const byDay = useMemo(() => {
    const out: { label: string; rows: ClubAuditRow[] }[] = [];
    for (const a of items) {
      const label = dayLabel(a.createdAt);
      const last = out[out.length - 1];
      if (last && last.label === label) last.rows.push(a);
      else out.push({ label, rows: [a] });
    }
    return out;
    // dayLabel yalnız dil/biçim değişince değişir
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [items, t, formatDate]);

  return (
    <>
      <PageHeader title={t('admin.clubAudit.title')} />
      <div className={styles.stack}>
        {communityId === null ? (
          <>
            <EntityPicker<ClubRow>
              anchor="audit-club"
              label={t('admin.v2.audit.pickLabel')}
              placeholder={t('admin.v2.audit.pickPlaceholder')}
              hint={t('admin.v2.audit.pickHint')}
              noResult={t('admin.v2.audit.pickNone')}
              queryKey="clubs"
              search={async (q) => (await listClubs({ ...EMPTY_CLUB_FILTERS, status: 'ALL', q }, 0, 8)).items}
              itemKey={(c) => c.id}
              render={(c) => ({
                title: c.name,
                meta: t('admin.v2.audit.pickMeta', {
                  n: formatNumber(c.memberCount),
                  owner: c.ownerName ?? c.ownerEmail ?? '—',
                }),
              })}
              onPick={(c) => setParams({ communityId: String(c.id), name: c.name })}
              footer={
                <details className={styles.muted}>
                  <summary>{t('admin.v2.audit.byId')}</summary>
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
                  </form>
                </details>
              }
            />
            <Link to={paths.admin.communities}>{t('admin.clubAudit.openCommunities')}</Link>
            <EmptyState icon="community" title={t('admin.clubAudit.empty.title')} description={t('admin.clubAudit.empty.hint')} />
          </>
        ) : (
          <>
            <PickedChip
              title={clubName || t('admin.v2.audit.clubNo', { id: communityId })}
              meta={t('admin.v2.audit.chipMeta')}
              onChange={() => setParams({})}
            />
            {query.isError ? (
              <ErrorState description={adminErrorMessage(i18n, query.error)} onRetry={() => void query.refetch()} />
            ) : query.isLoading ? (
              <Skeleton height="6rem" width="100%" />
            ) : all.length === 0 ? (
              <EmptyState icon="list" title={t('admin.clubAudit.none.title')} description={t('admin.clubAudit.none.hint')} />
            ) : (
              <>
                <SummaryStrip
                  insight={
                    <Insight
                      parts={t('admin.v2.audit.insight', {
                        n: formatNumber(all.length),
                        last: formatDateTime(all[0].createdAt),
                      })}
                    />
                  }
                >
                  {GROUPS.map((g) => (
                    <StatTile
                      key={g}
                      label={t(`admin.v2.audit.group.${g}`)}
                      value={all.filter((a) => groupOf(a.action) === g).length}
                    />
                  ))}
                </SummaryStrip>
                <div data-search-anchor="audit-filter">
                  <FormField label={t('admin.v2.audit.filter')}>
                    <Select value={group} onChange={(e) => setGroup(e.target.value as Group | '')}>
                      <option value="">{t('admin.v2.audit.filterAll')}</option>
                      {GROUPS.map((g) => (
                        <option key={g} value={g}>
                          {t(`admin.v2.audit.group.${g}`)}
                        </option>
                      ))}
                    </Select>
                  </FormField>
                </div>
                {items.length === 0 ? (
                  <EmptyState compact icon="list" title={t('admin.v2.audit.filterNone')} />
                ) : (
                  byDay.map((d) => (
                    <section key={d.label} aria-label={d.label}>
                      <h2 className={styles.muted}>{d.label}</h2>
                      <ul className={styles.rowList} aria-label={t('admin.clubAudit.title')}>
                        {d.rows.map((a) => (
                          <li key={a.id} className={styles.item}>
                            <div className={styles.itemHead}>
                              <Badge tone={toneOf(a.action)}>{td(`admin.clubAudit.action.${a.action}`, a.action)}</Badge>
                              <span>{t('admin.clubAudit.by', { name: who(a.actorName, a.actorId) })}</span>
                              {a.targetUserId !== null && (
                                <span>{t('admin.clubAudit.target', { name: who(a.targetName, a.targetUserId) })}</span>
                              )}
                              <span className={styles.spacer} />
                              <span className={styles.muted}>{formatDateTime(a.createdAt)}</span>
                            </div>
                            {a.detail && (
                              <details>
                                <summary className={styles.muted}>{t('admin.v2.audit.detail')}</summary>
                                <code className={`${styles.mono} ltr`}>{a.detail}</code>
                              </details>
                            )}
                          </li>
                        ))}
                      </ul>
                    </section>
                  ))
                )}
                <div data-search-anchor="audit-more">
                  <LoadMore
                    hasMore={!!query.hasNextPage}
                    loading={query.isFetchingNextPage}
                    onLoadMore={() => void query.fetchNextPage()}
                  />
                </div>
              </>
            )}
          </>
        )}
      </div>
    </>
  );
}
