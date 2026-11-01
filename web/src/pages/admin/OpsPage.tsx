// SAYFA: Operasyon paneli (/admin/ops) — sekmeler: Sağlık, Kuyruklar, Yedekleme, Sürüm ve bakım, Dış bağlantılar.
// API: GET /api/admin/ops/health, GET /api/admin/ops/mail-outbox/stats (+ POST .../retry-dead), GET /api/admin/push/outbox/stats
//      (+ POST .../retry-dead), GET /api/admin/ops/transcode/stats, GET /api/admin/ops/backup-status (api/ops.ts),
//      GET /api/status (kaynak sistem bakımı), GET/PUT /api/admin/settings (sürüm, bakım, ops_sentry_url, ops_grafana_url).
// Henüz olmayan uçlar (404/501) kartta zarifçe "Veri yok" gösterir; docs/API_CONTRACTS_V2.md "İSTEK(web→backend)".
// Sayfa görünürken 30 sn'de bir otomatik yenilenir.
import { useQuery, useQueryClient, type UseQueryResult } from '@tanstack/react-query';
import { useState, type ReactNode } from 'react';
import { SearchAnchor, useSearchReveal } from '../../search/anchor';
import { useUrlTab } from '../../search/useUrlTab';
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
  GuardedAction,
  Icon,
  Input,
  Insight,
  PageHeader,
  ProgressRing,
  Skeleton,
  StatusPill,
  Tabs,
  useToast,
} from '../../components/ui';
import type { Tone } from '../../components/ui/Badge';
import { useI18n, type I18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { paths } from '../../paths';
import { ADMIN_REASON_MIN } from '../../components/admin/guard/match';
import { adminErrorMessage, Callout } from './campaigns/shared';
import { formatMinutes } from './systemstatus/indicators';
import { s1 } from './sistem1/dict';
import { queueSegments, summarizeOps, zoneScale } from './sistem1/logic';
import { OpsSummary } from './sistem1/OpsSummary';
import { StackedBar, ZoneGauge } from './sistem1/Visuals';
import sx from './sistem1/sistem1.module.css';
import styles from './moderation/moderation.module.css';

const POLL_MS = 30_000;
const STALE_BACKUP_MS = 48 * 3600 * 1000;
type TabId = 'health' | 'queues' | 'backup' | 'release' | 'links';
const TABS: TabId[] = ['health', 'queues', 'backup', 'release', 'links'];

/** Arama anchor'ı -> o kartın bulunduğu sekme (kart görünür olsun diye sekme açılır). */
const TAB_OF_ANCHOR: Record<string, TabId> = {
  'ops-components': 'health',
  'ops-sources': 'health',
  'ops-mail-queue': 'queues',
  'ops-push-queue': 'queues',
  'ops-transcode': 'queues',
  'ops-release': 'release',
  'ops-links': 'links',
};

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
/** Bayt sayısını "4,7 GB" gibi okunur yazar. */
function formatBytes(i18n: I18n, n: number): string {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  let v = n;
  let i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i += 1;
  }
  return `${i18n.formatNumber(v, { maximumFractionDigits: i === 0 ? 0 : 1 })} ${units[i]}`;
}

/** Bileşen ayrıntısı: disk için cümle, hata için kısa metin; geri kalan ham anahtarlar "Teknik ayrıntı" altında. */
function ComponentDetails({
  i18n,
  name,
  details,
}: {
  i18n: I18n;
  name: string;
  details: Record<string, string | number | boolean | null> | undefined;
}) {
  if (!details) return null;
  const { total, free, error } = details;
  const sentence: string[] = [];
  let ring: ReactNode = null;
  if (typeof total === 'number' && typeof free === 'number' && total > 0) {
    const usedPct = Math.round(((total - free) / total) * 100);
    ring = (
      <ProgressRing
        value={usedPct}
        label={s1(i18n)('admin.s1.ops.diskRing')}
        center={i18n.t('admin.system.unit.percent', { n: i18n.formatNumber(usedPct) })}
        tone={usedPct >= 90 ? 'danger' : usedPct >= 80 ? 'warning' : 'success'}
        size={80}
        thickness={9}
      />
    );
    sentence.push(
      i18n.t('admin.v2n.ops.disk', {
        free: formatBytes(i18n, free),
        total: formatBytes(i18n, total),
        percent: i18n.formatNumber(usedPct),
      }),
    );
  }
  if (typeof error === 'string' && error) sentence.push(i18n.t('admin.v2n.ops.compError', { error }));
  const raw = Object.entries(details)
    .map(([k, v]) => `${k}=${String(v)}`)
    .join(' · ');
  if (!raw) return null;
  return (
    <>
      {ring}
      {sentence.map((x) => (
        <p key={x}>{x}</p>
      ))}
      <details data-testid={`tech-${name}`}>
        <summary className={styles.muted}>{i18n.t('admin.v2n.ops.techDetail')}</summary>
        <p className={styles.mono}>{raw}</p>
      </details>
    </>
  );
}

