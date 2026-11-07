// Ayarlar: "Son değişiklikler" kartı. Denetim kaydından (hedef türü SETTING) en yeni 5 ayar işlemini gösterir: kim, ne zaman, hangi ayar, sebep.
// Yalnız `audit.read` izni olana sorulur; hata/yetki yoksa kart hiç görünmez (sayfanın ana işini bozmaz).
import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { listAudit } from '../../../api/audit';
import { useCan } from '../../../auth/permissions';
import { Card } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { paths } from '../../../paths';
import { clip, describeAction } from '../audit/auditLogic';
import { useGt } from '../sys2Dict';
import styles from './recentChanges.module.css';

const QUERY = { page: 0, size: 5, targetType: 'SETTING' } as const;

export function RecentChanges() {
  const { t, td, formatDateTime } = useI18n();
  const gt = useGt();
  const allowed = useCan('audit.read');
  const q = useQuery({
    queryKey: ['audit', 'settings-recent'],
    queryFn: () => listAudit({ ...QUERY }),
    enabled: allowed,
    staleTime: 30_000,
    retry: false,
  });
  const items = (q.data?.items ?? []).filter((r) => r.method !== 'GET');
  if (!allowed || q.isError || (q.data && items.length === 0)) return null;
  return (
    <Card
      title={gt('admin.sys2.settings.recent.title')}
      data-search-anchor="settings-recent"
      actions={
        <Link to={`${paths.admin.audit}?targetType=SETTING`}>{gt('admin.sys2.settings.recent.all')}</Link>
      }
    >
      {q.isLoading ? (
        <p className={styles.muted}>{t('common.loading')}</p>
      ) : (
        <ol className={styles.list}>
          {items.map((r) => {
            const a = describeAction(td, r.method, r.path);
            const key = r.targetId ?? '';
            return (
              <li key={r.id} className={styles.item}>
                <span className={styles.what}>
                  {key ? td(`admin.settings.key.${key}`, key) : a.label}
                  {r.status >= 400 && <span className={styles.failed}> ({gt('admin.sys2.settings.recent.failed')})</span>}
                </span>
                <span className={styles.meta}>
                  {r.adminEmail ?? t('admin.audit.noAdmin')} · {formatDateTime(r.at)}
                </span>
                {r.reason && (
                  <span className={styles.reason} dir="auto">
                    {gt('admin.sys2.settings.recent.reason', { text: clip(r.reason, 120) })}
                  </span>
                )}
              </li>
            );
          })}
        </ol>
      )}
    </Card>
  );
}
