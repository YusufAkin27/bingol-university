// Şikâyet bağlamı kartı: şikâyet eden/edilen, sebep+not, şikâyet edilen mesajın (silinmiş olsa da) çevresi ve ilişkili şikâyetler.
// API: GET /api/admin/reports/{id} (api/adminChat.ts#getReportDetail). Sunucu her çağrıda denetim kaydı yazar.
import { useQuery } from '@tanstack/react-query';
import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { adminChatApi, qk } from '../../../api';
import type { ReportPerson } from '../../../api/types';
import { Badge, Card, ErrorState, Skeleton } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { paths } from '../../../paths';
import { FeedContentMedia } from '../posts/FeedContentMedia';
import { adminErrorMessage } from '../campaigns/shared';
import { ChatBubble } from './ChatBubble';
import { chatReasonKey, isReasonRequiredError, rejectChatReason } from './chatReason';
import { ReasonGate } from './ReasonGate';
import { Lightbox } from './Lightbox';
import { collectLightboxItems } from './chatLogic';
import styles from './chat.module.css';

function PersonLink({ p }: { p: ReportPerson | null | undefined }) {
  if (!p || p.id == null) return <span className={styles.muted}>—</span>;
  return (
    <span dir="auto">
      <Link to={paths.admin.user(p.id)}>{p.displayName ?? `#${p.id}`}</Link>
      {p.email && <span className={`${styles.muted} ltr`}> {p.email}</span>}
    </span>
  );
}

/** Sunucu yolu `/admin/...` döner; yönetim tabanı farklıysa uyarlanır. */
export function localViewerPath(p: string | null | undefined): string | null {
  if (!p) return null;
  return p.replace(/^\/admin(?=\/)/, paths.admin.dashboard);
}

/**
 * Şikâyet bağlamı. Sohbet MESAJI şikâyetlerinde özel yazışma açıldığı için sebep gerekir (ReasonGate,
 * `X-Admin-Reason`); diğer hedef türlerinde sebep istenmez. Sunucu beklenmedik biçimde sebep isterse kapı açılır.
 */
export function ReportContextCard({ reportId, targetType }: { reportId: number; targetType?: string }) {
  const { t } = useI18n();
  const [forced, setForced] = useState(false);
  const body = (reason: string | null) => (
    <ReportContextBody reportId={reportId} reason={reason} onNeedReason={() => setForced(true)} />
  );
  return (
    <Card title={t('admin.reports.ctx.title')}>
      {targetType === 'MESSAGE' || forced ? (
        <ReasonGate storeKey={chatReasonKey.report(reportId)} initialText={`${t('admin.wp02.reason.tpl.reportText')}${reportId}`}>
          {(reason) => body(reason)}
        </ReasonGate>
      ) : (
        body(null)
      )}
    </Card>
  );
}

