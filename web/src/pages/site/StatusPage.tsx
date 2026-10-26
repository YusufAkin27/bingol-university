// SAYFA: Güncel durum (/status)
// API: GET /api/status ({NEWS:{maintenance,lastSuccessAt,lastAttemptAt,message}, MENU:{…}}), GET /api/app/info (maintenance, banner).
import { useQuery } from '@tanstack/react-query';
import { useAppInfo } from '../../api/hooks';
import { getSourceStatus, type SourceStatus } from '../../api/publicContent';
import { Badge, Button, EmptyState, ErrorState, Icon, Skeleton } from '../../components/ui';
import type { TranslationKey } from '../../i18n';
import { useI18n } from '../../i18n/I18nProvider';
import { errorMessage } from '../../lib/errors';
import { paths } from '../../paths';
import { PageHero } from './components/PageHero';
import { usePageMeta } from './components/usePageMeta';
import shared from './components/site.module.css';
import styles from './StatusPage.module.css';

const SOURCES = ['NEWS', 'MENU'] as const;

export default function StatusPage() {
  const i18n = useI18n();
  const { t, formatDateTime } = i18n;
  const status = useQuery({ queryKey: ['public', 'status'], queryFn: getSourceStatus, refetchInterval: 60_000 });
  const info = useAppInfo();
  const title = t('pg.status.title');
  usePageMeta({ title, description: t('pg.status.meta'), path: paths.site.status });

  const appMaint = info.data?.maintenance.enabled ?? false;
  const rows = SOURCES.filter((s) => status.data?.[s]).map((s) => [s, status.data![s]] as [string, SourceStatus]);
  const anyMaint = appMaint || rows.some(([, v]) => v.maintenance);

  return (
    <>
      <PageHero title={title} lead={t('pg.status.lead')} crumbs={[{ label: title }]} />
      <section className={`${shared.section} ${shared.sectionTop}`}>
        <div className={`container ${styles.wrap}`}>
          {status.isLoading && (
            <div role="status" aria-label={t('common.loading')} className={styles.cards}>
              <Skeleton height="5rem" />
              <Skeleton height="5rem" />
            </div>
          )}
          {status.isError && (
            <ErrorState
              title={t('pg.status.error')}
              description={errorMessage(i18n, status.error)}
              onRetry={() => void status.refetch()}
            />
          )}
          {status.isSuccess && rows.length === 0 && (
            <EmptyState icon="info" title={t('pg.status.empty')} description={t('pg.status.emptyHint')} />
          )}
          {status.isSuccess && rows.length > 0 && (
            <>
              <p
                className={`${styles.summary} ${anyMaint ? styles.warn : styles.ok}`}
                role="status"
              >
                <Icon name={anyMaint ? 'alert' : 'check'} size={20} />
                {anyMaint ? t('pg.status.someMaint') : t('pg.status.allOk')}
              </p>
              <ul className={styles.cards}>
                {rows.map(([key, s]) => (
                  <li key={key} className={styles.card}>
                    <div className={styles.head}>
                      <h2 className={shared.h3}>{t(`pg.status.src.${key}` as TranslationKey)}</h2>
                      <Badge tone={s.maintenance ? 'warning' : 'success'}>
                        {s.maintenance ? t('pg.status.maint') : t('pg.status.ok')}
                      </Badge>
                    </div>
                    <p className={shared.muted}>
                      {s.lastSuccessAt
                        ? t('pg.status.lastOk', { date: formatDateTime(s.lastSuccessAt) })
                        : t('pg.status.never')}
                    </p>
                    {s.lastAttemptAt && (
                      <p className={shared.muted}>{t('pg.status.lastTry', { date: formatDateTime(s.lastAttemptAt) })}</p>
                    )}
                    {s.maintenance && s.message && <p>{s.message}</p>}
                  </li>
                ))}
              </ul>
            </>
          )}

          {info.isSuccess && (
            <p className={`${styles.summary} ${appMaint ? styles.warn : styles.ok}`} role="status">
              <Icon name={appMaint ? 'alert' : 'check'} size={20} />
              {appMaint
                ? `${t('pg.status.appMaint')}${info.data.maintenance.message ? `: ${info.data.maintenance.message}` : ''}`
                : t('pg.status.appOk')}
            </p>
          )}
          <p className={shared.muted}>{t('pg.status.note')}</p>
          <div>
            <Button
              variant="secondary"
              size="sm"
              onClick={() => {
                void status.refetch();
                void info.refetch();
              }}
            >
              {t('pg.status.refresh')}
            </Button>
          </div>
        </div>
      </section>
    </>
  );
}
