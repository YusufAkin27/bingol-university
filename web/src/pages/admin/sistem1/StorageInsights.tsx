// Veri saklama sayfasının görsel özeti: depolama doluluk halkası + tek cümle + en büyük tablolar, ve büyüme tahmini.
// Sunucu geçmiş ölçüm tutmadığı için büyüme, tablo boyutu / en eski kayıttan beri geçen gün ile TAHMİN edilir ve öyle etiketlenir.
import { useQuery } from '@tanstack/react-query';
import {
  getRetentionTables,
  getStorage,
  retentionKeys,
  type StorageReport,
} from '../../../api/dataRetention';
import { levelOf } from '../../../api/system';
import { Card, ErrorState, Insight, ProgressRing, RankedBars, Skeleton, type RingTone } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { formatBytes, levelOfPercent } from '../dataretention/format';
import { s1 } from './dict';
import { daysUntilFull, fullestDisk, growthRows } from './logic';
import styles from './sistem1.module.css';

const RING: Record<string, RingTone> = { OK: 'success', WARN: 'warning', CRIT: 'danger', UNKNOWN: 'neutral' };

/** Halka + cümle + en büyük tablolar (çubuk). Ayrıntılı kartlar sayfada katlanır bölümdedir. */
export function StorageOverview({ report }: { report: StorageReport }) {
  const i18n = useI18n();
  const t = s1(i18n);
  const worst = fullestDisk(report);
  const pct = report.worstPercent ?? worst?.percent ?? null;
  const level = pct === null ? 'UNKNOWN' : levelOfPercent(pct, report.warnPercent, report.critPercent);
  const top = report.database.topTables.slice(0, 5);
  const sentence =
    pct === null
      ? t('admin.s1.storage.unknown')
      : level === 'OK'
        ? t('admin.s1.storage.ok', { pct: i18n.formatNumber(Math.round(pct)), warn: String(report.warnPercent) })
        : t('admin.s1.storage.bad', { pct: i18n.formatNumber(Math.round(pct)), warn: String(report.warnPercent), crit: String(report.critPercent) });
  return (
    <div className={styles.twoCol} data-testid="storage-overview">
      <div className={styles.stack}>
        <div className={styles.ringRow}>
          <ProgressRing
            value={pct}
            label={t('admin.s1.storage.ring')}
            center={pct === null ? '—' : i18n.t('admin.system.unit.percent', { n: i18n.formatNumber(Math.round(pct)) })}
            tone={RING[levelOf(level)]}
            size={120}
            thickness={12}
          />
          <Insight tone={level === 'OK' ? 'good' : level === 'WARN' ? 'warn' : level === 'CRIT' ? 'bad' : 'neutral'} parts={sentence} />
        </div>
      </div>
      <div className={styles.stack} data-search-anchor="biggest-tables">
        <h3 className={styles.blockTitle}>{t('admin.s1.storage.top')}</h3>
        <RankedBars
          ariaLabel={t('admin.s1.storage.top')}
          items={top.map((x) => ({ key: x.name, label: x.name, value: x.totalBytes }))}
          limit={5}
          showShare
          formatValue={(n) => formatBytes(n)}
          emptyLabel={t('admin.s1.storage.topEmpty')}
        />
      </div>
    </div>
  );
}

/** Tablo büyüme tahmini: günde ortalama büyüme çubukları + "kaç gün yer var" cümlesi. */
export function GrowthPanel() {
  const i18n = useI18n();
  const t = s1(i18n);
  const tables = useQuery({ queryKey: retentionKeys.tables, queryFn: getRetentionTables, staleTime: 30_000 });
  const storage = useQuery({ queryKey: retentionKeys.storage, queryFn: getStorage, staleTime: 30_000 });
  const now = Date.now();
  const rows = growthRows(tables.data, now, 6);
  const totalPerDay = rows.reduce((s, r) => s + r.perDay, 0);
  const free = storage.data?.dbServerDisk.freeBytes ?? null;
  const days = daysUntilFull(free, totalPerDay);
  const top = rows[0];

  let body;
  if (tables.isError) {
    body = <ErrorState compact subject={t('admin.s1.growth.subject')} error={tables.error} onRetry={() => void tables.refetch()} />;
  } else if (tables.isLoading) {
    body = <Skeleton height={160} />;
  } else if (rows.length === 0) {
    body = <p className={styles.note}>{t('admin.s1.growth.none')}</p>;
  } else {
    const sentence = top
      ? days !== null
        ? t('admin.s1.growth.withDays', { name: top.label, perDay: formatBytes(top.perDay), days: i18n.formatNumber(days) })
        : t('admin.s1.growth.noDays', { name: top.label, perDay: formatBytes(top.perDay) })
      : '';
    body = (
      <div className={styles.stack}>
        <Insight tone={days !== null && days < 30 ? 'warn' : 'info'} parts={sentence} />
        <RankedBars
          ariaLabel={t('admin.s1.growth.aria')}
          items={rows.map((r) => ({ key: r.name, label: r.label, value: r.perDay, hint: r.name }))}
          limit={6}
          showShare
          formatValue={(n) => t('admin.s1.growth.perDay', { size: formatBytes(n) })}
        />
        <p className={styles.note}>{t('admin.s1.growth.note')}</p>
      </div>
    );
  }
  return (
    <Card title={t('admin.s1.growth.title')} data-search-anchor="growth">
      {body}
    </Card>
  );
}