function HealthTab({ i18n }: { i18n: I18n }) {
  const { t, formatDateTime } = i18n;
  const health = useOpsQuery('health', opsApi.getHealth);
  const sources = useOpsQuery('sources', getSyncStatus);
  return (
    <div className={styles.stack}>
      <Card title={t('admin.ops.health.components')} data-search-anchor="ops-components">
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
                      <strong>{i18n.td(`admin.v2n.ops.comp.${name}`, name)}</strong>
                      <Level i18n={i18n} status={c.status} />
                    </div>
                    <ComponentDetails i18n={i18n} name={name} details={c.details} />
                  </li>
                ))}
              </ul>
              <Updated i18n={i18n} at={health.dataUpdatedAt} />
            </>
          )}
        </Panel>
      </Card>
      <Card title={t('admin.ops.health.sources')} data-search-anchor="ops-sources">
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
/** Ölü kayıtları yeniden kuyruğa alır: etkilenen sayı gösterilir (eşik üstünde sayıyı yazdırır), çift tıklama tek istek. */
function RetryButton({
  i18n,
  run,
  invalidate,
  count,
}: {
  i18n: I18n;
  run: (o: { idempotencyKey: string }) => Promise<{ requeued: number }>;
  invalidate: string;
  /** Yeniden denenecek ölü kayıt sayısı. */
  count: number;
}) {
  const toast = useToast();
  return (
    <GuardedAction
      variant="secondary"
      size="sm"
      permission="system.write"
      title={i18n.t('admin.p05.ops.retryTitle')}
      message={i18n.t('admin.p05.ops.retryMessage')}
      consequence={i18n.t('admin.p05.ops.retryConsequence')}
      irreversible={false}
      impact={{ count, noun: i18n.t('admin.p05.ops.noun') }}
      confirmLabel={i18n.t('admin.ops.q.retry')}
      invalidateKeys={[qk.ops.part(invalidate)]}
      successMessage={false}
      onConfirm={async ({ idempotencyKey }) => {
        const r = await run({ idempotencyKey });
        toast.success(i18n.t('admin.ops.q.retried', { n: String(r?.requeued ?? 0) }));
      }}
    >
      {i18n.t('admin.ops.q.retry')}
    </GuardedAction>
  );
}

function ageText(i18n: I18n, s: number | null | undefined): string {
  if (s === null || s === undefined) return i18n.t('admin.ops.q.none');
  return s <= 0 ? i18n.t('admin.v2n.sys.noWaiting') : formatMinutes(i18n, Math.max(1, Math.round(s / 60)));
}

/** Sıra özeti: tek cümle (kaç bekliyor, kaç gönderilemedi, son 24 saatte kaç gitti). */
function QueueSentence({
  i18n,
  pending,
  dead,
  sent,
}: {
  i18n: I18n;
  pending: number;
  dead: number;
  sent?: number;
}) {
  const f = i18n.formatNumber;
  const text =
    sent === undefined
      ? i18n.t('admin.v2n.ops.q.summaryNoSent', { pending: f(pending), dead: f(dead) })
      : i18n.t('admin.v2n.ops.q.summary', { pending: f(pending), dead: f(dead), sent: f(sent) });
  return <Insight tone={dead > 0 ? 'warn' : 'good'} parts={text} />;
}

/** Sira durumunu tek yigilmis cubukla gosterir (sifirlar atilir); sayilar "Ayrintili sayilar" altindadir. */
function QueueBar({
  i18n,
  parts,
}: {
  i18n: I18n;
  parts: [string, number | undefined, 'info' | 'neutral' | 'warning' | 'danger'][];
}) {
  const segs = queueSegments(parts.map(([key, count, tone]) => ({ key, count, tone })));
  const t = s1(i18n);
  if (segs.length === 0) return null;
  return (
    <StackedBar
      segments={segs}
      label={t('admin.s1.ops.queueBar')}
      legend={(sg) => `${i18n.td(`admin.ops.q.${sg.key}`, sg.key)}: ${i18n.formatNumber(sg.count)}`}
    />
  );
}

