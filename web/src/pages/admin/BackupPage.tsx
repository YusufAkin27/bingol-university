// SAYFA: Yedekleme (Google Drive) (/admin/backup)  [GD1]
// API: GET /api/admin/system/backup (api/backup.ts; izin: system.read). Uç henüz yoksa (404/501) sayfa hata vermez,
// kurulum rehberini gösterir. Sayfa hiçbir sır toplamaz: yalnız durum okur ve talimat verir.
import { useQuery } from '@tanstack/react-query';
import { backupKeys, getBackupStatus } from '../../api/backup';
import { Button, ErrorState, Insight, PageHeader, Skeleton } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { usePageTitle } from '../../lib/hooks';
import { adminErrorMessage, Callout } from './campaigns/shared';
import { gt } from './backup/dict';
import { driveState, freshness, isEndpointMissing } from './backup/lib';
import { SetupGuide } from './backup/SetupGuide';
import { agoText, StatusCards } from './backup/StatusCards';
import styles from './backup/backup.module.css';

const POLL_MS = 60_000;

export default function BackupPage() {
  const i18n = useI18n();
  const t = gt(i18n);
  usePageTitle(t('admin.gd1.title'));

  const q = useQuery({
    queryKey: backupKeys.status,
    queryFn: getBackupStatus,
    refetchInterval: POLL_MS,
    retry: (n, e) => !isEndpointMissing(e) && n < 1,
  });

  const missing = q.isError && isEndpointMissing(q.error);
  const failed = q.isError && !missing;
  const status = q.data ?? null;
  const drive = driveState(status);
  const fresh = freshness(status, Date.now());
  const sentence =
    status && drive !== 'NOT_CONFIGURED' && drive !== 'UNAVAILABLE' && fresh !== 'NONE'
      ? {
          tone: fresh === 'FRESH' && drive === 'OK' ? ('good' as const) : fresh === 'STALE' && drive !== 'ERROR' ? ('warn' as const) : ('bad' as const),
          text: t(
            fresh === 'FRESH' && drive === 'OK' ? 'admin.gd1.sentence.good' : drive === 'ERROR' ? 'admin.gd1.sentence.driveError' : 'admin.gd1.sentence.late',
            { ago: agoText(i18n, status.lastSuccessAt, Date.now()) },
          ),
        }
      : null;

  const goGuide = () => document.getElementById('gd-guide')?.scrollIntoView({ behavior: 'smooth', block: 'start' });

  return (
    <>
      <PageHeader
        title={t('admin.gd1.title')}
        description={t('admin.gd1.desc')}
        actions={
          <Button variant="secondary" data-search-anchor="backup-refresh" onClick={() => void q.refetch()} loading={q.isFetching}>
            {t('admin.gd1.refresh')}
          </Button>
        }
      />
      <div className={styles.page}>
        <section className={styles.section} aria-labelledby="gd-status-h">
          <h2 id="gd-status-h" className={styles.h2}>
            {t('admin.gd1.status.heading')}
          </h2>
          {drive === 'NOT_CONFIGURED' && (
            <Callout tone="warning" role="status" title={t('admin.gd1.warn.localOnly.title')}>
              <p className={styles.line}>{t('admin.gd1.warn.localOnly')}</p>
              <div className={styles.actions}>
                <Button variant="secondary" size="sm" onClick={goGuide}>
                  {t('admin.gd1.warn.localOnly.go')}
                </Button>
              </div>
            </Callout>
          )}
          {q.isLoading ? (
            <Skeleton height={140} />
          ) : failed ? (
            <ErrorState
              compact
              title={t('admin.gd1.status.error')}
              description={adminErrorMessage(i18n, q.error)}
              onRetry={() => void q.refetch()}
            />
          ) : missing ? (
            <Callout tone="info" role="status">
              {t('admin.gd1.status.unavailable')}
            </Callout>
          ) : (
            <>
              {sentence && <Insight tone={sentence.tone} parts={sentence.text} />}
              <div data-search-anchor="backup-status">
                <StatusCards i18n={i18n} status={status} now={Date.now()} />
              </div>
            </>
          )}
        </section>
        <SetupGuide i18n={i18n} connected={drive === 'OK'} />
      </div>
    </>
  );
}
