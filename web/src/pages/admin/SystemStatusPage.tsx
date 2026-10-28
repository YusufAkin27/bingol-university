// SAYFA: Sistem durumu (/admin/system) — kuyruk, zamanlayıcı, altyapı ve yedek göstergeleri + ölü (DEAD) mail/push listesi.
// API: GET /api/admin/system/overview; GET/POST /api/admin/system/dead-letters/{mail|push}[/retry|/delete] (api/system.ts).
// Sayfa görünürken 30 sn'de bir otomatik yenilenir. Durum yalnız renkle değil simge + metinle de gösterilir.
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { qk, systemApi } from '../../api';
import {
  groupOf,
  levelOf,
  toUnit,
  unitOf,
  type DeadKind,
  type SystemGroup,
  type SystemIndicator,
  type SystemLevel,
} from '../../api/system';
import {
  Button,
  Card,
  ConfirmDialog,
  EmptyState,
  ErrorState,
  Icon,
  PageHeader,
  Skeleton,
  Tabs,
  useToast,
} from '../../components/ui';
import type { IconName } from '../../components/ui';
import { useI18n, type I18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { adminErrorMessage, Callout } from './campaigns/shared';
import styles from './SystemStatusPage.module.css';

const POLL_MS = 30_000;
const GROUPS: SystemGroup[] = ['queues', 'infra', 'jobs'];
const ICON: Record<SystemLevel, IconName> = { OK: 'check', WARN: 'alert', CRIT: 'x', UNKNOWN: 'help' };

/** Gösterge değerini birimiyle (dk/sa/%/ms) metne çevirir; nesne değerleri "anahtar: değer" olarak birleştirir. */
function formatValue(i18n: I18n, key: string, ind: SystemIndicator): string {
  const v = ind.value;
  if (v === null || v === undefined) return '—';
  if (typeof v === 'object') {
    return Object.entries(v)
      .map(([k, x]) => `${k}: ${String(x)}`)
      .join(' · ');
  }
  if (typeof v === 'string') return v;
  return formatNumberUnit(i18n, key, v);
}

function formatNumberUnit(i18n: I18n, key: string, n: number): string {
  const unit = unitOf(key);
  const num = toUnit(unit, n);
  const f = i18n.formatNumber(num);
  switch (unit) {
    case 'minutes':
      return i18n.t(key.startsWith('jobs.') ? 'admin.system.unit.minutesAgo' : 'admin.system.unit.minutes', { n: f });
    case 'hours':
      return i18n.t('admin.system.unit.hours', { n: f });
    case 'percent':
      return i18n.t('admin.system.unit.percent', { n: f });
    case 'ms':
      return i18n.t('admin.system.unit.ms', { n: f });
    default:
      return f;
  }
}

function formatThreshold(i18n: I18n, key: string, th: SystemIndicator['threshold']): string | null {
  if (!th || th.warn === undefined) return null;
  const unit = unitOf(key);
  const plain = (n: number) => {
    const f = i18n.formatNumber(toUnit(unit, n));
    if (unit === 'minutes') return i18n.t('admin.system.unit.minutes', { n: f });
    if (unit === 'hours') return i18n.t('admin.system.unit.hours', { n: f });
    if (unit === 'percent') return i18n.t('admin.system.unit.percent', { n: f });
    if (unit === 'ms') return i18n.t('admin.system.unit.ms', { n: f });
    return f;
  };
  if (th.crit === undefined) return i18n.t('admin.system.thresholdWarn', { warn: plain(th.warn) });
  return i18n.t('admin.system.threshold', { warn: plain(th.warn), crit: plain(th.crit) });
}

function Level({ i18n, level }: { i18n: I18n; level: SystemLevel }) {
  return (
    <span className={styles.badge} data-status={level}>
      <Icon name={ICON[level]} size={16} aria-hidden="true" />
      {i18n.t(`admin.system.status.${level}` as 'admin.system.status.OK')}
    </span>
  );
}

function IndicatorCard({ i18n, id, ind }: { i18n: I18n; id: string; ind: SystemIndicator }) {
  const level = levelOf(ind.status);
  const th = formatThreshold(i18n, id, ind.threshold);
  return (
    <article className={styles.card} data-status={level} data-testid={`ind-${id}`}>
      <Level i18n={i18n} level={level} />
      <h3 className={styles.label}>{i18n.td(`admin.system.ind.${id}`, id)}</h3>
      <p className={styles.value}>{formatValue(i18n, id, ind)}</p>
      {th && <p className={styles.muted}>{th}</p>}
      {ind.message && <p className={styles.muted}>{ind.message}</p>}
    </article>
  );
}

// ---------- Ölü kayıtlar ----------
interface DeadRow {
  id: number;
  cells: string[];
  error: string | null;
}

function DeadLetters({ i18n }: { i18n: I18n }) {
  const { t } = i18n;
  const qc = useQueryClient();
  const toast = useToast();
  const [kind, setKind] = useState<DeadKind>('mail');
  const [selected, setSelected] = useState<number[]>([]);
  const [confirm, setConfirm] = useState(false);

  const q = useQuery({
    queryKey: qk.system.dead(kind),
    queryFn: async (): Promise<DeadRow[]> => {
      if (kind === 'mail') {
        const rows = await systemApi.getDeadMail();
        return rows.map((r) => ({
          id: r.id,
          cells: [r.template, r.to, String(r.attempts), r.createdAt ? i18n.formatDateTime(r.createdAt) : '—'],
          error: r.lastError,
        }));
      }
      const rows = await systemApi.getDeadPush();
      return rows.map((r) => ({
        id: r.id,
        cells: [r.userId === null ? '—' : String(r.userId), String(r.attempts), r.createdAt ? i18n.formatDateTime(r.createdAt) : '—'],
        error: r.lastError,
      }));
    },
  });

  const done = () => {
    setSelected([]);
    void qc.invalidateQueries({ queryKey: qk.system.all });
  };
  const retry = useMutation({
    mutationFn: (ids: number[]) => systemApi.retryDead(kind, ids),
    onSuccess: (r) => {
      toast.success(t('admin.system.dead.retried', { n: String(r?.requeued ?? 0) }));
      done();
    },
    onError: (e) => toast.error(adminErrorMessage(i18n, e)),
  });
  const del = useMutation({
    mutationFn: (ids: number[]) => systemApi.deleteDead(kind, ids),
    onSuccess: (r) => {
      toast.success(t('admin.system.dead.deleted', { n: String(r?.deleted ?? 0) }));
      setConfirm(false);
      done();
    },
    onError: (e) => {
      setConfirm(false);
      toast.error(adminErrorMessage(i18n, e));
    },
  });

  const rows = q.data ?? [];
  const allSelected = rows.length > 0 && selected.length === rows.length;
  const toggle = (id: number) =>
    setSelected((s) => (s.includes(id) ? s.filter((x) => x !== id) : [...s, id]));
  const head =
    kind === 'mail'
      ? ['template', 'to', 'attempts', 'created']
      : ['user', 'attempts', 'created'];

  return (
    <Card title={t('admin.system.dead.title')}>
      <Tabs
        tabs={[
          { id: 'mail', label: t('admin.system.dead.mail') },
          { id: 'push', label: t('admin.system.dead.push') },
        ]}
        value={kind}
        onChange={(id) => {
          setKind(id as DeadKind);
          setSelected([]);
        }}
        label={t('admin.system.dead.tabs')}
      >
        {q.isError ? (
          <ErrorState compact description={adminErrorMessage(i18n, q.error)} onRetry={() => void q.refetch()} />
        ) : q.isLoading ? (
          <Skeleton height="4rem" width="100%" />
        ) : rows.length === 0 ? (
          <EmptyState compact icon="check" title={t('admin.system.dead.empty')} />
        ) : (
          <>
            <div className={styles.toolbar}>
              <Button
                variant="secondary"
                size="sm"
                disabled={selected.length === 0}
                loading={retry.isPending}
                onClick={() => retry.mutate(selected)}
              >
                {t('admin.system.dead.retrySelected')}
              </Button>
              <Button variant="secondary" size="sm" loading={retry.isPending} onClick={() => retry.mutate([])}>
                {t('admin.system.dead.retryAll')}
              </Button>
              <Button variant="danger" size="sm" disabled={selected.length === 0} onClick={() => setConfirm(true)}>
                {t('admin.system.dead.deleteSelected')}
              </Button>
            </div>
            <div className={styles.tableWrap}>
              <table className={styles.table}>
                <thead>
                  <tr>
                    <th scope="col">
                      <input
                        type="checkbox"
                        checked={allSelected}
                        aria-label={t('admin.system.dead.selectAll')}
                        onChange={() => setSelected(allSelected ? [] : rows.map((r) => r.id))}
                      />
                    </th>
                    <th scope="col">{t('admin.system.dead.col.id')}</th>
                    {head.map((h) => (
                      <th key={h} scope="col">
                        {i18n.td(`admin.system.dead.col.${h}`, h)}
                      </th>
                    ))}
                    <th scope="col">{t('admin.system.dead.col.error')}</th>
                  </tr>
                </thead>
                <tbody>
                  {rows.map((r) => (
                    <tr key={r.id}>
                      <td>
                        <input
                          type="checkbox"
                          checked={selected.includes(r.id)}
                          aria-label={t('admin.system.dead.selectRow', { id: String(r.id) })}
                          onChange={() => toggle(r.id)}
                        />
                      </td>
                      <td>{r.id}</td>
                      {r.cells.map((c, i) => (
                        <td key={i}>{c}</td>
                      ))}
                      <td className={styles.err}>{r.error ?? '—'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </>
        )}
      </Tabs>
      <ConfirmDialog
        open={confirm}
        onClose={() => setConfirm(false)}
        onConfirm={() => del.mutate(selected)}
        title={t('admin.system.dead.confirmTitle')}
        message={t('admin.system.dead.confirmMessage', { n: String(selected.length) })}
        confirmLabel={t('admin.system.dead.deleteSelected')}
        danger
        loading={del.isPending}
      />
    </Card>
  );
}

export default function SystemStatusPage() {
  const i18n = useI18n();
  const { t } = i18n;
  usePageTitle(t('admin.system.title'));
  const qc = useQueryClient();
  const q = useQuery({
    queryKey: qk.system.overview(),
    queryFn: systemApi.getOverview,
    refetchInterval: () =>
      typeof document === 'undefined' || document.visibilityState === 'visible' ? POLL_MS : false,
  });

  const data = q.data;
  const entries = data ? Object.entries(data.indicators) : [];
  const crit = entries.filter(([, v]) => v.status === 'CRIT').length;

  return (
    <>
      <PageHeader
        title={t('admin.system.title')}
        description={t('admin.system.intro')}
        actions={
          <Button variant="secondary" size="sm" onClick={() => void qc.invalidateQueries({ queryKey: qk.system.all })}>
            {t('admin.system.refresh')}
          </Button>
        }
      />
      <div className={styles.stack}>
        <p className={styles.muted} role="status">
          {t('admin.system.auto')}
          {data ? ` · ${t('admin.system.updated', { time: i18n.formatDateTime(data.generatedAt) })}` : ''}
        </p>
        {q.isError ? (
          <ErrorState description={adminErrorMessage(i18n, q.error)} onRetry={() => void q.refetch()} />
        ) : !data ? (
          <Skeleton height="8rem" width="100%" />
        ) : (
          <>
            <div className={styles.overall}>
              <strong>{t('admin.system.overall')}:</strong>
              <Level i18n={i18n} level={levelOf(data.overall)} />
            </div>
            {crit > 0 && (
              <Callout tone="danger" role="alert">
                {t('admin.system.critBanner', { n: String(crit) })}
              </Callout>
            )}
            {GROUPS.map((g) => {
              const items = entries.filter(([k]) => groupOf(k) === g);
              if (items.length === 0) return null;
              return (
                <section key={g} aria-labelledby={`sys-${g}`}>
                  <h2 id={`sys-${g}`} className={styles.groupTitle}>
                    {t(`admin.system.group.${g}` as 'admin.system.group.queues')}
                  </h2>
                  <div className={styles.grid}>
                    {items.map(([k, v]) => (
                      <IndicatorCard key={k} i18n={i18n} id={k} ind={v} />
                    ))}
                  </div>
                </section>
              );
            })}
          </>
        )}
        <DeadLetters i18n={i18n} />
      </div>
    </>
  );
}