/** Ham sayilar: ust bolumde cumle + cubuk yeterli; ayrinti isteyen acar. */
function Numbers({ i18n, children }: { i18n: I18n; children: ReactNode }) {
  return (
    <details className={sx.numbers}>
      <summary>{s1(i18n)('admin.s1.ops.numbers')}</summary>
      {children}
    </details>
  );
}

function QueuesTab({ i18n }: { i18n: I18n }) {
  const { t, formatNumber: n } = i18n;
  const mail = useOpsQuery('mail', opsApi.getMailStats);
  const push = useOpsQuery('push', opsApi.getPushStats);
  const tc = useOpsQuery('transcode', opsApi.getTranscodeStats);
  return (
    <div className={styles.stack}>
      <Card title={t('admin.ops.q.mail')} data-search-anchor="ops-mail-queue">
        <Panel i18n={i18n} q={mail}>
          {(s) => (
            <>
              <QueueSentence i18n={i18n} pending={s.pending} dead={s.dead} sent={s.sentLast24h} />
              <QueueBar i18n={i18n} parts={[['pending', s.pending, 'info'], ['sending', s.sending, 'neutral'], ['dead', s.dead, 'danger']]} />
              <Numbers i18n={i18n}>
              <dl className={styles.statGrid}>
                <Stat label={t('admin.ops.q.pending')} value={n(s.pending)} />
                {s.sending !== undefined && <Stat label={t('admin.ops.q.sending')} value={n(s.sending)} />}
                <Stat label={t('admin.ops.q.dead')} value={n(s.dead)} warn={s.dead > 0} />
                {s.sentLast24h !== undefined && (
                  <Stat label={t('admin.ops.q.sent24h')} value={n(s.sentLast24h)} />
                )}
                <Stat label={t('admin.ops.q.oldest')} value={ageText(i18n, s.oldestPendingAgeSeconds)} />
              </dl>
              </Numbers>
              {s.dead > 0 && <RetryButton i18n={i18n} run={opsApi.retryMailDead} invalidate="mail" count={s.dead} />}
            </>
          )}
        </Panel>
      </Card>
      <Card title={t('admin.ops.q.push')} data-search-anchor="ops-push-queue">
        <Panel i18n={i18n} q={push}>
          {(s) => (
            <>
              {!s.enabled && (
                <Callout tone="warning" role="status">
                  {t('admin.ops.q.disabled')}
                </Callout>
              )}
              <QueueSentence i18n={i18n} pending={s.pending} dead={s.dead} sent={s.sentLast24h} />
              <QueueBar i18n={i18n} parts={[['pending', s.pending, 'info'], ['sending', s.sending, 'neutral'], ['failed', s.failed, 'warning'], ['dead', s.dead, 'danger']]} />
              <Numbers i18n={i18n}>
              <dl className={styles.statGrid}>
                <Stat label={t('admin.ops.q.pending')} value={n(s.pending)} />
                <Stat label={t('admin.ops.q.sending')} value={n(s.sending)} />
                <Stat label={t('admin.ops.q.failed')} value={n(s.failed)} warn={s.failed > 0} />
                <Stat label={t('admin.ops.q.dead')} value={n(s.dead)} warn={s.dead > 0} />
                <Stat label={t('admin.ops.q.sent24h')} value={n(s.sentLast24h)} />
                <Stat label={t('admin.ops.q.oldest')} value={ageText(i18n, s.oldestPendingAgeSeconds)} />
              </dl>
              </Numbers>
              {s.dead > 0 && <RetryButton i18n={i18n} run={opsApi.retryPushDead} invalidate="push" count={s.dead} />}
            </>
          )}
        </Panel>
      </Card>
      <Card title={t('admin.ops.q.transcode')} data-search-anchor="ops-transcode">
        <Panel i18n={i18n} q={tc}>
          {(s) => (
            <>
              {s.enabled === false && (
                <Callout tone="warning" role="status">
                  {t('admin.p03.ops.transcodeDisabled')}
                </Callout>
              )}
              <QueueBar i18n={i18n} parts={[['pending', s.pending, 'info'], ['processing', s.processing, 'neutral'], ['failed', s.failed, 'danger']]} />
              <Numbers i18n={i18n}>
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
              </Numbers>
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
  const { t, formatDateTime } = i18n;
  const q = useOpsQuery('backup', opsApi.getBackupStatus);
  return (
    <div className={styles.stack}>
      <Card title={t('admin.ops.tab.backup')}>
        <Panel i18n={i18n} q={q}>
          {(b) => {
            const last = b.lastSuccessAt ? new Date(b.lastSuccessAt).getTime() : null;
            const stale = last === null || Date.now() - last > STALE_BACKUP_MS;
            const level = levelOf(b.status);
            const hours = last === null ? null : Math.max(0, (Date.now() - last) / 3_600_000);
            const t1 = s1(i18n);
            return (
              <>
                {hours !== null && (
                  <>
                    <Insight
                      tone={hours > 48 ? 'bad' : hours > 24 ? 'warn' : 'good'}
                      parts={t1('admin.s1.ops.backupAgo', { h: i18n.formatNumber(Math.floor(hours)) })}
                    />
                    <ZoneGauge
                      scale={zoneScale(hours, 24, 48)}
                      level={hours > 48 ? 'CRIT' : hours > 24 ? 'WARN' : 'OK'}
                      label={t1('admin.s1.ops.backupGauge', { h: i18n.formatNumber(Math.floor(hours)) })}
                    />
                  </>
                )}
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
                      value={formatBytes(i18n, b.sizeBytes)}
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
      <Card title={t('admin.ops.tab.release')} data-search-anchor="ops-release">
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
  const [edit, setEdit] = useState<string | null>(null);
  const value = edit ?? saved;
  const href = safeHttpsUrl(saved);
  const invalid = value.trim() !== '' && safeHttpsUrl(value) === null;
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
        {/* W1-B (T-013): her ayar kaydı gerekçe ister. */}
        <GuardedAction
          size="sm"
          permission="settings.write"
          disabled={invalid || edit === null}
          title={label}
          message={value.trim() || t('admin.ops.links.unset')}
          confirmLabel={t('admin.ops.links.save')}
          requireReason
          reasonMinLength={ADMIN_REASON_MIN}
          successMessage={t('admin.ops.links.saved')}
          errorMessage={(e) => adminErrorMessage(i18n, e)}
          invalidateKeys={[qk.ops.part('settings')]}
          onSuccess={() => setEdit(null)}
          onConfirm={({ reason, idempotencyKey }) => putSetting(k, value.trim(), { reason, idempotencyKey })}
        >
          {t('admin.ops.links.save')}
        </GuardedAction>
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
      <Card title={i18n.t('admin.ops.tab.links')} data-search-anchor="ops-links">
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
  const [tab, setTab] = useUrlTab<TabId>(TABS, 'health'); // ?tab=queues: arama derin bağlantısı sekmeyi açar
  useSearchReveal((anchor) => {
    const target = TAB_OF_ANCHOR[anchor];
    if (target) setTab(target);
  });
  // Üst özet: sekmelerle aynı sorgu anahtarlarını paylaşır (ek istek yok; uç yoksa o parça özete girmez)
  const health = useOpsQuery('health', opsApi.getHealth);
  const mailQ = useOpsQuery('mail', opsApi.getMailStats);
  const pushQ = useOpsQuery('push', opsApi.getPushStats);
  const backupQ = useOpsQuery('backup', opsApi.getBackupStatus);
  const summary = summarizeOps({
    healthStatus: health.data?.status ?? null,
    mailDead: mailQ.data?.dead ?? null,
    pushDead: pushQ.data?.dead ?? null,
    backup: backupQ.data ? { status: backupQ.data.status, lastSuccessAt: backupQ.data.lastSuccessAt } : null,
    now: Date.now(),
  });
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
        {t('admin.ops.auto')} · {t('admin.v2n.ops.systemLink')}{' '}
        <Link to={paths.admin.system}>{t('admin.v2n.ops.systemLinkText')}</Link>
      </p>
      {(health.isSuccess || mailQ.isSuccess || pushQ.isSuccess || backupQ.isSuccess) && <OpsSummary i18n={i18n} summary={summary} />}
      <Tabs tabs={tabs} value={tab} onChange={(id) => setTab(id as TabId)} label={t('admin.ops.tabs')}>
        {tab === 'health' && (
          <SearchAnchor id="tab-health">
            <HealthTab i18n={i18n} />
          </SearchAnchor>
        )}
        {tab === 'queues' && (
          <SearchAnchor id="tab-queues">
            <QueuesTab i18n={i18n} />
          </SearchAnchor>
        )}
        {tab === 'backup' && (
          <SearchAnchor id="tab-backup">
            <BackupTab i18n={i18n} />
          </SearchAnchor>
        )}
        {tab === 'release' && (
          <SearchAnchor id="tab-release">
            <ReleaseTab i18n={i18n} />
          </SearchAnchor>
        )}
        {tab === 'links' && (
          <SearchAnchor id="tab-links">
            <LinksTab i18n={i18n} />
          </SearchAnchor>
        )}
      </Tabs>
    </>
  );
}
