// Sosyal moderasyon sekmeleri (Gönderiler sayfası): hikâyeler ve etiketler.
// API: GET /api/admin/stories, POST /stories/{id}/hide|unhide, DELETE /stories/{id};
//      GET /api/admin/hashtags/trending|banned, POST /hashtags/banned, DELETE /hashtags/banned/{tag} (api/adminSocial.ts).
import { useInfiniteQuery, useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';
import { adminSocialApi, qk } from '../../../api';
import type { AdminStory } from '../../../api/adminSocial';
import {
  Badge,
  Button,
  Checkbox,
  ConfirmDialog,
  EmptyState,
  ErrorState,
  FormField,
  Input,
  LoadMore,
  Skeleton,
  useToast,
} from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminErrorMessage } from '../campaigns/shared';
import styles from './posts.module.css';

export function StoriesTab() {
  const i18n = useI18n();
  const { t, formatDateTime, formatNumber } = i18n;
  const toast = useToast();
  const qc = useQueryClient();
  const [hiddenOnly, setHiddenOnly] = useState(false);
  const [del, setDel] = useState<AdminStory | null>(null);
  const list = useInfiniteQuery({
    queryKey: qk.adminSocial.stories(hiddenOnly),
    queryFn: ({ pageParam }) => adminSocialApi.listStories(hiddenOnly, pageParam, 20),
    initialPageParam: undefined as number | undefined,
    getNextPageParam: (last) => last.nextCursor ?? undefined,
  });
  const rows = useMemo(() => list.data?.pages.flatMap((p) => p.items) ?? [], [list.data]);
  const refresh = () => void qc.invalidateQueries({ queryKey: ['adminSocial', 'stories'] });
  const onError = (e: unknown) => toast.error(adminErrorMessage(i18n, e));
  const toggle = useMutation({
    mutationFn: (s: AdminStory) => (s.hidden ? adminSocialApi.unhideStory(s.id) : adminSocialApi.hideStory(s.id)),
    onSuccess: () => {
      toast.success(t('admin.social.updated'));
      refresh();
    },
    onError,
  });
  const remove = useMutation({
    mutationFn: (s: AdminStory) => adminSocialApi.deleteStory(s.id),
    onSuccess: () => {
      toast.success(t('admin.social.deleted'));
      setDel(null);
      refresh();
    },
    onError,
  });

  return (
    <>
      <p className={styles.note}>{t('admin.social.stories.note')}</p>
      <div className={styles.filters}>
        <Checkbox label={t('admin.social.stories.hiddenOnly')} checked={hiddenOnly} onChange={(e) => setHiddenOnly(e.target.checked)} />
      </div>
      {list.isError ? (
        <ErrorState description={adminErrorMessage(i18n, list.error)} onRetry={() => void list.refetch()} />
      ) : list.isLoading ? (
        <Skeleton height="10rem" width="100%" />
      ) : rows.length === 0 ? (
        <EmptyState icon="list" title={t('admin.social.stories.empty')} description=" " />
      ) : (
        <>
          <ul className={styles.list} data-testid="story-list">
            {rows.map((s) => (
              <li key={s.id} className={styles.row} data-testid="story-row">
                <div className={styles.rowHead}>
                  <span dir="auto">{s.author.displayName ?? `#${s.author.id}`}</span>
                  {s.author.email && <span className={`${styles.muted} ltr`}>{s.author.email}</span>}
                  <Badge>{s.kind}</Badge>
                  {s.hidden && <Badge tone="warning">{t('admin.posts.badge.hidden')}</Badge>}
                  <span className={styles.spacer} />
                  <time className={styles.muted} dateTime={s.createdAt}>
                    {formatDateTime(s.createdAt)}
                  </time>
                </div>
                <p className={styles.text} dir="auto">
                  {s.caption || s.bodyText || t('admin.posts.noText')}
                </p>
                <div className={styles.rowHead}>
                  <span className={styles.muted}>
                    {t('admin.social.stories.views', { n: formatNumber(s.viewCount) })} ·{' '}
                    {t('admin.social.stories.expires', { d: formatDateTime(s.expiresAt) })}
                  </span>
                  <span className={styles.spacer} />
                  <Button size="sm" variant="secondary" loading={toggle.isPending && toggle.variables?.id === s.id} onClick={() => toggle.mutate(s)}>
                    {s.hidden ? t('admin.posts.action.unhide') : t('admin.posts.action.hide')}
                  </Button>
                  <Button size="sm" variant="danger" onClick={() => setDel(s)}>
                    {t('admin.posts.action.delete')}
                  </Button>
                </div>
              </li>
            ))}
          </ul>
          <LoadMore hasMore={!!list.hasNextPage} loading={list.isFetchingNextPage} onLoadMore={() => void list.fetchNextPage()} />
        </>
      )}
      <ConfirmDialog
        open={del !== null}
        onClose={() => setDel(null)}
        onConfirm={() => del && remove.mutate(del)}
        title={t('admin.social.stories.deleteTitle')}
        message={t('admin.social.stories.deleteMessage')}
        confirmLabel={t('admin.posts.action.delete')}
        danger
        loading={remove.isPending}
      />
    </>
  );
}

