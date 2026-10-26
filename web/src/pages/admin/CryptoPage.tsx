// SAYFA: Şifreleme durumu ve kullanıcı sohbetlerini açma (/admin/crypto)
// API: GET /api/admin/crypto/status (anahtar kimlikleri, ana anahtar başına DEK sayısı; sır yok) ve kullanıcı arama (GET /api/admin/users?q=).
// Mesajlar kullanıcı bazlı görüntüleyicide açılır (UserMessagesPage); tek tek çözme formu ve uyarı kutusu T24 ile kaldırıldı.
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { Link } from 'react-router-dom';
import { cryptoApi, qk, usersApi } from '../../api';
import { Badge, Card, EmptyState, ErrorState, FormField, Input, PageHeader, Skeleton } from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { useDebouncedValue, usePageTitle } from '../../lib/hooks';
import { paths } from '../../paths';
import { adminErrorMessage, Callout } from './campaigns/shared';
import styles from './moderation/moderation.module.css';

export default function CryptoPage() {
  const i18n = useI18n();
  const { t, formatNumber } = i18n;
  usePageTitle(t('admin.crypto.title'));
  const [q, setQ] = useState('');
  const term = useDebouncedValue(q.trim(), 300);

  const status = useQuery({ queryKey: qk.crypto.status(), queryFn: cryptoApi.getCryptoStatus });
  const disabled = status.data ? !status.data.adminDecryptEnabled : false;
  const found = useQuery({
    queryKey: qk.users.list({ q: term, size: 8 }),
    queryFn: () => usersApi.listUsers({ q: term, size: 8 }),
    enabled: term.length >= 2,
  });

  return (
    <>
      <PageHeader title={t('admin.crypto.title')} />
      <div className={styles.stack}>
        <Card title={t('admin.crypto.status.title')}>
          {status.isError ? (
            <ErrorState compact description={adminErrorMessage(i18n, status.error)} onRetry={() => void status.refetch()} />
          ) : status.isLoading || !status.data ? (
            <Skeleton height="6rem" width="100%" />
          ) : (
            <>
              <dl className={styles.statGrid}>
                <div>
                  <dt className={styles.muted}>{t('admin.crypto.status.active')}</dt>
                  <dd className="ltr">
                    <code>{status.data.activeKeyId}</code>
                  </dd>
                </div>
                <div>
                  <dt className={styles.muted}>{t('admin.crypto.status.keys')}</dt>
                  <dd className="ltr">{status.data.keyIds.join(', ')}</dd>
                </div>
                <div>
                  <dt className={styles.muted}>{t('admin.crypto.status.decrypt')}</dt>
                  <dd>
                    <Badge tone={status.data.adminDecryptEnabled ? 'success' : 'danger'}>
                      {t(status.data.adminDecryptEnabled ? 'admin.crypto.status.on' : 'admin.crypto.status.off')}
                    </Badge>
                  </dd>
                </div>
              </dl>
              {status.data.devKey && (
                <Callout tone="danger" role="alert" title={t('admin.crypto.status.devKeyTitle')}>
                  {t('admin.crypto.status.devKey')}
                </Callout>
              )}
              <h3 className={styles.muted}>{t('admin.crypto.status.deks')}</h3>
              <ul className={styles.msgList}>
                {Object.entries(status.data.dekCountsByMasterKey).map(([k, n]) => (
                  <li key={k} className={styles.msgMeta}>
                    <code className="ltr">{k}</code>
                    <strong>{formatNumber(n)}</strong>
                    {k !== status.data.activeKeyId && <Badge tone="warning">{t('admin.crypto.status.rewrapNeeded')}</Badge>}
                  </li>
                ))}
              </ul>
            </>
          )}
        </Card>

        <Card title={t('admin.crypto.open.title')}>
          <p className={styles.muted}>{t('admin.crypto.open.hint')}</p>
          {disabled && (
            <Callout tone="warning" role="status">
              {t('admin.crypto.disabled')}
            </Callout>
          )}
          <div className={styles.formGrid}>
            <FormField label={t('admin.crypto.open.search')}>
              <Input
                value={q}
                dir="auto"
                autoComplete="off"
                placeholder={t('admin.crypto.open.placeholder')}
                onChange={(e) => setQ(e.target.value)}
              />
            </FormField>
          </div>
          {term.length >= 2 &&
            (found.isError ? (
              <ErrorState compact description={adminErrorMessage(i18n, found.error)} onRetry={() => void found.refetch()} />
            ) : found.isLoading ? (
              <Skeleton height="4rem" width="100%" />
            ) : found.data && found.data.items.length === 0 ? (
              <EmptyState compact icon="search" title={t('admin.crypto.open.none')} description=" " />
            ) : (
              <ul className={styles.msgList}>
                {found.data?.items.map((u) => (
                  <li key={u.id} className={styles.msgMeta}>
                    <strong dir="auto">{u.displayName}</strong>
                    <span className="ltr">{u.email}</span>
                    {!disabled && <Link to={paths.admin.userMessages(u.id)}>{t('admin.crypto.open.go')}</Link>}
                  </li>
                ))}
              </ul>
            ))}
        </Card>
      </div>
    </>
  );
}
