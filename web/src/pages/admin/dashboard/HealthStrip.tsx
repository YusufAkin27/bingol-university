// Genel bakış: "Şu an her şey yolunda mı?" şeridi. Sistem göstergeleri (system.read izni varsa) + haber/yemek kaynakları tek cümlede.
// API: GET /api/admin/system/overview (yalnız system.read), GET /api/status (SourcesPanel ile aynı önbellek anahtarı: tek istek).
// Sorun yoksa yeşil onay cümlesi; varsa en kötü seviye başlıkta, en çok 4 sorun rozeti ilgili sayfaya bağlanır.
import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { qk } from '../../../api/queryKeys';
import { getSyncStatus } from '../../../api/settings';
import { getOverview as getSystemOverview } from '../../../api/system';
import { usePermissions } from '../../../auth/permissions';
import { Icon, Skeleton } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { paths } from '../../../paths';
import { nameOf } from '../systemstatus/indicators';
import { summarizeHealth } from './health';
import styles from './dashboard.module.css';

const MAX_CHIPS = 4;

export function HealthStrip() {
  const i18n = useI18n();
  const { t, td, formatNumber } = i18n;
  const perms = usePermissions();
  const canSystem = perms.can('system.read');
  const system = useQuery({
    queryKey: qk.system.overview(),
    queryFn: getSystemOverview,
    enabled: canSystem,
    staleTime: 30_000,
    refetchInterval: 60_000,
    retry: false,
  });
  const sources = useQuery({ queryKey: qk.settings.sync(), queryFn: getSyncStatus, refetchInterval: 60_000 });

  const waiting = (canSystem && system.isLoading) || sources.isLoading;
  if (waiting) {
    return (
      <section className={styles.health} aria-busy="true" aria-label={t('admin.genel.health.title')} data-search-anchor="dash-health">
        <Skeleton height="3.5rem" width="100%" />
      </section>
    );
  }

  const summary = summarizeHealth(system.data, sources.data);
  const { tone, issues } = summary;
  const systemFailed = canSystem && system.isError;
  const sourcesFailed = sources.isError;
  const scope = summary.systemKnown ? t('admin.genel.health.scopeAll') : t('admin.genel.health.scopeSources');

  const headline =
    tone === 'good'
      ? sourcesFailed
        ? t('admin.genel.health.sourcesUnknown')
        : t('admin.genel.health.good', { scope })
      : tone === 'bad'
        ? t('admin.genel.health.bad', { n: formatNumber(issues.length) })
        : t('admin.genel.health.warn', { n: formatNumber(issues.length) });

  const shown = issues.slice(0, MAX_CHIPS);
  const hidden = issues.length - shown.length;
  const label = (id: string): string => {
    if (id.startsWith('source:')) {
      const name = id.slice('source:'.length);
      return t('admin.genel.health.sourceMaintenance', { name: td(`admin.dashboard.sources.${name}`, name) });
    }
    return nameOf(i18n, id);
  };

  return (
    <section
      className={`${styles.health} ${tone === 'good' ? styles.healthGood : tone === 'warn' ? styles.healthWarn : styles.healthBad}`}
      aria-label={t('admin.genel.health.title')}
      data-search-anchor="dash-health"
      data-tone={tone}
      data-testid="health-strip"
    >
      <div className={styles.healthHead}>
        <Icon name={tone === 'good' ? 'check' : 'alert'} size={22} aria-hidden="true" className={styles.healthIcon} />
        <div className={styles.healthText}>
          <h2 className={styles.healthTitle}>{t('admin.genel.health.title')}</h2>
          <p className={styles.healthSentence}>{headline}</p>
        </div>
        {canSystem && (
          <Link to={paths.admin.system} className={styles.healthLink}>
            {t('admin.genel.health.openSystem')}
          </Link>
        )}
      </div>
      {shown.length > 0 && (
        <ul className={styles.healthChips} aria-label={t('admin.genel.health.issues')}>
          {shown.map((i) => (
            <li key={i.id}>
              <Link to={i.kind === 'source' ? paths.admin.sources : paths.admin.system} className={styles.healthChip}>
                <strong>{t(`admin.genel.health.level.${i.level}`)}</strong>
                <span>{label(i.id)}</span>
              </Link>
            </li>
          ))}
          {hidden > 0 && <li className={styles.healthMore}>{t('admin.genel.health.more', { n: formatNumber(hidden) })}</li>}
        </ul>
      )}
      {systemFailed && <p className={styles.healthNote}>{t('admin.genel.health.systemUnknown')}</p>}
    </section>
  );
}
