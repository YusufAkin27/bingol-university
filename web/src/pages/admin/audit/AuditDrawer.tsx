// Denetim kaydı ayrıntı çekmecesi: tüm alanlar, hedef bağlantısı, istek kimliği kopyalama.
import { Link } from 'react-router-dom';
import type { AuditRowV2 } from '../../../api/audit';
import { Badge, CopyButton, Drawer, StatusPill } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { auditForTargetHref, describeAction, targetHref } from './auditLogic';
import { isDenied, statusTone } from './status';
import styles from './audit.module.css';

export function AuditDrawer({ row, onClose }: { row: AuditRowV2 | null; onClose: () => void }) {
  const { t, td, formatDateTime } = useI18n();
  if (!row) return null;
  const action = describeAction(td, row.method, row.path);
  const href = targetHref(row.targetType, row.targetId);
  const none = <span className={styles.muted}>{t('admin.wp02.audit.drawer.none')}</span>;
  return (
    <Drawer open onClose={onClose} size="md" title={t('admin.wp02.audit.drawer.title', { id: row.id })}>
      <dl className={styles.detail} data-testid="audit-drawer">
        <div>
          <dt>{t('admin.wp02.audit.drawer.when')}</dt>
          <dd>{formatDateTime(row.at)}</dd>
        </div>
        <div>
          <dt>{t('admin.wp02.audit.drawer.admin')}</dt>
          <dd>
            {row.adminEmail ? <span className="ltr">{row.adminEmail}</span> : none}
            {row.adminId === null && row.adminEmail === 'basic-admin' && (
              <>
                {' '}
                <Badge tone="warning">{t('admin.wp02.audit.basicAdmin')}</Badge>
              </>
            )}
          </dd>
        </div>
        <div>
          <dt>{t('admin.wp02.audit.drawer.action')}</dt>
          <dd>{action.label}</dd>
        </div>
        <div>
          <dt>{t('admin.wp02.audit.drawer.request')}</dt>
          <dd>
            <span className={`${styles.method} ltr`}>{row.method}</span>{' '}
            <span className={`${styles.pathWrap} ltr`}>{row.path}</span>
          </dd>
        </div>
        <div>
          <dt>{t('admin.wp02.audit.drawer.status')}</dt>
          <dd>
            <StatusPill tone={isDenied(row.status) ? 'danger' : statusTone(row.status)}>
              <span className="ltr">{row.status}</span>
            </StatusPill>
          </dd>
        </div>
        <div>
          <dt>{t('admin.wp02.audit.drawer.target')}</dt>
          <dd>
            {row.targetType ? (
              <>
                <Badge tone="primary">{row.targetType}</Badge>{' '}
                {row.targetId && <span className="ltr">#{row.targetId}</span>}
                <div className={styles.links}>
                  {href && <Link to={href}>{t('admin.wp02.audit.drawer.openTarget')}</Link>}
                  {row.targetId && (
                    <Link to={auditForTargetHref(row.targetType, row.targetId)} onClick={onClose}>
                      {t('admin.wp02.audit.drawer.sameTarget')}
                    </Link>
                  )}
                </div>
              </>
            ) : (
              none
            )}
          </dd>
        </div>
        <div>
          <dt>{t('admin.wp02.audit.drawer.reason')}</dt>
          <dd dir="auto" className={styles.longText}>
            {row.reason || none}
          </dd>
        </div>
        <div>
          <dt>{t('admin.wp02.audit.drawer.summary')}</dt>
          <dd dir="auto" className={styles.longText}>
            {row.summary || none}
          </dd>
        </div>
        <div>
          <dt>{t('admin.wp02.audit.drawer.ip')}</dt>
          <dd className="ltr">{row.ip ?? none}</dd>
        </div>
        <div>
          <dt>{t('admin.wp02.audit.drawer.requestId')}</dt>
          <dd>
            {row.requestId ? (
              <>
                <code className={`${styles.code} ltr`}>{row.requestId}</code>
                <CopyButton value={row.requestId} label={t('admin.wp02.audit.copyRequest')} />
                <p className={styles.muted}>{t('admin.wp02.audit.drawer.requestIdHint')}</p>
              </>
            ) : (
              none
            )}
          </dd>
        </div>
      </dl>
      {!row.targetType && !row.reason && !row.summary && !row.requestId && (
        <p className={styles.muted}>{t('admin.wp02.audit.legacyRow')}</p>
      )}
    </Drawer>
  );
}
