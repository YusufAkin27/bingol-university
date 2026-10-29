// Kalıcı depolama uyarı bandı: yönetim paneli genelinde (AdminLayout) WARN/CRIT iken görünür; kapatılamaz. 5 dakikada bir
// yenilenir. Yalnız veri saklama okuma izni olan yöneticiler için istek atılır; izin ya da uç yoksa sessizce gizlenir.
import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { getStorage, isStorageAlert, retentionKeys } from '../../../api/dataRetention';
import { Icon } from '../../../components/ui';
import { usePermissions } from '../../../auth/permissions';
import { useI18n } from '../../../i18n/I18nProvider';
import { paths } from '../../../paths';
import styles from './DataRetention.module.css';

export const BANNER_POLL_MS = 5 * 60_000;

export function StorageBanner() {
  const { t, formatNumber } = useI18n();
  const perms = usePermissions();
  const allowed = perms.status === 'ready' && perms.can('data.retention.read');
  const q = useQuery({
    queryKey: retentionKeys.storage,
    queryFn: getStorage,
    enabled: allowed,
    refetchInterval: BANNER_POLL_MS,
    staleTime: 60_000,
    retry: false,
  });
  const r = q.data;
  if (!allowed || !isStorageAlert(r) || !r) return null;
  const crit = r.status === 'CRIT';
  return (
    <div className={styles.banner} data-status={r.status} role={crit ? 'alert' : 'status'} data-testid="storage-banner">
      <Icon name="alert" size={18} />
      <span className={styles.bannerText}>
        {crit
          ? t('admin.ds1.banner.crit', { pct: formatNumber(r.worstPercent ?? 0), crit: r.critPercent })
          : t('admin.ds1.banner.warn', { pct: formatNumber(r.worstPercent ?? 0), warn: r.warnPercent })}{' '}
        {t('admin.ds1.banner.action')}
      </span>
      <Link to={paths.admin.dataRetention} className={styles.bannerLink}>
        {t('admin.ds1.banner.link')}
      </Link>
    </div>
  );
}
