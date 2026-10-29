// FCM durumu sekmesi: GET /api/admin/push/fcm/status, POST .../fcm/validate (kuru çalıştırma; hiçbir cihaza gitmez).
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { getFcmStatus, pushOpsKeys, validateFcm, type FcmCheck } from '../../../api/adminPushOps';
import { isApiError } from '../../../api/client';
import { Card, ErrorState, GuardedAction, Skeleton, StatusPill } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminError } from '../../../lib/errors';
import { Callout } from '../campaigns/shared';
import { codeKey } from './lib';
import styles from './pushops.module.css';

export function FcmTab() {
  const i18n = useI18n();
  const { t, td } = i18n;
  const [last, setLast] = useState<{ at: Date; check: FcmCheck } | null>(null);
  const q = useQuery({ queryKey: pushOpsKeys.fcm(), queryFn: getFcmStatus });
  const s = q.data;

  const errorLabel = (code: string | null) => {
    if (!code) return null;
    const k = codeKey(code);
    return k ? `${td(k, code)} (${code})` : code;
  };

  return (
    <div className={styles.stack}>
      <Card title={t('admin.p14.fcm.title')}>
        {q.isError ? (
          <ErrorState onRetry={() => void q.refetch()} description={adminError(i18n, q.error, 'admin.p14.err')} />
        ) : !s ? (
          <Skeleton width="100%" height="5em" />
        ) : (
          <dl className={styles.kv}>
            <dt>{t('admin.p14.fcm.state')}</dt>
            <dd>
              <StatusPill tone={s.enabled ? 'success' : 'warning'}>
                {s.enabled ? t('admin.p14.fcm.enabled') : t('admin.p14.fcm.disabled')}
              </StatusPill>
            </dd>
            <dt>{t('admin.p14.fcm.project')}</dt>
            <dd className="ltr">{s.projectId ?? '—'}</dd>
            {s.error && (
              <>
                <dt>{t('admin.p14.fcm.error')}</dt>
                <dd className="ltr">{s.error}</dd>
              </>
            )}
          </dl>
        )}
        {s && !s.enabled && (
          <Callout tone="warning" title={t('admin.p14.fcm.off.title')}>
            {t('admin.p14.fcm.off.body')}
          </Callout>
        )}
      </Card>

      <Card title={t('admin.p14.fcm.validate.card')}>
        <p className={styles.hint}>{t('admin.p14.fcm.validate.desc')}</p>
        <div className={styles.row}>
          <GuardedAction
            variant="secondary"
            disabled={!s?.enabled}
            irreversible={false}
            title={t('admin.p14.fcm.validate.title')}
            message={t('admin.p14.fcm.validate.message')}
            consequence={t('admin.p14.fcm.validate.consequence')}
            confirmLabel={t('admin.p14.fcm.validate.confirm')}
            successMessage={false}
            errorMessage={(e) =>
              isApiError(e) && e.status === 429 ? t('admin.p14.fcm.validate.rate') : adminError(i18n, e, 'admin.p14.err')
            }
            onConfirm={async () => {
              const check = await validateFcm();
              setLast({ at: new Date(), check });
            }}
          >
            {t('admin.p14.fcm.validate.button')}
          </GuardedAction>
          <span className={styles.hint}>{t('admin.p14.fcm.validate.limit')}</span>
        </div>
        {last && (
          <div role="status" aria-live="polite">
            {last.check.validated ? (
              <Callout tone="success" title={t('admin.p14.fcm.validate.ok')}>
                {t('admin.p14.fcm.validate.at', { time: i18n.formatDateTime(last.at.toISOString()) })}
              </Callout>
            ) : (
              <Callout tone="danger" role="alert" title={t('admin.p14.fcm.validate.fail')}>
                <span className="ltr">{errorLabel(last.check.error) ?? '—'}</span>
                {last.check.detail && (
                  <div className="ltr">
                    {t('admin.p14.fcm.validate.detail')}: {last.check.detail}
                  </div>
                )}
              </Callout>
            )}
          </div>
        )}
      </Card>

      <Card title={t('admin.p14.fcm.ios.title')}>
        <Callout tone="info">
          {t('admin.p14.fcm.ios.body')}
          <ul className={styles.list}>
            <li>{t('admin.p14.fcm.ios.plist')}</li>
            <li>{t('admin.p14.fcm.ios.apns')}</li>
            <li>{t('admin.p14.fcm.ios.android')}</li>
          </ul>
        </Callout>
      </Card>
    </div>
  );
}
