import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import {
  cancelMailCampaign,
  getMailCampaign,
  listRecipients,
  mailKeys,
  pauseMailCampaign,
  resumeMailCampaign,
  type MailCampaignView,
  type RecipientRow,
  type RecipientStatus,
} from '../../../api/adminMail';
import {
  Badge,
  Button,
  Card,
  ConfirmDialog,
  EmptyState,
  ErrorState,
  FormField,
  PageHeader,
  Pagination,
  Select,
  Skeleton,
  Table,
  useToast,
  type Column,
} from '../../../components/ui';
import { ReasonField } from '../../../components/admin/guard/ReasonField';
import { ADMIN_REASON_MIN, isReasonValid } from '../../../components/admin/guard/match';
import { useI18n } from '../../../i18n/I18nProvider';
import { usePageTitle } from '../../../lib/hooks';
import { paths } from '../../../paths';
import { Callout } from '../campaigns/shared';
import { CampaignStatusPill, ProgressBar } from './MailParts';
import { isCampaignLive, mailErrorMessage } from './mailLogic';
import styles from './mail.module.css';

const RECIPIENT_STATUSES: RecipientStatus[] = ['PENDING', 'QUEUED', 'SKIPPED', 'FAILED', 'CANCELLED'];

export function CampaignDetail({ id }: { id: number }) {
  const i18n = useI18n();
  const { t, td, formatNumber, formatDateTime } = i18n;
  const toast = useToast();
  const qc = useQueryClient();
  const [confirm, setConfirm] = useState<null | 'pause' | 'resume' | 'cancel'>(null);
  // W1-B (T-013): iptal gerekce ister (X-Admin-Reason); duraklat/surdur istemez.
  const [why, setWhy] = useState('');
  const needsReason = confirm === 'cancel';
  const [rStatus, setRStatus] = useState<RecipientStatus | ''>('');
  const [rPage, setRPage] = useState(0);

  const q = useQuery({
    queryKey: mailKeys.campaign(id),
    queryFn: () => getMailCampaign(id),
    // Gönderirken (ya da zamanı gelmek üzereyken) 5 sn'de bir yenile
    refetchInterval: (query) => (query.state.data && isCampaignLive(query.state.data.status) ? 5000 : false),
  });
  const c = q.data;
  usePageTitle(c?.name ?? t('admin.mail.campaigns.title'));

  const rParams = { status: rStatus || undefined, page: rPage, size: 50 };
  const recipients = useQuery({
    queryKey: mailKeys.recipients(id, rParams),
    queryFn: () => listRecipients(id, rParams),
    enabled: !!c && c.counters.target > 0,
    refetchInterval: c && isCampaignLive(c.status) ? 5000 : false,
  });

  const act = useMutation({
    mutationFn: (a: 'pause' | 'resume' | 'cancel') =>
      a === 'pause'
        ? pauseMailCampaign(id)
        : a === 'resume'
          ? resumeMailCampaign(id)
          : cancelMailCampaign(id, { reason: why }),
    onSuccess: (v: MailCampaignView) => {
      qc.setQueryData(mailKeys.campaign(id), v);
      void qc.invalidateQueries({ queryKey: ['adminMail', 'campaigns'] });
      void qc.invalidateQueries({ queryKey: ['adminMail', 'recipients', id] });
      setConfirm(null);
      toast.success(t('admin.mail.detail.done'));
    },
    onError: (e) => {
      setConfirm(null);
      toast.error(mailErrorMessage(i18n, e));
    },
  });

  if (q.isLoading) return <Skeleton height={300} />;
  if (q.isError || !c)
    return <ErrorState description={mailErrorMessage(i18n, q.error)} onRetry={() => void q.refetch()} />;

  const k = c.counters;
  const canPause = c.status === 'SCHEDULED' || c.status === 'SENDING';
  const canResume = c.status === 'PAUSED';
  const canCancel = ['DRAFT', 'SCHEDULED', 'SENDING', 'PAUSED'].includes(c.status);
  const reasons = Object.entries(k.skippedByReason ?? {}).filter(([, n]) => n > 0);
  const langs = Object.entries(k.languages ?? {}).filter(([, n]) => n > 0);

  const cols: Column<RecipientRow>[] = [
    { key: 'email', header: t('admin.mail.detail.col.email'), render: (r) => <span className="ltr">{r.email}</span> },
    {
      key: 'status',
      header: t('common.status'),
      render: (r) => <Badge tone={r.status === 'FAILED' ? 'danger' : r.status === 'QUEUED' ? 'success' : 'neutral'}>{t(`admin.mail.rstatus.${r.status}`)}</Badge>,
    },
    {
      key: 'lang',
      header: t('common.language'),
      render: (r) =>
        r.lang ? `${r.lang.toUpperCase()}${r.langFallback ? ` (${t('admin.mail.detail.fallbackShort')})` : ''}` : '—',
    },
    {
      key: 'detail',
      header: t('admin.mail.detail.col.detail'),
      render: (r) => (r.skipReason ? td(`admin.mail.skip.${r.skipReason}`, r.skipReason) : (r.errorCode ?? '—')),
    },
    { key: 'updated', header: t('admin.mail.templates.col.updated'), render: (r) => <span className={styles.nowrap}>{formatDateTime(r.updatedAt)}</span> },
  ];

  const stat = (label: string, v: number) => (
    <div className={styles.stat}>
      <p className={styles.statLabel}>{label}</p>
      <p className={styles.statValue}>{formatNumber(v)}</p>
    </div>
  );

  return (
    <div>
      <PageHeader
        title={c.name}
        breadcrumbs={[{ label: t('admin.mail.campaigns.title'), to: paths.admin.mailCampaigns }, { label: c.name }]}
        actions={
          <div className={styles.row}>
            <CampaignStatusPill status={c.status} />
            {canPause && <Button variant="secondary" onClick={() => setConfirm('pause')}>{t('admin.mail.detail.pause')}</Button>}
            {canResume && <Button variant="secondary" onClick={() => setConfirm('resume')}>{t('admin.mail.detail.resume')}</Button>}
            {canCancel && <Button
              variant="danger"
              onClick={() => {
                setWhy('');
                setConfirm('cancel');
              }}
            >{t('admin.mail.detail.cancel')}</Button>}
          </div>
        }
      />
      <div className={styles.stack}>
        {isCampaignLive(c.status) && (
          <p className={styles.muted} role="status">
            {t('admin.mail.detail.autoRefresh')}
          </p>
        )}
        {c.status === 'FAILED' && (
          <div role="alert">
            <Callout tone="danger" title={t('admin.mail.detail.failedTitle')}>
              {c.error ?? t('admin.mail.detail.failedHint')}
            </Callout>
          </div>
        )}
        <Card>
          <ProgressBar percent={k.progressPercent} label={t('admin.mail.detail.progress')} />
          <div className={styles.stats} style={{ marginBlockStart: 'var(--space-4)' }}>
            {stat(t('admin.mail.detail.target'), k.target)}
            {stat(t('admin.mail.detail.pending'), k.pending)}
            {stat(t('admin.mail.detail.queued'), k.queued)}
            {stat(t('admin.mail.detail.skipped'), k.skipped)}
            {stat(t('admin.mail.detail.failed'), k.failed)}
            {stat(t('admin.mail.detail.cancelled'), k.cancelled)}
          </div>
          <p className={styles.muted} style={{ marginBlockStart: 'var(--space-3)' }}>
            {t('admin.mail.detail.queuedNote')}
          </p>
        </Card>

        <div className={styles.grid2}>
          <Card title={t('admin.mail.detail.info')}>
            <dl className={styles.dl}>
              <dt>{t('admin.mail.wizard.template')}</dt>
              <dd>
                {c.templateName}
                {c.templateVersion ? ` (v${c.templateVersion})` : ''}
              </dd>
              <dt>{t('admin.mail.wizard.step.audience')}</dt>
              <dd>{td(`admin.mail.aud.${c.audience.type}`, c.audience.type)}</dd>
              <dt>{t('admin.mail.detail.scheduledAt')}</dt>
              <dd>{c.scheduledAt ? formatDateTime(c.scheduledAt) : t('admin.mail.sched.now')}</dd>
              <dt>{t('admin.mail.detail.startedAt')}</dt>
              <dd>{c.startedAt ? formatDateTime(c.startedAt) : '—'}</dd>
              <dt>{t('admin.mail.detail.finishedAt')}</dt>
              <dd>{c.finishedAt ? formatDateTime(c.finishedAt) : '—'}</dd>
            </dl>
          </Card>
          <Card title={t('admin.mail.prev.languages')}>
            {langs.length === 0 ? (
              <p className={styles.muted}>—</p>
            ) : (
              <ul className={styles.kv}>
                {langs.map(([l, n]) => (
                  <li key={l}>
                    <span>{td(`admin.mail.langName.${l}`, l)}</span>
                    <strong>{formatNumber(n)}</strong>
                  </li>
                ))}
              </ul>
            )}
            {k.languageFallback > 0 && (
              <p className={styles.muted}>{t('admin.mail.prev.fallback', { n: formatNumber(k.languageFallback) })}</p>
            )}
          </Card>
          <Card title={t('admin.mail.prev.reasons')}>
            {reasons.length === 0 ? (
              <p className={styles.muted}>—</p>
            ) : (
              <ul className={styles.kv}>
                {reasons.map(([r, n]) => (
                  <li key={r}>
                    <span>{td(`admin.mail.skip.${r}`, r)}</span>
                    <strong>{formatNumber(n)}</strong>
                  </li>
                ))}
              </ul>
            )}
          </Card>
        </div>

        <Card title={t('admin.mail.detail.recipients')}>
          <div className={styles.toolbar}>
            <FormField label={t('common.status')}>
              <Select
                value={rStatus}
                onChange={(e) => {
                  setRStatus(e.target.value as RecipientStatus | '');
                  setRPage(0);
                }}
              >
                <option value="">{t('common.all')}</option>
                {RECIPIENT_STATUSES.map((s) => (
                  <option key={s} value={s}>
                    {t(`admin.mail.rstatus.${s}`)}
                  </option>
                ))}
              </Select>
            </FormField>
          </div>
          {recipients.isError ? (
            <ErrorState compact description={mailErrorMessage(i18n, recipients.error)} onRetry={() => void recipients.refetch()} />
          ) : (
            <>
              <Table
                caption={t('admin.mail.detail.recipients')}
                columns={cols}
                rows={recipients.data?.items}
                rowKey={(r) => r.userId}
                loading={recipients.isLoading && k.target > 0}
                empty={<EmptyState compact icon="users" title={t('admin.mail.detail.noRecipients')} />}
              />
              <Pagination
                page={recipients.data?.page ?? rPage}
                totalPages={recipients.data?.totalPages ?? 0}
                totalItems={recipients.data?.totalItems}
                onPageChange={setRPage}
              />
            </>
          )}
        </Card>
      </div>

      <ConfirmDialog
        open={confirm !== null}
        onClose={() => setConfirm(null)}
        onConfirm={() => confirm && act.mutate(confirm)}
        loading={act.isPending}
        danger={confirm === 'cancel'}
        title={confirm ? t(`admin.mail.detail.confirm.${confirm}.title`) : ''}
        message={confirm ? t(`admin.mail.detail.confirm.${confirm}.msg`) : undefined}
        confirmLabel={confirm ? t(`admin.mail.detail.${confirm}`) : undefined}
        confirmDisabled={needsReason && !isReasonValid(why, ADMIN_REASON_MIN)}
        initialFocus={needsReason ? 'content' : undefined}
      >
        {needsReason && (
          <ReasonField
            value={why}
            onChange={setWhy}
            minLength={ADMIN_REASON_MIN}
            label={t('admin.wp02.actionReason.label')}
            disabled={act.isPending}
            focusOnMount
          />
        )}
      </ConfirmDialog>
    </div>
  );
}
