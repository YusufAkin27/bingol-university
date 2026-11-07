// Çökme raporlarının görsel özeti: grupların durum dağılımı (yığılmış çubuk) ve sürüm/platform başına çökme sayısı (sıralı çubuk).
// Sürüm dağılımı, en çok çöken ilk 50 grubun sürüm sayılarından türer (sunucu sürüm başına toplam vermez); etiket bunu söyler.
import type { CrashGroup, CrashSummary } from '../../../api/crashes';
import { RankedBars, Skeleton } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { s1 } from './dict';
import { crashStatusShares, crashVersionTotals, queueSegments } from './logic';
import { StackedBar } from './Visuals';
import styles from './sistem1.module.css';

const STATUS_TONE = { NEW: 'danger', ACK: 'warning', RESOLVED: 'success' } as const;

export function CrashOverview({
  summary,
  groups,
  groupsLoading,
}: {
  summary: CrashSummary | undefined;
  groups: CrashGroup[] | undefined;
  groupsLoading: boolean;
}) {
  const i18n = useI18n();
  const t = s1(i18n);
  const segs = queueSegments(crashStatusShares(summary).map((x) => ({ key: x.key, count: x.count, tone: STATUS_TONE[x.key] })));
  const versions = crashVersionTotals(groups);
  const worst = versions[0];
  if (!summary && !groups) return null;
  return (
    <section className={styles.twoCol} aria-label={t('admin.s1.crash.title')} data-testid="crash-overview" data-search-anchor="crash-overview">
      <div className={styles.stack} data-search-anchor="crash-status-split">
        <h2 className={styles.blockTitle}>{t('admin.s1.crash.statusTitle')}</h2>
        {segs.length === 0 ? (
          <p className={styles.note}>{t('admin.s1.crash.noGroups')}</p>
        ) : (
          <StackedBar
            segments={segs}
            label={t('admin.s1.crash.statusAria')}
            legend={(sg) => `${t(`admin.s1.crash.status.${sg.key}`)}: ${i18n.formatNumber(sg.count)}`}
          />
        )}
        <p className={styles.note}>{t('admin.s1.crash.statusNote')}</p>
      </div>
      <div className={styles.stack} data-search-anchor="crash-versions">
        <h2 className={styles.blockTitle}>{t('admin.s1.crash.versionTitle')}</h2>
        {groupsLoading ? (
          <Skeleton height={120} />
        ) : versions.length === 0 ? (
          <p className={styles.note}>{t('admin.s1.crash.noVersions')}</p>
        ) : (
          <>
            <p className={styles.summarySentence}>
              {t('admin.s1.crash.versionSentence', {
                platform: i18n.td(`admin.cr1.platform.${worst.platform}`, worst.platform),
                version: worst.version,
                n: i18n.formatNumber(worst.count),
              })}
            </p>
            <RankedBars
              ariaLabel={t('admin.s1.crash.versionTitle')}
              items={versions.map((v) => ({
                key: v.key,
                label: `${i18n.td(`admin.cr1.platform.${v.platform}`, v.platform)} ${v.version}`,
                value: v.count,
              }))}
              limit={5}
              showShare
              formatValue={(n) => t('admin.s1.crash.times', { n: i18n.formatNumber(n) })}
            />
            <p className={styles.note}>{t('admin.s1.crash.versionNote')}</p>
          </>
        )}
      </div>
    </section>
  );
}
