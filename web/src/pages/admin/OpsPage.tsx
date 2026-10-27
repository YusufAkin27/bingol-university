// SAYFA: Operasyon paneli (/admin/ops) — sekmeler: Sağlık, Kuyruklar, Yedekleme, Sürüm ve bakım, Dış bağlantılar.
// API: GET /api/admin/ops/health, GET /api/admin/ops/mail-outbox/stats (+ POST .../retry-dead), GET /api/admin/push/outbox/stats
//      (+ POST .../retry-dead), GET /api/admin/ops/transcode/stats, GET /api/admin/ops/backup-status (api/ops.ts),
//      GET /api/status (kaynak sistem bakımı), GET/PUT /api/admin/settings (sürüm, bakım, ops_sentry_url, ops_grafana_url).
// Henüz olmayan uçlar (404/501) kartta zarifçe "Veri yok" gösterir; docs/API_CONTRACTS_V2.md "İSTEK(web→backend)".
// Sayfa görünürken 30 sn'de bir otomatik yenilenir.
import { useMutation, useQuery, useQueryClient, type UseQueryResult } from '@tanstack/react-query';
import { useState, type ReactNode } from 'react';
import { Link } from 'react-router-dom';
import { isApiError } from '../../api/client';
import { opsApi, qk } from '../../api';
import { getSettings, getSyncStatus, putSetting } from '../../api/settings';
import { levelOf, safeHttpsUrl, type OpsLevel } from '../../api/ops';
import {
  Button,
  Card,
  EmptyState,
  ErrorState,
  FormField,
  Icon,
  Input,
  PageHeader,
  Skeleton,
  StatusPill,
  Tabs,
  useToast,
} from '../../components/ui';
import type { Tone } from '../../components/ui/Badge';
import { useI18n, type I18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { paths } from '../../paths';
import { adminErrorMessage, Callout } from './campaigns/shared';
import styles from './moderation/moderation.module.css';

const POLL_MS = 30_000;
const STALE_BACKUP_MS = 48 * 3600 * 1000;
type TabId = 'health' | 'queues' | 'backup' | 'release' | 'links';
const TABS: TabId[] = ['health', 'queues', 'backup', 'release', 'links'];

const TONE: Record<OpsLevel, Tone> = { UP: 'success', WARN: 'warning', DOWN: 'danger', UNKNOWN: 'neutral' };

/** Yalnızca sayfa görünürken yoklar. */
function useOpsQuery<T>(name: string, fn: () => Promise<T>): UseQueryResult<T> {
  return useQuery({
    queryKey: qk.ops.part(name),
    queryFn: fn,
    refetchInterval: () =>
      typeof document === 'undefined' || document.visibilityState === 'visible' ? POLL_MS : false,
    retry: (n, e) => !unavailable(e) && n < 1,
  });
}

/** Sunucu ucu henüz yok mu (404/405/501)? */
function unavailable(e: unknown): boolean {
  return isApiError(e) && (e.status === 404 || e.status === 405 || e.status === 501);
}

function Level({ i18n, status }: { i18n: I18n; status: string | undefined }) {
  const level = levelOf(status);
  return (
    <StatusPill tone={TONE[level]}>{i18n.t(`admin.ops.status.${level}` as 'admin.ops.status.UP')}</StatusPill>
  );
}

/** Yükleniyor / veri yok / hata / içerik. */
function Panel<T>({
  i18n,
  q,
  children,
}: {
  i18n: I18n;
  q: UseQueryResult<T>;
  children: (data: T) => ReactNode;
}) {
  const { t } = i18n;
  if (q.isError) {
    if (unavailable(q.error))
      return (
        <EmptyState
          compact
          icon="info"
          title={t('admin.ops.noData')}
          description={t('admin.ops.noDataHint')}
        />
      );
    return (
      <ErrorState compact description={adminErrorMessage(i18n, q.error)} onRetry={() => void q.refetch()} />
    );
  }
  if (q.isLoading || q.data === undefined) return <Skeleton height="5rem" width="100%" />;
  return <>{children(q.data)}</>;
}

function Updated({ i18n, at }: { i18n: I18n; at: number }) {
  if (!at) return null;
  return <p className={styles.muted}>{i18n.t('admin.ops.updated', { time: i18n.formatDateTime(at) })}</p>;
}

function Stat({ label, value, warn }: { label: string; value: ReactNode; warn?: boolean }) {
  return (
    <div>
      <dt className={styles.muted}>{label}</dt>
      <dd data-warn={warn || undefined}>
        <strong>{value}</strong>
      </dd>
    </div>
  );
}

// ---------- Sağlık ----------
function HealthTab({ i18n }: { i18n: I18n }) {
  const { t, formatDateTime } = i18n;
  const health = useOpsQuery('health', opsApi.getHealth);
  const sources = useOpsQuery('sources', getSyncStatus);
  return (
    <div className={styles.stack}>
      <Card title={t('admin.ops.health.components')}>
        <Panel i18n={i18n} q={health}>
          {(h) => (
            <>
              <p>
                {t('admin.ops.health.overall')}: <Level i18n={i18n} status={h.status} />
              </p>
              <ul className={styles.rowList}>
                {Object.entries(h.components ?? {}).map(([name, c]) => (
                  <li key={name} className={styles.item}>
                    <div className={styles.itemHead}>
                      <strong className="ltr">{name}</strong>
                      <Level i18n={i18n} status={c.status} />
                    </div>
                    {c.details && (
                      <p className={styles.mono}>
                        {Object.entries(c.details)
                          .map(([k, v]) => `${k}=${String(v)}`)
                          .join(' · ')}
                      </p>
                    )}
                  </li>
                ))}
              </ul>
              <Updated i18n={i18n} at={health.dataUpdatedAt} />
            </>
          )}
        </Panel>
      </Card>
      <Card title={t('admin.ops.health.sources')}>
        <Panel i18n={i18n} q={sources}>
          {(s) => (
            <ul className={styles.rowList}>
              {Object.entries(s).map(([key, v]) => (
                <li key={key} className={styles.item}>
                  <div className={styles.itemHead}>
                    <strong>{i18n.td(`admin.ops.health.source.${key}`, key)}</strong>
                    <StatusPill tone={v.maintenance ? 'warning' : 'success'}>
                      {t(v.maintenance ? 'admin.ops.health.sourceMaint' : 'admin.ops.health.sourceOk')}
                    </StatusPill>
                  </div>
                  <p className={styles.muted}>
                    {v.lastSuccessAt
                      ? t('admin.ops.health.lastSuccess', { time: formatDateTime(v.lastSuccessAt) })
                      : t('admin.ops.health.never')}
                  </p>
                </li>
              ))}
            </ul>
          )}
        </Panel>
      </Card>
    </div>
  );
}

// ---------- Kuyruklar ----------
function RetryButton({
  i18n,
  run,
  invalidate,
}: {
  i18n: I18n;
  run: () => Promise<{ requeued: number }>;
  invalidate: string;
}) {
  const qc = useQueryClient();
  const toast = useToast();
  const m = useMutation({
    mutationFn: run,
    onSuccess: (r) => {
      toast.success(i18n.t('admin.ops.q.retried', { n: String(r?.requeued ?? 0) }));
      void qc.invalidateQueries({ queryKey: qk.ops.part(invalidate) });
    },
    onError: (e) => toast.error(adminErrorMessage(i18n, e)),
  });
  return (
    <Button variant="secondary" size="sm" loading={m.isPending} onClick={() => m.mutate()}>
      {i18n.t('admin.ops.q.retry')}
    </Button>
  );
}

function ageText(i18n: I18n, s: number | null | undefined): string {
  return s === null || s === undefined
    ? i18n.t('admin.ops.q.none')
    : i18n.t('admin.ops.q.oldestAge', { n: i18n.formatNumber(s) });
}

function QueuesTab({ i18n }: { i18n: I18n }) {
  const { t, formatNumber: n } = i18n;
  const mail = useOpsQuery('mail', opsApi.getMailStats);
  const push = useOpsQuery('push', opsApi.getPushStats);
  const tc = useOpsQuery('transcode', opsApi.getTranscodeStats);
  return (
    <div className={styles.stack}>
      <Card title={t('admin.ops.q.mail')}>
        <Panel i18n={i18n} q={mail}>
          {(s) => (
            <>
              <dl className={styles.statGrid}>
                <Stat label={t('admin.ops.q.pending')} value={n(s.pending)} />
                {s.sending !== undefined && <Stat label={t('admin.ops.q.sending')} value={n(s.sending)} />}
                <Stat label={t('admin.ops.q.dead')} value={n(s.dead)} warn={s.dead > 0} />
                {s.sentLast24h !== undefined && (
                  <Stat label={t('admin.ops.q.sent24h')} value={n(s.sentLast24h)} />
                )}
                <Stat label={t('admin.ops.q.oldest')} value={ageText(i18n, s.oldestPendingAgeSeconds)} />
              </dl>
              {s.dead > 0 && <RetryButton i18n={i18n} run={opsApi.retryMailDead} invalidate="mail" />}
              <Updated i18n={i18n} at={mail.dataUpdatedAt} />
            </>
          )}
        </Panel>
      </Card>
      <Card title={t('admin.ops.q.push')}>
        <Panel i18n={i18n} q={push}>
          {(s) => (
            <>
              {!s.enabled && (
                <Callout tone="warning" role="status">
                  {t('admin.ops.q.disabled')}
                </Callout>
              )}
              <dl className={styles.statGrid}>
                <Stat label={t('admin.ops.q.pending')} value={n(s.pending)} />
                <Stat label={t('admin.ops.q.sending')} value={n(s.sending)} />
                <Stat label={t('admin.ops.q.failed')} value={n(s.failed)} warn={s.failed > 0} />
                <Stat label={t('admin.ops.q.dead')} value={n(s.dead)} warn={s.dead > 0} />
                <Stat label={t('admin.ops.q.sent24h')} value={n(s.sentLast24h)} />
                <Stat label={t('admin.ops.q.oldest')} value={ageText(i18n, s.oldestPendingAgeSeconds)} />
              </dl>
              {s.dead > 0 && <RetryButton i18n={i18n} run={opsApi.retryPushDead} invalidate="push" />}
              <Updated i18n={i18n} at={push.dataUpdatedAt} />
            </>
          )}
        </Panel>
      </Card>
      <Card title={t('admin.ops.q.transcode')}>
        <Panel i18n={i18n} q={tc}>
          {(s) => (
            <>
              <dl className={styles.statGrid}>
                <Stat label={t('admin.ops.q.pending')} value={n(s.pending)} />
                {s.processing !== undefined && (
                  <Stat label={t('admin.ops.q.processing')} value={n(s.processing)} />
                )}
                <Stat label={t('admin.ops.q.failed')} value={n(s.failed)} warn={s.failed > 0} />
                {s.doneLast24h !== undefined && (
                  <Stat label={t('admin.ops.q.done24h')} value={n(s.doneLast24h)} />
                )}
              </dl>
              <Updated i18n={i18n} at={tc.dataUpdatedAt} />
            </>
          )}
        </Panel>
      </Card>
    </div>
  );
}

// ---------- Yedekleme ----------
function BackupTab({ i18n }: { i18n: I18n }) {
  const { t, formatDateTime, formatNumber } = i18n;
  const q = useOpsQuery('backup', opsApi.getBackupStatus);
  return (
    <div className={styles.stack}>
      <Card title={t('admin.ops.tab.backup')}>
        <Panel i18n={i18n} q={q}>
          {(b) => {
            const last = b.lastSuccessAt ? new Date(b.lastSuccessAt).getTime() : null;
            const stale = last === null || Date.now() - last > STALE_BACKUP_MS;
            const level = levelOf(b.status);
            return (
              <>
                {stale && (
                  <Callout tone="warning" role="status">
                    {t(last === null ? 'admin.ops.backup.never' : 'admin.ops.backup.stale')}
                  </Callout>
                )}
                <dl className={styles.statGrid}>
                  <div>
                    <dt className={styles.muted}>{t('admin.ops.backup.status')}</dt>
                    <dd>
                      <StatusPill tone={TONE[level]}>
                        {i18n.td(`admin.ops.backup.${b.status}`, t('admin.ops.backup.UNKNOWN'))}
                      </StatusPill>
                    </dd>
                  </div>
                  <Stat label={t('admin.ops.backup.last')} value={formatDateTime(b.lastSuccessAt)} />
                  <Stat label={t('admin.ops.backup.attempt')} value={formatDateTime(b.lastAttemptAt)} />
                  {typeof b.sizeBytes === 'number' && (
                    <Stat
                      label={t('admin.ops.backup.size')}
                      value={`${formatNumber(Math.round(b.sizeBytes / 1048576))} MB`}
                    />
                  )}
                </dl>
                {b.message && <p className={styles.mono}>{b.message}</p>}
                <Updated i18n={i18n} at={q.dataUpdatedAt} />
              </>
            );
          }}
        </Panel>
      </Card>
    </div>
  );
}

// ---------- Sürüm ve bakım ----------
function ReleaseTab({ i18n }: { i18n: I18n }) {
  const { t } = i18n;
  const q = useOpsQuery('settings', getSettings);
  const dash = (v: string | undefined) => (v && v.trim() ? v : '—');
  return (
    <div className={styles.stack}>
      <Card title={t('admin.ops.tab.release')}>
        <Panel i18n={i18n} q={q}>
          {(s) => {
            const on = (s.maintenance_mode ?? '').toLowerCase() === 'true';
            return (
              <>
                <dl className={styles.statGrid}>
                  <div>
                    <dt className={styles.muted}>{t('admin.ops.release.maintenance')}</dt>
                    <dd>
                      <StatusPill tone={on ? 'warning' : 'success'}>
                        {t(on ? 'admin.ops.release.on' : 'admin.ops.release.off')}
                      </StatusPill>
                    </dd>
                  </div>
                  {(['android', 'ios'] as const).flatMap((p) => [
                    <Stat
                      key={`min-${p}`}
                      label={t('admin.ops.release.min', { platform: p })}
                      value={<span className="ltr">{dash(s[`min_version_${p}`])}</span>}
                    />,
                    <Stat
                      key={`latest-${p}`}
                      label={t('admin.ops.release.latest', { platform: p })}
                      value={<span className="ltr">{dash(s[`latest_version_${p}`])}</span>}
                    />,
                  ])}
                </dl>
                <Link to={paths.admin.settings}>{t('admin.ops.release.edit')}</Link>
                <Updated i18n={i18n} at={q.dataUpdatedAt} />
              </>
            );
          }}
        </Panel>
      </Card>
    </div>
  );
}

// ---------- Dış bağlantılar ----------
const LINK_KEYS = [
  { key: 'ops_sentry_url', label: 'admin.ops.links.sentry' },
  { key: 'ops_grafana_url', label: 'admin.ops.links.grafana' },
] as const;

function LinkRow({ i18n, k, label, saved }: { i18n: I18n; k: string; label: string; saved: string }) {
  const { t } = i18n;
  const qc = useQueryClient();
  const toast = useToast();
  const [edit, setEdit] = useState<string | null>(null);
  const value = edit ?? saved;
  const href = safeHttpsUrl(saved);
  const invalid = value.trim() !== '' && safeHttpsUrl(value) === null;
  const m = useMutation({
    mutationFn: () => putSetting(k, value.trim()),
    onSuccess: () => {
      toast.success(t('admin.ops.links.saved'));
      setEdit(null);
      void qc.invalidateQueries({ queryKey: qk.ops.part('settings') });
    },
    onError: (e) => toast.error(adminErrorMessage(i18n, e)),
  });
  return (
    <li className={styles.item}>
      <FormField label={label} error={invalid ? t('admin.ops.links.invalid') : undefined}>
        <Input
          value={value}
          dir="ltr"
          autoComplete="off"
          placeholder="https://"
          onChange={(e) => setEdit(e.target.value)}
        />
      </FormField>
      <div className={styles.itemHead}>
        <Button
          size="sm"
          loading={m.isPending}
          disabled={invalid || edit === null}
          onClick={() => m.mutate()}
        >
          {t('admin.ops.links.save')}
        </Button>
        {href ? (
          <a href={href} target="_blank" rel="noopener noreferrer">
            {t('admin.ops.links.open')} <Icon name="external" size={14} aria-hidden="true" />
          </a>
        ) : (
          <span className={styles.muted}>{t('admin.ops.links.unset')}</span>
        )}
      </div>
    </li>
  );
}

function LinksTab({ i18n }: { i18n: I18n }) {
  const q = useOpsQuery('settings', getSettings);
  return (
    <div className={styles.stack}>
      <Card title={i18n.t('admin.ops.tab.links')}>
        <p className={styles.muted}>{i18n.t('admin.ops.links.intro')}</p>
        <Panel i18n={i18n} q={q}>
          {(s) => (
            <ul className={styles.rowList}>
              {LINK_KEYS.map((l) => (
                <LinkRow key={l.key} i18n={i18n} k={l.key} label={i18n.t(l.label)} saved={s[l.key] ?? ''} />
              ))}
            </ul>
          )}
        </Panel>
      </Card>
    </div>
  );
}

export default function OpsPage() {
  const i18n = useI18n();
  const { t } = i18n;
  usePageTitle(t('admin.ops.title'));
  const qc = useQueryClient();
  const [tab, setTab] = useState<TabId>('health');
  const tabs = TABS.map((id) => ({ id, label: t(`admin.ops.tab.${id}` as 'admin.ops.tab.health') }));

  return (
    <>
      <PageHeader
        title={t('admin.ops.title')}
        description={t('admin.ops.intro')}
        actions={
          <Button
            variant="secondary"
            size="sm"
            onClick={() => void qc.invalidateQueries({ queryKey: ['ops'] })}
          >
            {t('admin.ops.refresh')}
          </Button>
        }
      />
      <p className={styles.muted} role="status">
        {t('admin.ops.auto')}
      </p>
      <Tabs tabs={tabs} value={tab} onChange={(id) => setTab(id as TabId)} label={t('admin.ops.tabs')}>
        {tab === 'health' && <HealthTab i18n={i18n} />}
        {tab === 'queues' && <QueuesTab i18n={i18n} />}
        {tab === 'backup' && <BackupTab i18n={i18n} />}
        {tab === 'release' && <ReleaseTab i18n={i18n} />}
        {tab === 'links' && <LinksTab i18n={i18n} />}
      </Tabs>
    </>
  );
}
