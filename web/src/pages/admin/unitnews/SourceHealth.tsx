import { Badge, Insight } from '../../../components/ui';
import type { UnitSource } from '../../../api/adminUnitNews';
import { useI18n } from '../../../i18n/I18nProvider';
import { gt } from './dict';
import styles from './unitNews.module.css';

/** Kaynak sağlığı özeti; yalnız bu sayfada, ana "Sistem durumu"na dokunmaz. Kaynak listesinden türetilir. */
export function summarizeSources(sources: UnitSource[]) {
  const enabled = sources.filter((s) => s.enabled);
  const maintenance = enabled.filter((s) => s.maintenance).length;
  const neverSynced = enabled.filter((s) => !s.lastSuccessAt).length;
  const healthy = enabled.filter((s) => !s.maintenance && s.lastSuccessAt).length;
  const disabled = sources.length - enabled.length;
  const times = enabled
    .map((s) => s.lastSuccessAt)
    .filter((x): x is string => !!x)
    .sort();
  return { healthy, maintenance, neverSynced, disabled, total: sources.length, oldest: times[0] ?? null };
}

export function SourceHealth({ sources }: { sources: UnitSource[] }) {
  const i18n = useI18n();
  const t = gt(i18n);
  const { formatDateTime } = i18n;
  const s = summarizeSources(sources);
  const allGood = s.maintenance === 0 && s.neverSynced === 0;
  return (
    <section className={styles.healthBox} aria-label={t('admin.unitNews.health.title')} data-testid="unit-news-health" data-search-anchor="unitnews-health">
      <Insight
        tone={allGood ? 'good' : s.maintenance > 0 ? 'bad' : 'warn'}
        parts={
          allGood
            ? t('admin.unitNews.health.allGood')
            : s.oldest
              ? t('admin.unitNews.health.oldest', { date: formatDateTime(s.oldest) })
              : t('admin.unitNews.health.neverSyncedSentence')
        }
      />
      <div className={styles.health}>
        <Badge tone={allGood ? 'success' : 'neutral'}>
          {t('admin.unitNews.health.healthy', { n: s.healthy, total: s.total })}
        </Badge>
        {s.maintenance > 0 && (
          <Badge tone="danger">{t('admin.unitNews.health.maintenance', { n: s.maintenance })}</Badge>
        )}
        {s.neverSynced > 0 && (
          <Badge tone="warning">{t('admin.unitNews.health.neverSynced', { n: s.neverSynced })}</Badge>
        )}
        {s.disabled > 0 && <Badge>{t('admin.unitNews.health.disabled', { n: s.disabled })}</Badge>}
      </div>
    </section>
  );
}
