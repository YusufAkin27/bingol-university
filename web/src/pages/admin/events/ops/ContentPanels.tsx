import { useInfiniteQuery, useQuery } from '@tanstack/react-query';
import { useMemo } from 'react';
import {
  deleteEventAnnouncement,
  deleteEventFeedback,
  listEventAnnouncements,
  listEventFeedback,
  listEventOrganizers,
  removeEventOrganizer,
} from '../../../../api/adminEvents';
import { Badge, GuardedAction, LoadMore } from '../../../../components/ui';
import { useI18n } from '../../../../i18n/I18nProvider';
import { eventErrorMessage } from '../errors';
import { PanelState, opsInvalidate, opsKey } from './opsParts';
import styles from './ops.module.css';

/** Geri bildirim: ANONİM (yazan kimliği sunucudan hiç gelmez); yalnız uygunsuz içeriği silme. */
export function FeedbackPanel({ eventId }: { eventId: number }) {
  const i18n = useI18n();
  const { t, formatDateTime, formatNumber } = i18n;
  const q = useInfiniteQuery({
    queryKey: opsKey(eventId, 'feedback'),
    queryFn: ({ pageParam }) => listEventFeedback(eventId, { cursor: pageParam, size: 50 }),
    initialPageParam: null as number | null,
    getNextPageParam: (last) => last.nextCursor ?? undefined,
  });
  const items = useMemo(() => q.data?.pages.flatMap((p) => p.items) ?? [], [q.data]);
  const sm = q.data?.pages[0]?.summary;
  const max = Math.max(1, ...(sm?.distribution ?? [0]));

  return (
    <section className={styles.panel} aria-label={t('admin.p07.tab.feedback')} data-testid="panel-feedback">
      <p className={styles.muted}>{t('admin.p07.fb.anonymous')}</p>
      {sm && sm.total > 0 && (
        <div data-testid="fb-summary">
          <p>{t('admin.p07.fb.average', { avg: formatNumber(sm.average), total: formatNumber(sm.total) })}</p>
          <div className={styles.dist}>
            {[5, 4, 3, 2, 1].map((star) => {
              const n = sm.distribution[star - 1] ?? 0;
              return (
                <div key={star} className={styles.distRow}>
                  <span>{t('admin.p07.fb.stars', { n: star })}</span>
                  <span className={styles.track} aria-hidden="true">
                    <span className={styles.fill} style={{ inlineSize: `${(n / max) * 100}%` }} />
                  </span>
                  <span className="ltr">{formatNumber(n)}</span>
                </div>
              );
            })}
          </div>
        </div>
      )}
      <PanelState
        loading={q.isLoading}
        error={q.error}
        onRetry={() => void q.refetch()}
        empty={items.length === 0}
        emptyTitle={t('admin.p07.fb.empty')}
      >
        <ul className={styles.cards}>
          {items.map((f) => (
            <li key={f.id} className={styles.card} data-testid={`fb-${f.id}`}>
              <div className={styles.cardMain}>
                <span className={styles.name}>{t('admin.p07.fb.rating', { n: f.rating })}</span>
                {f.comment ? (
                  <p className={styles.note} dir="auto">
                    {f.comment}
                  </p>
                ) : (
                  <span className={styles.sub}>{t('admin.p07.fb.noComment')}</span>
                )}
                <span className={styles.sub}>{formatDateTime(f.createdAt)}</span>
              </div>
              <GuardedAction
                size="sm"
                variant="danger"
                danger
                title={t('admin.p07.fb.delete.title')}
                consequence={t('admin.p07.fb.delete.consequence')}
                irreversible
                requireReason
                confirmLabel={t('admin.p07.fb.delete.confirm')}
                errorMessage={(e) => eventErrorMessage(i18n, e)}
                successMessage={t('admin.p07.fb.delete.done')}
                invalidateKeys={opsInvalidate(eventId)}
                onConfirm={({ reason, idempotencyKey }) =>
                  deleteEventFeedback(eventId, f.id, { reason, idempotencyKey })
                }
              >
                {t('admin.p07.fb.delete')}
              </GuardedAction>
            </li>
          ))}
        </ul>
        <LoadMore
          hasMore={!!q.hasNextPage}
          loading={q.isFetchingNextPage}
          onLoadMore={() => void q.fetchNextPage()}
        />
      </PanelState>
    </section>
  );
}

