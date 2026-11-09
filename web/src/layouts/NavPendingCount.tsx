import { useQuery } from '@tanstack/react-query';
import { listCommunities } from '../api/approvals';
import { useCan } from '../auth/permissions';
import { useI18n } from '../i18n/I18nProvider';
import styles from './AdminLayout.module.css';

/** Menüde onay bekleyen kulüp sayısı (kulüp kurma yönetici onayı ister). Sıfırsa ya da yetki yoksa çizilmez. */
export function NavPendingCount() {
  const { t, formatNumber } = useI18n();
  const allowed = useCan('content.read');
  const q = useQuery({
    // 'communities' ön ekini paylaşır: onay/red sonrası qk.communities.all ile yenilenir
    queryKey: ['communities', 'pendingCount'],
    queryFn: () => listCommunities({ status: 'PENDING_REVIEW', size: 50 }),
    enabled: allowed,
    refetchInterval: 60_000,
    staleTime: 30_000,
  });
  const n = q.data?.items.length ?? 0;
  if (!allowed || n === 0) return null;
  const label = `${formatNumber(n)}${q.data?.nextCursor ? '+' : ''}`;
  return (
    <span className={styles.navCount} aria-label={t('admin.nav.pendingCount', { n: label })} title={t('admin.nav.pendingCount', { n: label })}>
      {label}
    </span>
  );
}