function ReportContextBody({
  reportId,
  reason,
  onNeedReason,
}: {
  reportId: number;
  reason: string | null;
  onNeedReason: () => void;
}) {
  const i18n = useI18n();
  const { t, formatDateTime } = i18n;
  const q = useQuery({
    queryKey: qk.reports.detail(reportId),
    queryFn: () => adminChatApi.getReportDetail(reportId, reason),
    staleTime: Infinity,
    gcTime: 0,
    refetchOnWindowFocus: false,
    retry: false,
  });
  const needsReason = isReasonRequiredError(q.error);
  useEffect(() => {
    if (!needsReason) return;
    if (reason) rejectChatReason(chatReasonKey.report(reportId));
    else onNeedReason();
  }, [needsReason, reason, reportId, onNeedReason]);
  const [lb, setLb] = useState<number | null>(null);
  const d = q.data;
  const ctx = d?.context ?? null;
  // Şikâyet edilen kullanıcının mesajları bir yanda, diğerleri öbür yanda
  const msgs = useMemo(
    () =>
      (ctx?.messages ?? []).map((x) => ({
        ...x.message,
        mine: d?.reportedUser?.id != null && x.message.senderId === d.reportedUser.id,
      })),
    [ctx, d],
  );
  const lbItems = useMemo(() => collectLightboxItems(msgs, () => null), [msgs]);
  const viewer = localViewerPath(d?.viewerPath);

  return (
    <>
      {q.isError ? (
        <ErrorState compact description={adminErrorMessage(i18n, q.error)} onRetry={() => void q.refetch()} />
      ) : q.isLoading || !d ? (
        <Skeleton height="8rem" width="100%" />
      ) : (
        <div data-testid="report-context">
          <dl className={styles.facts}>
            <div>
              <dt>{t('admin.reports.ctx.reporter')}</dt>
              <dd data-testid="ctx-reporter">
                <PersonLink p={d.reporter} />
              </dd>
            </div>
            <div>
              <dt>{t('admin.reports.ctx.reported')}</dt>
              <dd data-testid="ctx-reported">
                <PersonLink p={d.reportedUser} />
              </dd>
            </div>
            <div>
              <dt>{t('admin.reports.ctx.reason')}</dt>
              <dd>
                <Badge tone="primary">{i18n.td(`admin.reports.reason.${d.reason}`, d.reason)}</Badge>{' '}
                {d.reasonCode && <Badge tone="neutral">{i18n.td(`admin.reports.reasonCode.${d.reasonCode}`, d.reasonCode)}</Badge>}
              </dd>
            </div>
            <div>
              <dt>{t('admin.reports.note')}</dt>
              <dd dir="auto">{d.note ?? t('admin.reports.noNote')}</dd>
            </div>
          </dl>

          {ctx?.userStats && (
            <p className={styles.muted}>
              {t('admin.reports.ctx.userStats', {
                n: ctx.userStats.reportsAgainstUser,
                active: ctx.userStats.activeStrikes,
                total: ctx.userStats.totalStrikes,
              })}
            </p>
          )}

          {viewer && (
            <p>
              <Link to={viewer} data-testid="open-in-chat">
                {t('admin.reports.ctx.openInChat')}
              </Link>
            </p>
          )}

          {ctx && ctx.type !== 'NONE' && !ctx.targetExists && <p className={styles.muted}>{t('admin.reports.ctx.missing')}</p>}

          {ctx?.conversation && (
            <p className={styles.muted} dir="auto">
              {t('admin.reports.ctx.conversation', {
                title: ctx.conversation.title ?? t(`admin.chat.type.${ctx.conversation.type}`),
                n: ctx.conversation.memberCount,
              })}
            </p>
          )}

          {msgs.length > 0 && (
            <>
              <p className={styles.muted}>{t('admin.reports.ctx.surrounding')}</p>
              <ul className={styles.ctxList} data-testid="ctx-messages">
                {msgs.map((m, i) => (
                  <ChatBubble
                    key={m.id}
                    m={m}
                    reported={!!ctx?.messages[i]?.reported}
                    highlighted={!!ctx?.messages[i]?.reported}
                    onOpenMedia={(aid) => {
                      const k = lbItems.findIndex((x) => x.key === `a${aid}`);
                      if (k >= 0) setLb(k);
                    }}
                  />
                ))}
              </ul>
            </>
          )}

          {ctx?.content && (
            <div data-testid="ctx-content">
              <p>
                <Badge tone="primary">{ctx.content.kind}</Badge>{' '}
                {ctx.content.deleted && <Badge tone="danger">{t('admin.chat.badge.deleted')}</Badge>}{' '}
                {ctx.content.status && <Badge tone="neutral">{ctx.content.status}</Badge>}
              </p>
              {ctx.content.title && (
                <p>
                  <strong dir="auto">{ctx.content.title}</strong>
                </p>
              )}
              {ctx.content.text && (
                <p className={styles.text} dir="auto">
                  {ctx.content.text}
                </p>
              )}
              {ctx.content.media && ctx.content.media.length > 0 && <FeedContentMedia media={ctx.content.media} createdAt={ctx.content.createdAt} />}
              {ctx.content.createdAt && <p className={styles.muted}>{formatDateTime(ctx.content.createdAt)}</p>}
              {ctx.content.kind === 'FEED_POST' && ctx.content.postId != null && (
                <p>
                  <Link to={`${paths.admin.posts}?open=${ctx.content.postId}`} data-testid="open-in-post">
                    {t('admin.reports.ctx.openPost')}
                  </Link>
                </p>
              )}
            </div>
          )}

          {d.relatedReports && d.relatedReports.sameTargetCount > 0 && (
            <div data-testid="ctx-related">
              <p className={styles.muted}>{t('admin.reports.ctx.related', { n: d.relatedReports.sameTargetCount })}</p>
              <ul>
                {d.relatedReports.last.map((r) => (
                  <li key={r.id}>
                    <span dir="auto">{r.reporter?.displayName ?? '?'}</span> ·{' '}
                    {i18n.td(`admin.reports.reason.${r.reason}`, r.reason)} ·{' '}
                    <span className={styles.muted}>{formatDateTime(r.createdAt)}</span>
                  </li>
                ))}
              </ul>
            </div>
          )}
        </div>
      )}
      {lb !== null && <Lightbox items={lbItems} index={lb} onIndex={setLb} onClose={() => setLb(null)} />}
    </>
  );
}