/** Duyuru kayıtları (metin saklanmaz): gönderim kaydı silme; gönderilen bildirimler geri alınmaz. */
export function AnnouncementsPanel({ eventId }: { eventId: number }) {
  const i18n = useI18n();
  const { t, formatDateTime, formatNumber } = i18n;
  const q = useInfiniteQuery({
    queryKey: opsKey(eventId, 'announcements'),
    queryFn: ({ pageParam }) => listEventAnnouncements(eventId, { cursor: pageParam, size: 50 }),
    initialPageParam: null as number | null,
    getNextPageParam: (last) => last.nextCursor ?? undefined,
  });
  const items = useMemo(() => q.data?.pages.flatMap((p) => p.items) ?? [], [q.data]);

  return (
    <section
      className={styles.panel}
      aria-label={t('admin.p07.tab.announcements')}
      data-testid="panel-announcements"
    >
      <p className={styles.muted}>{t('admin.p07.ann.hint')}</p>
      <PanelState
        loading={q.isLoading}
        error={q.error}
        onRetry={() => void q.refetch()}
        empty={items.length === 0}
        emptyTitle={t('admin.p07.ann.empty')}
      >
        <ul className={styles.cards}>
          {items.map((a) => (
            <li key={a.id} className={styles.card} data-testid={`ann-${a.id}`}>
              <div className={styles.cardMain}>
                <span className={styles.name}>{formatDateTime(a.createdAt)}</span>
                <span className={styles.sub} dir="auto">
                  {t('admin.p07.ann.sender')}: {a.senderName} ·{' '}
                  {t('admin.p07.ann.recipients', { n: formatNumber(a.recipients) })}
                </span>
              </div>
              <GuardedAction
                size="sm"
                variant="danger"
                danger
                title={t('admin.p07.ann.delete.title')}
                consequence={t('admin.p07.ann.delete.consequence')}
                irreversible
                requireReason
                confirmLabel={t('admin.p07.ann.delete.confirm')}
                errorMessage={(e) => eventErrorMessage(i18n, e)}
                successMessage={t('admin.p07.ann.delete.done')}
                invalidateKeys={opsInvalidate(eventId)}
                onConfirm={({ reason, idempotencyKey }) =>
                  deleteEventAnnouncement(eventId, a.id, { reason, idempotencyKey })
                }
              >
                {t('admin.p07.ann.delete')}
              </GuardedAction>
            </li>
          ))}
        </ul>
        <LoadMore
          hasMore={!!q.hasNextPage}
          loading={q.isFetchingNextPage}
          onLoadMore={() => void q.fetchNextPage()}
        />
      </PanelState>
    </section>
  );
}

/** Düzenleyenler: sahip korunur; yalnız ortak düzenleyen çıkarılır (sunucu son aktif düzenleyeni de korur). */
export function OrganizersPanel({ eventId }: { eventId: number }) {
  const i18n = useI18n();
  const { t, formatDateTime } = i18n;
  const q = useQuery({
    queryKey: opsKey(eventId, 'organizers'),
    queryFn: () => listEventOrganizers(eventId),
  });
  const rows = q.data ?? [];

  return (
    <section
      className={styles.panel}
      aria-label={t('admin.p07.tab.organizers')}
      data-testid="panel-organizers"
    >
      <PanelState
        loading={q.isLoading}
        error={q.error}
        onRetry={() => void q.refetch()}
        empty={rows.length === 0}
        emptyTitle={t('admin.p07.org.empty')}
      >
        <ul className={styles.cards}>
          {rows.map((o) => (
            <li key={o.userId} className={styles.card} data-testid={`org-${o.userId}`}>
              <div className={styles.cardMain}>
                <span className={styles.name} dir="auto">
                  {o.displayName}
                </span>
                <span className={`${styles.sub} ltr`}>{o.emailMasked ?? '—'}</span>
                <span className={styles.sub}>{formatDateTime(o.createdAt)}</span>
              </div>
              <div className={styles.actions}>
                <Badge tone={o.role === 'OWNER' ? 'primary' : 'info'}>
                  {t(`admin.p07.org.role.${o.role}`)}
                </Badge>
                {o.removable ? (
                  <GuardedAction
                    size="sm"
                    variant="danger"
                    danger
                    title={t('admin.p07.org.remove.title', { name: o.displayName })}
                    consequence={t('admin.p07.org.remove.consequence')}
                    irreversible
                    requireReason
                    confirmLabel={t('admin.p07.org.remove.confirm')}
                    errorMessage={(e) => eventErrorMessage(i18n, e)}
                    successMessage={t('admin.p07.org.remove.done')}
                    invalidateKeys={opsInvalidate(eventId)}
                    onConfirm={({ reason, idempotencyKey }) =>
                      removeEventOrganizer(eventId, o.userId, { reason, idempotencyKey })
                    }
                  >
                    {t('admin.p07.org.remove')}
                  </GuardedAction>
                ) : (
                  <span className={styles.sub}>{t('admin.p07.org.protected')}</span>
                )}
              </div>
            </li>
          ))}
        </ul>
      </PanelState>
    </section>
  );
}
