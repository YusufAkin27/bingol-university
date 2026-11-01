// Mesaj erişim kayıtları görselleri: kim bakmış, nasıl bakılmış, sebep yazılmış mı. Veri: sayfada listelenen kayıtlar (ek istek yok).
import { useMemo } from 'react';
import type { MessageAccessRow } from '../../../api/audit';
import { RankedBars } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { useGt } from './dict';
import { StackedShare } from './StackedShare';
import styles from './mod2.module.css';

/** Kayıtları anahtara göre sayar; büyükten küçüğe. */
export function countBy<T>(rows: T[], key: (r: T) => string): { key: string; value: number }[] {
  const m = new Map<string, number>();
  for (const r of rows) m.set(key(r), (m.get(key(r)) ?? 0) + 1);
  return [...m].map(([k, value]) => ({ key: k, value })).sort((a, b) => b.value - a.value);
}

export function AccessCharts({ rows }: { rows: MessageAccessRow[] }) {
  const t = useGt();
  const { td } = useI18n();
  const byAdmin = useMemo(
    () => countBy(rows, (r) => r.adminEmail ?? '').map((x) => ({ ...x, label: x.key || t('admin.mod2.access.unknownAdmin') })),
    [rows, t],
  );
  const byKind = useMemo(
    () => countBy(rows, (r) => r.kind).map((x) => ({ ...x, label: td(`admin.wp02.access.kind.${x.key}`, x.key) })),
    [rows, td],
  );
  const withReason = rows.filter((r) => !!r.reason).length;
  if (rows.length === 0) return null;
  return (
    <section className={styles.chartGrid} aria-label={t('admin.mod2.access.chartsLabel')} data-search-anchor="access-charts">
      <div className={styles.chartCard} data-search-anchor="access-by-admin">
        <h2 className={styles.chartTitle}>{t('admin.mod2.access.byAdminTitle')}</h2>
        <p className={styles.chartHint}>{t('admin.mod2.access.hint')}</p>
        <RankedBars items={byAdmin} limit={5} truncateAt={30} ariaLabel={t('admin.mod2.access.byAdminTitle')} />
      </div>
      <div className={styles.chartCard} data-search-anchor="access-by-kind">
        <h2 className={styles.chartTitle}>{t('admin.mod2.access.byKindTitle')}</h2>
        <RankedBars items={byKind} limit={5} ariaLabel={t('admin.mod2.access.byKindTitle')} />
      </div>
      <div className={styles.chartCard} data-search-anchor="access-reason-chart">
        <h2 className={styles.chartTitle}>{t('admin.mod2.access.reasonTitle')}</h2>
        <StackedShare
          ariaLabel={t('admin.mod2.access.reasonTitle')}
          segments={[
            { key: 'with', label: t('admin.mod2.access.withReason'), value: withReason, tone: 'success' },
            { key: 'without', label: t('admin.mod2.access.noReason'), value: rows.length - withReason, tone: 'danger' },
          ]}
        />
      </div>
    </section>
  );
}
