// SAYFA: Forum şikâyet kuyruğu (/admin/forum/reports)
// API: GET /api/admin/forum/reports?status=&type=&reason=&cursor= (FORUM_TOPIC | FORUM_COMMENT), eylemler gerekçeyle:
//      POST .../topics/{id}/moderate | .../comments/{id}/moderate {action, reason}, POST .../reports/{id}/resolve (yoksay) (api/adminForum.ts).
// Okuma `forum.read`, eylem `forum.moderate`. Anonim içeriğin yazarı "Anonim" görünür; kimliği hiçbir yerde açılmaz.
import { useInfiniteQuery } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import {
  FORUM_REPORT_REASONS,
  forumKeys,
  listReports,
  type ForumReportFilters,
  type ForumReportRow,
} from '../../../api/adminForum';
import {
  Badge,
  Button,
  EmptyState,
  ErrorState,
  FormField,
  LoadMore,
  PageHeader,
  Select,
  Skeleton,
} from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { usePageTitle } from '../../../lib/hooks';
import styles from '../moderation/moderation.module.css';
import fs from './forum.module.css';
import { authorLabel, ContentBadges, excerpt, useForumCan, useForumModeration, type ModAction } from './shared';
import { forumError, tf } from './tf';

const DEFAULTS: ForumReportFilters = { status: 'OPEN', type: '', reason: '' };

/** Şikâyet satırı için eylemler: içerik (kaldır/geri al), konuysa sabit/kilit, açıksa yoksay. */
export function reportActions(r: Pick<ForumReportRow, 'targetType' | 'status' | 'preview'>): ModAction[] {
  const out: ModAction[] = [];
  const cs = r.preview.contentStatus;
  // sahibi silmiş / kaydı olmayan içerikte kaldır-geri al yoktur; yalnız şikâyet yoksayılabilir
  if (cs === 'ACTIVE' || cs === 'REMOVED') out.push(cs === 'REMOVED' ? 'RESTORE' : 'REMOVE');
  if (r.targetType === 'FORUM_TOPIC' && cs === 'ACTIVE') {
    out.push(r.preview.pinned ? 'UNPIN' : 'PIN', r.preview.locked ? 'UNLOCK' : 'LOCK');
  }
  if (r.status === 'OPEN') out.push('DISMISS');
  return out;
}

