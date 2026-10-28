import { useQuery } from '@tanstack/react-query';
import { api, isApiError } from '../../../api/client';
import { useI18n } from '../../../i18n/I18nProvider';
import { ErrorState, Spinner } from '../../ui/Feedback';
import styles from './guard.module.css';

/** Denetim satırı (P02'de `GET /api/admin/audit?targetType=&targetId=` ile gelir; alanların çoğu isteğe bağlıdır). */
export interface AuditTrailEntry {
  id: number | string;
  adminEmail?: string | null;
  /** Ör. USER_ROLE_CHANGE; yoksa method + path gösterilir. */
  action?: string | null;
  method?: string | null;
  path?: string | null;
  reason?: string | null;
  at: string;
}

export interface AuditTrailProps {
  /** Hedef türü: USER, COMMUNITY, EVENT, SETTING... */
  targetType: string;
  targetId: string | number;
  /** En çok kaç satır (varsayılan 20). */
  size?: number;
  title?: string;
}

/** Sunucu `Page<T>` ya da düz dizi döndürebilir; ikisini de kabul ederiz. */
function toRows(data: unknown): AuditTrailEntry[] {
  if (Array.isArray(data)) return data as AuditTrailEntry[];
  const items = (data as { items?: unknown } | null)?.items;
  return Array.isArray(items) ? (items as AuditTrailEntry[]) : [];
}

/**
 * Bir kaydın denetim geçmişi: kim, ne zaman, ne yaptı, sebep. Uç henüz yoksa (404/501) "henüz yok" gösterir.
 */
export function AuditTrail({ targetType, targetId, size = 20, title }: AuditTrailProps) {
  const { t, formatDateTime } = useI18n();
  const q = useQuery({
    queryKey: ['admin', 'audit-trail', targetType, String(targetId), size],
    queryFn: async () => {
      try {
        return toRows(await api.get('/admin/audit', { targetType, targetId: String(targetId), size }));
      } catch (e) {
        if (isApiError(e) && (e.status === 404 || e.status === 501)) return [];
        throw e;
      }
    },
  });
  const heading = title ?? t('admin.guard.audit.title');
  return (
    <section className={styles.audit} aria-label={heading}>
      <h3 className={styles.auditTitle}>{heading}</h3>
      {q.isPending ? (
        <Spinner size="sm" />
      ) : q.isError ? (
        <ErrorState compact title={t('admin.guard.audit.error')} onRetry={() => void q.refetch()} />
      ) : q.data.length === 0 ? (
        <p className={styles.auditEmpty}>{t('admin.guard.audit.empty')}</p>
      ) : (
        <ol className={styles.auditList}>
          {q.data.map((r) => (
            <li key={r.id} className={styles.auditItem}>
              <p className={styles.auditHead}>
                <strong>{r.adminEmail ?? t('admin.guard.audit.unknownAdmin')}</strong>
                <time dateTime={r.at} className={styles.auditTime}>
                  {formatDateTime(r.at)}
                </time>
              </p>
              <p className={styles.auditAction}>{r.action ?? [r.method, r.path].filter(Boolean).join(' ')}</p>
              {r.reason && <p className={styles.auditReason}>{t('admin.guard.audit.reason', { reason: r.reason })}</p>}
            </li>
          ))}
        </ol>
      )}
    </section>
  );
}
