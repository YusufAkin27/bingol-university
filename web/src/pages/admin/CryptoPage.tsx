// SAYFA: Şifreleme durumu ve kullanıcı sohbetlerini açma (/admin/crypto)
// API: GET /api/admin/crypto/status (anahtar kimlikleri, ana anahtar başına DEK sayısı; sır yok) ve kullanıcı arama (GET /api/admin/users?q=).
// Mesajlar kullanıcı bazlı görüntüleyicide açılır (UserMessagesPage); tek tek çözme formu ve uyarı kutusu T24 ile kaldırıldı.
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { Link } from 'react-router-dom';
import { cryptoApi, qk, usersApi } from '../../api';
import { Badge, Card, EmptyState, ErrorState, FormField, Input, Insight, PageHeader, Skeleton, Tabs } from '../../components/ui';
import { SearchAnchor, useSearchReveal } from '../../search/anchor';
import { useUrlTab } from '../../search/useUrlTab';
import { useI18n } from '../../i18n/I18nProvider';
import { useDebouncedValue, usePageTitle } from '../../lib/hooks';
import { paths } from '../../paths';
import type { CryptoStatus } from '../../api/types';
import { adminErrorMessage, Callout } from './campaigns/shared';
import styles from './moderation/moderation.module.css';
import sysStyles from './systemstatus/systemstatus.module.css';

/** Tek cümlelik durum + güncel/eski anahtar oranı (yığılmış çubuk). */
function CryptoSummary({ i18n, data }: { i18n: ReturnType<typeof useI18n>; data: CryptoStatus }) {
  const total = Object.values(data.dekCountsByMasterKey).reduce((s, n) => s + n, 0);
  const current = data.dekCountsByMasterKey[data.activeKeyId] ?? 0;
  const old = total - current;
  const f = i18n.formatNumber;
  const text = data.devKey
    ? i18n.t('admin.v2n.crypto.devKey')
    : old > 0
      ? i18n.t('admin.v2n.crypto.old', { old: f(old), active: data.activeKeyId })
      : i18n.t('admin.v2n.crypto.ok');
  return (
    <>
      <Insight tone={data.devKey ? 'bad' : old > 0 ? 'warn' : 'good'} parts={text} />
      {total > 0 && (
        <>
          <div className={sysStyles.stacked} aria-hidden="true">
            {current > 0 && <span className={sysStyles.stackSeg} data-tone="success" style={{ flexGrow: current }} />}
            {old > 0 && <span className={sysStyles.stackSeg} data-tone="warning" style={{ flexGrow: old }} />}
          </div>
          <p className={styles.muted}>
            {i18n.t('admin.v2n.crypto.split', { current: f(current), old: f(old) })}
          </p>
        </>
      )}
    </>
  );
}

type CryptoTab = 'status' | 'messages';
const CRYPTO_TABS: CryptoTab[] = ['status', 'messages'];

export default function CryptoPage() {
  const i18n = useI18n();
  const { t, formatNumber } = i18n;
  usePageTitle(t('admin.crypto.title'));
  const [q, setQ] = useState('');
  // Güvenlik durumu ile mesaj okuma aracı ayrı sekmelerde (?tab=messages); arama anchor'ı da doğru sekmeyi açar
  const [tab, setTab] = useUrlTab<CryptoTab>(CRYPTO_TABS, 'status');
  useSearchReveal((anchor) => {
    if (anchor === 'crypto-open') setTab('messages');
    else if (anchor === 'crypto-status') setTab('status');
  });
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
      <PageHeader title={t('admin.crypto.title')} description={t('admin.v2n.crypto.intro')} />
      <Tabs
        label={t('admin.v2n.crypto.tabs')}
        value={tab}
        onChange={(id) => setTab(id as CryptoTab)}
        tabs={[
          { id: 'status', label: t('admin.v2n.crypto.tabStatus') },
          { id: 'messages', label: t('admin.v2n.crypto.tabMessages') },
        ]}
      >
      <div className={styles.stack}>
        {tab === 'status' && (
        <SearchAnchor id="tab-status">
        <Card title={t('admin.crypto.status.title')} data-search-anchor="crypto-status">
          {status.isError ? (
            <ErrorState compact description={adminErrorMessage(i18n, status.error)} onRetry={() => void status.refetch()} />
          ) : status.isLoading || !status.data ? (
            <Skeleton height="6rem" width="100%" />
          ) : (
            <>
              <CryptoSummary i18n={i18n} data={status.data} />
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
        </SearchAnchor>
        )}

        {tab === 'messages' && (
        <SearchAnchor id="tab-messages">
        <Card title={t('admin.crypto.open.title')} data-search-anchor="crypto-open">
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
        </SearchAnchor>
        )}
      </div>
      </Tabs>
    </>
  );
}