export default function ForumReportsPage() {
  const i18n = useI18n();
  const { formatNumber, formatDateTime } = i18n;
  const f = tf(i18n);
  usePageTitle(f('admin.forum.reports.title'));
  const canModerate = useForumCan('forum.moderate');
  const mod = useForumModeration();
  const [filters, setFilters] = useState<ForumReportFilters>(DEFAULTS);
  const set = (p: Partial<ForumReportFilters>) => setFilters((s) => ({ ...s, ...p }));

  const list = useInfiniteQuery({
    queryKey: forumKeys.reports(filters),
    queryFn: ({ pageParam }) => listReports(filters, pageParam),
    initialPageParam: undefined as string | number | undefined,
    getNextPageParam: (last) => last.nextCursor ?? undefined,
  });
  const rows = useMemo(() => list.data?.pages.flatMap((p) => p.items) ?? [], [list.data]);
  const dirty = filters.status !== DEFAULTS.status || filters.type !== '' || filters.reason !== '';

  return (
    <>
      <PageHeader title={f('admin.forum.reports.title')} description={f('admin.forum.reports.intro')} />
      <div className={styles.stack}>
        {!canModerate && (
          <p className={styles.muted} role="status">
            {f('admin.forum.readOnly')}
          </p>
        )}
        <div className={fs.filters} role="search" aria-label={f('admin.forum.filters')} data-search-anchor="freport-filters">
          <FormField label={f('admin.forum.reports.filter.status')}>
            <Select value={filters.status} onChange={(e) => set({ status: e.target.value as ForumReportFilters['status'] })}>
              <option value="OPEN">{f('admin.forum.reports.status.OPEN')}</option>
              <option value="RESOLVED">{f('admin.forum.reports.status.RESOLVED')}</option>
              <option value="">{f('admin.forum.status.all')}</option>
            </Select>
          </FormField>
          <FormField label={f('admin.forum.reports.filter.type')}>
            <Select value={filters.type} onChange={(e) => set({ type: e.target.value as ForumReportFilters['type'] })}>
              <option value="">{f('admin.forum.status.all')}</option>
              <option value="FORUM_TOPIC">{f('admin.forum.type.FORUM_TOPIC')}</option>
              <option value="FORUM_COMMENT">{f('admin.forum.type.FORUM_COMMENT')}</option>
            </Select>
          </FormField>
          <FormField label={f('admin.forum.reports.filter.reason')}>
            <Select value={filters.reason} onChange={(e) => set({ reason: e.target.value as ForumReportFilters['reason'] })}>
              <option value="">{f('admin.forum.status.all')}</option>
              {FORUM_REPORT_REASONS.map((r) => (
                <option key={r} value={r}>
                  {f(`admin.forum.reason.${r}`)}
                </option>
              ))}
            </Select>
          </FormField>
          {dirty && (
            <Button variant="ghost" size="sm" onClick={() => setFilters(DEFAULTS)}>
              {f('admin.forum.clear')}
            </Button>
          )}
        </div>

        {list.isError ? (
          <ErrorState description={forumError(i18n, list.error)} onRetry={() => void list.refetch()} />
        ) : list.isLoading ? (
          <Skeleton height="10rem" width="100%" />
        ) : rows.length === 0 ? (
          <EmptyState
            icon="flag"
            title={f(dirty ? 'admin.forum.reports.empty.filtered' : 'admin.forum.reports.empty.title')}
            description={f('admin.forum.reports.empty.hint')}
          />
        ) : (
          <>
            <ul className={styles.rowList} aria-label={f('admin.forum.reports.list')} data-search-anchor="freport-list">
              {rows.map((r) => (
                <li key={r.id} className={styles.item} data-testid="forum-report-row">
                  <div className={styles.itemHead}>
                    <Badge tone="info">{f(`admin.forum.type.${r.targetType}`)}</Badge>
                    <Badge tone={r.status === 'OPEN' ? 'warning' : 'success'}>{f(`admin.forum.reports.status.${r.status}`)}</Badge>
                    <ContentBadges
                      removed={r.preview.contentStatus === 'REMOVED'}
                      gone={r.preview.contentStatus === 'DELETED' || r.preview.contentStatus === 'MISSING' ? r.preview.contentStatus : null}
                      pinned={r.preview.pinned}
                      locked={r.preview.locked}
                      anonymous={r.preview.anonymous}
                    />
                    <span className={styles.spacer} />
                    <Badge tone={r.reportCount > 1 ? 'danger' : 'neutral'}>
                      {f('admin.forum.reports.count', { n: formatNumber(r.reportCount) })}
                    </Badge>
                  </div>
                  {r.preview.title && (
                    <h2 className={fs.title} dir="auto">
                      {r.preview.title}
                    </h2>
                  )}
                  <p className={fs.snippet} dir="auto">
                    {excerpt(r.preview.body) || f('admin.forum.reports.noPreview')}
                  </p>
                  <p className={fs.meta}>
                    <span dir="auto">{authorLabel(r.preview.authorName, r.preview.anonymous, f('admin.forum.anonymous'))}</span>
                    <time dateTime={r.createdAt}>{r.createdAt ? formatDateTime(r.createdAt) : '—'}</time>
                    <span className="ltr">#{r.targetId}</span>
                  </p>
                  {r.reasons.length > 0 && (
                    <div className={fs.reasons} aria-label={f('admin.forum.reports.reasons')}>
                      {r.reasons.map((x, i) => (
                        <Badge key={`${x}-${i}`} tone="neutral">
                          {i18n.td(`admin.forum.reason.${x}`, x)}
                        </Badge>
                      ))}
                    </div>
                  )}
                  {r.note && (
                    <p className={fs.note} dir="auto">
                      {f('admin.forum.reports.note', { note: excerpt(r.note, 300) })}
                    </p>
                  )}
                  {canModerate && (
                    <div className={styles.actions}>
                      {reportActions(r).map((a) => (
                        <Button
                          key={a}
                          size="sm"
                          variant={a === 'REMOVE' ? 'danger' : 'secondary'}
                          onClick={() =>
                            mod.ask(
                              {
                                reportId: r.id,
                                type: r.targetType,
                                id: r.targetId,
                                title: r.preview.title ?? excerpt(r.preview.body, 60),
                              },
                              a,
                            )
                          }
                        >
                          {f(`admin.forum.action.${a}`)}
                        </Button>
                      ))}
                    </div>
                  )}
                </li>
              ))}
            </ul>
            <LoadMore hasMore={!!list.hasNextPage} loading={list.isFetchingNextPage} onLoadMore={() => void list.fetchNextPage()} />
          </>
        )}
      </div>
      {mod.dialogs}
    </>
  );
}
