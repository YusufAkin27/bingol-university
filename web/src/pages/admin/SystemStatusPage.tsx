// SAYFA: Sistem durumu (/admin/system) — "Her şey yolunda mı?" kahramanı + gruplu, katlanır gösterge bölümleri + gönderilemeyen kayıtlar.
// API: GET /api/admin/system/overview; GET/POST /api/admin/system/dead-letters/{mail|push}[/retry|/delete] (api/system.ts).
// Sayfa görünürken 30 sn'de bir otomatik yenilenir. Durum yalnız renkle değil simge + metinle de gösterilir.
// Üstte yalnız İyi/Dikkat/Acil trafik ışığı + tek cümle + dört ana gösterge + sağlık çizelgesi + görev şeridi (sistem1);
// ham gösterge listesi "Teknik ayrıntılar" katlanır bölümündedir (sorun varsa açık gelir).
// Sorunlu göstergeler her grubun başında dolgun kart, normal olanlar tek satır; sorunlu grup açık, tamamen normal grup kapalı gelir.
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { qk, systemApi } from '../../api';
import { groupOf, levelOf, type SystemGroup, type SystemIndicator } from '../../api/system';
import { Button, ErrorState, Icon, PageHeader, Skeleton } from '../../components/ui';
import { useI18n, type I18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { adminErrorMessage } from './campaigns/shared';
import { DeadLetters } from './systemstatus/DeadLetters';
import { CompactRow, IndicatorCard, LEVEL_ICON } from './systemstatus/IndicatorViews';
import { LEVEL_ORDER, isRing } from './systemstatus/indicators';
import { countsText, StatusHero } from './systemstatus/StatusHero';
import { s1 } from './sistem1/dict';
import { HealthTimeline, JobLanes, KeyGauges, useHealthHistory } from './sistem1/SystemPanels';
import sx from './sistem1/sistem1.module.css';
import styles from './systemstatus/systemstatus.module.css';

const POLL_MS = 30_000;
const GROUPS: SystemGroup[] = ['queues', 'infra', 'jobs'];

type Entry = [string, SystemIndicator];

function GroupSection({
  i18n,
  group,
  items,
  open,
  onToggle,
}: {
  i18n: I18n;
  group: SystemGroup;
  items: Entry[];
  open: boolean;
  onToggle: (next: boolean) => void;
}) {
  const sorted = [...items].sort((a, b) => LEVEL_ORDER[levelOf(a[1].status)] - LEVEL_ORDER[levelOf(b[1].status)]);
  // Dolgun kart: sorunlu/bilinmeyen olanlar ve halka gösterilen yüzdeler; geri kalan normaller tek satır.
  const full = sorted.filter(([k, v]) => levelOf(v.status) !== 'OK' || isRing(k, v));
  const compact = sorted.filter(([k, v]) => levelOf(v.status) === 'OK' && !isRing(k, v));
  const bad = sorted.filter(([, v]) => levelOf(v.status) === 'CRIT' || levelOf(v.status) === 'WARN').length;
  const level = sorted.some(([, v]) => levelOf(v.status) === 'CRIT')
    ? 'CRIT'
    : bad > 0
      ? 'WARN'
      : sorted.some(([, v]) => levelOf(v.status) === 'UNKNOWN')
        ? 'UNKNOWN'
        : 'OK';
  return (
    <details
      className={styles.group}
      data-status={level}
      open={open}
      onToggle={(e) => onToggle((e.currentTarget as HTMLDetailsElement).open)}
      data-search-anchor={`group-${group}`}
    >
      <summary className={styles.groupSummary}>
        <span className={styles.groupIcon} data-status={level} aria-hidden="true">
          <Icon name={LEVEL_ICON[level]} size={16} />
        </span>
        <span className={styles.groupHead}>
          <span className={styles.groupTitle}>{i18n.t(`admin.v2n.sys.group.${group}` as 'admin.v2n.sys.group.queues')}</span>
          <span className={styles.groupSub}>
            {bad > 0
              ? i18n.t('admin.v2n.sys.group.mixed', { n: String(sorted.length), bad: String(bad) })
              : i18n.t('admin.v2n.sys.group.allOk', { n: String(sorted.length) })}
          </span>
        </span>
        <Icon className={styles.chevron} name="chevronDown" size={18} aria-hidden="true" />
      </summary>
      <p className={styles.groupAbout}>{i18n.t(`admin.v2n.sys.group.${group}.about` as 'admin.v2n.sys.group.queues.about')}</p>
      {full.length > 0 && (
        <div className={styles.grid}>
          {full.map(([k, v]) => (
            <IndicatorCard key={k} i18n={i18n} id={k} ind={v} />
          ))}
        </div>
      )}
      {compact.length > 0 && (
        <ul className={styles.rows} aria-label={i18n.t('admin.v2n.sys.group.okList')}>
          {compact.map(([k, v]) => (
            <CompactRow key={k} i18n={i18n} id={k} ind={v} />
          ))}
        </ul>
      )}
    </details>
  );
}

function SystemSkeleton() {
  return (
    <div className={styles.stack} aria-busy="true">
      <Skeleton height="9rem" width="100%" />
      <Skeleton height="4rem" width="100%" />
      <Skeleton height="4rem" width="100%" />
      <Skeleton height="4rem" width="100%" />
    </div>
  );
}

export default function SystemStatusPage() {
  const i18n = useI18n();
  const { t } = i18n;
  usePageTitle(t('admin.system.title'));
  const qc = useQueryClient();
  /** Kullanıcının elle açıp kapattığı gruplar; dokunmadıysa sorunlu grup açık, normal grup kapalı. */
  const [chosen, setChosen] = useState<Partial<Record<SystemGroup, boolean>>>({});
  const q = useQuery({
    queryKey: qk.system.overview(),
    queryFn: systemApi.getOverview,
    refetchInterval: () =>
      typeof document === 'undefined' || document.visibilityState === 'visible' ? POLL_MS : false,
  });

  const data = q.data;
  const entries: Entry[] = data ? Object.entries(data.indicators) : [];
  const history = useHealthHistory(q.dataUpdatedAt, data ? levelOf(data.overall) : null);
  const t1 = s1(i18n);
  const anyProblem = entries.some(([, v]) => levelOf(v.status) !== 'OK');

  return (
    <>
      <PageHeader
        title={t('admin.system.title')}
        description={t('admin.v2n.sys.intro')}
        actions={
          <Button
            variant="secondary"
            size="sm"
            data-search-anchor="refresh"
            onClick={() => void qc.invalidateQueries({ queryKey: qk.system.all })}
          >
            {t('admin.system.refresh')}
          </Button>
        }
      />
      <div className={styles.page}>
        <p className={styles.muted} role="status">
          {t('admin.system.auto')}
          {data ? ` · ${t('admin.system.updated', { time: i18n.formatDateTime(data.generatedAt) })}` : ''}
        </p>
        {q.isError ? (
          <ErrorState
            title={t('admin.v2n.sys.errorTitle')}
            description={adminErrorMessage(i18n, q.error)}
            onRetry={() => void q.refetch()}
          />
        ) : !data ? (
          <SystemSkeleton />
        ) : (
          <>
            <StatusHero i18n={i18n} overall={levelOf(data.overall)} entries={entries} />
            <KeyGauges i18n={i18n} entries={entries} />
            <HealthTimeline i18n={i18n} history={history} />
            <JobLanes i18n={i18n} entries={entries} />
            <details className={sx.tech} open={anyProblem || undefined} data-search-anchor="technical-details">
              <summary className={sx.techSummary}>
                <Icon name="chevronDown" size={16} aria-hidden="true" />
                {t1('admin.s1.tech.title', { n: String(entries.length) })}
              </summary>
              <div className={sx.techBody}>
                <p className={styles.muted}>{t1('admin.s1.tech.hint')}</p>
                <p className={styles.muted}>{countsText(i18n, entries)}</p>
                {GROUPS.map((g) => {
                  const items = entries.filter(([k]) => groupOf(k) === g);
                  if (items.length === 0) return null;
                  const hasProblem = items.some(([, v]) => levelOf(v.status) !== 'OK');
                  return (
                    <GroupSection
                      key={g}
                      i18n={i18n}
                      group={g}
                      items={items}
                      open={chosen[g] ?? hasProblem}
                      onToggle={(next) => setChosen((c) => (c[g] === next ? c : { ...c, [g]: next }))}
                    />
                  );
                })}
              </div>
            </details>
          </>
        )}
        {!q.isError && <DeadLetters i18n={i18n} />}
      </div>
    </>
  );
}