export function TagsTab() {
  const i18n = useI18n();
  const { t, formatNumber } = i18n;
  const toast = useToast();
  const qc = useQueryClient();
  const [tag, setTag] = useState('');
  const trending = useQuery({ queryKey: qk.adminSocial.trending(), queryFn: adminSocialApi.trendingTags, staleTime: 60_000 });
  const banned = useQuery({ queryKey: qk.adminSocial.banned(), queryFn: adminSocialApi.bannedTags });
  const refresh = () => void qc.invalidateQueries({ queryKey: ['adminSocial'] });
  const onError = (e: unknown) => toast.error(adminErrorMessage(i18n, e));
  const ban = useMutation({
    mutationFn: (v: string) => adminSocialApi.banTag(v),
    onSuccess: () => {
      setTag('');
      toast.success(t('admin.social.updated'));
      refresh();
    },
    onError,
  });
  const unban = useMutation({
    mutationFn: (v: string) => adminSocialApi.unbanTag(v),
    onSuccess: () => {
      toast.success(t('admin.social.updated'));
      refresh();
    },
    onError,
  });
  const clean = tag.trim().replace(/^#/, '').toLowerCase();

  return (
    <>
      <section aria-labelledby="tags-trending-h">
        <h2 id="tags-trending-h">{t('admin.social.tags.trending')}</h2>
        {trending.isError ? (
          <ErrorState description={adminErrorMessage(i18n, trending.error)} onRetry={() => void trending.refetch()} />
        ) : trending.isLoading ? (
          <Skeleton height="5rem" width="100%" />
        ) : (trending.data?.items.length ?? 0) === 0 ? (
          <EmptyState icon="list" title={t('admin.social.tags.trendingEmpty')} description=" " />
        ) : (
          <ul className={styles.list} data-testid="trending-tags">
            {trending.data?.items.map((x) => (
              <li key={x.tag} className={styles.row}>
                <div className={styles.rowHead}>
                  <strong dir="auto">#{x.display}</strong>
                  <span className={styles.muted}>{t('admin.social.tags.posts', { n: formatNumber(x.postCount) })}</span>
                  <span className={styles.spacer} />
                  <Button size="sm" variant="danger" loading={ban.isPending && ban.variables === x.tag} onClick={() => ban.mutate(x.tag)}>
                    {t('admin.social.tags.ban')}
                  </Button>
                </div>
              </li>
            ))}
          </ul>
        )}
      </section>

      <section aria-labelledby="tags-banned-h">
        <h2 id="tags-banned-h">{t('admin.social.tags.banned')}</h2>
        <form
          className={styles.filters}
          onSubmit={(e) => {
            e.preventDefault();
            if (clean) ban.mutate(clean);
          }}
        >
          <FormField label={t('admin.social.tags.add')}>
            <Input className="ltr" value={tag} maxLength={40} placeholder="#" onChange={(e) => setTag(e.target.value)} />
          </FormField>
          <Button type="submit" disabled={!clean} loading={ban.isPending}>
            {t('admin.social.tags.ban')}
          </Button>
        </form>
        {banned.isError ? (
          <ErrorState description={adminErrorMessage(i18n, banned.error)} onRetry={() => void banned.refetch()} />
        ) : banned.isLoading ? (
          <Skeleton height="4rem" width="100%" />
        ) : (banned.data?.items.length ?? 0) === 0 ? (
          <EmptyState icon="list" title={t('admin.social.tags.bannedEmpty')} description=" " />
        ) : (
          <ul className={styles.list} data-testid="banned-tags">
            {banned.data?.items.map((x) => (
              <li key={x} className={styles.row}>
                <div className={styles.rowHead}>
                  <strong className="ltr">#{x}</strong>
                  <span className={styles.spacer} />
                  <Button size="sm" variant="secondary" onClick={() => unban.mutate(x)}>
                    {t('admin.social.tags.unban')}
                  </Button>
                </div>
              </li>
            ))}
          </ul>
        )}
      </section>
    </>
  );
}
