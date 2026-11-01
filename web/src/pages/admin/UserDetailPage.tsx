// SAYFA: Kullanıcı ayrıntısı (/admin/users/:id)
// API: GET /api/admin/users/{id} (düz AdminUserDetail), PATCH .../role, DELETE .../{id}, POST .../suspend|unsuspend (api/users.ts).
//      İki faktörlü doğrulama kartı: POST .../two-factor/disable (users/UserTwoFactor.tsx).
// KVKK: yalnızca günlük açılış sayıları gösterilir; başka kullanım ayrıntısı yoktur.
// PEOPLE: 20 kartlık tek sütun yerine; üstte durum/risk bandı + hızlı işlem çubuğu, altta 5 sade sekme
// (Özet, Katılım, Destek ve raporlar, Cihazlar ve güvenlik, Yönetim). Sekme ?tab= ile URL'dedir (arama derin bağlantısı).
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { useLocation, useNavigate, useParams } from 'react-router-dom';
import { qk } from '../../api/queryKeys';
import { getUser } from '../../api/users';
import { useAuth } from '../../auth/AuthProvider';
import {
  Avatar,
  Badge,
  ButtonLink,
  Card,
  EmptyState,
  ErrorState,
  Icon,
  Insight,
  PageHeader,
  PermissionButton,
  Skeleton,
  StatusPill,
  Tabs,
  toneFor,
  useKitFormat,
} from '../../components/ui';
import { isApiError } from '../../api/client';
import { useI18n } from '../../i18n/I18nProvider';
import { errorMessage } from '../../lib/errors';
import { usePageTitle } from '../../lib/hooks';
import { paths } from '../../paths';
import { useSearchReveal } from '../../search/anchor';
import { useUrlTab } from '../../search/useUrlTab';
import { QuickSendDialog } from './campaigns/QuickSendDialog';
import { ActivityBars } from './users/ActivityBars';
import { AuditTrail } from '../../components/admin/guard';
import { UserDevices } from './accessbans/UserDevices';
import { UserActions } from './users/UserActions';
import { UserDeepTabs } from './users/UserDeepTabs';
import { UserExtras } from './users/UserExtras';
import { UserTwoFactor } from './users/UserTwoFactor';
import styles from './users/users.module.css';

const TAB_IDS = ['overview', 'activity', 'support', 'security', 'manage'] as const;
type TabId = (typeof TAB_IDS)[number];

/** Arama derin bağlantısı: anchor hangi sekmedeyse o sekme açılır (aynı sekmeyi tekrar atamak etkisizdir). */
const TAB_OF_ANCHOR: Record<string, TabId> = {
  'ud-counts': 'overview',
  'ud-activity': 'overview',
  'ud-account': 'overview',
  'ud-prefs': 'overview',
  'ud-messages-link': 'overview',
  'ud-consents': 'overview',
  'ud-communities': 'activity',
  'ud-events-created': 'activity',
  'ud-events-attending': 'activity',
  'ud-reports-against': 'support',
  'ud-reports-filed': 'support',
  'ud-tickets': 'support',
  'ud-feedback': 'support',
  'ud-devices': 'security',
  'ud-device-log': 'security',
  'ud-actions': 'manage',
  'ud-danger': 'manage',
  'ud-deep': 'manage',
  'ud-audit': 'manage',
};

const SOCIAL_KEYS = ['communities', 'eventsCreated', 'bookmarks', 'conversations'] as const;
const SUPPORT_KEYS = ['feedback', 'tickets'] as const;
const MOD_KEYS = ['reportsAgainst', 'reportsFiled'] as const;

export default function UserDetailPage() {
  const i18n = useI18n();
  const { t, td, formatDate, formatDateTime, formatNumber } = i18n;
  const kit = useKitFormat();
  const { id } = useParams();
  const userId = Number(id);
  const navigate = useNavigate();
  const location = useLocation();
  const { user: me } = useAuth();
  const from = (location.state as { from?: string } | null)?.from ?? paths.admin.users;

  const [notifyOpen, setNotifyOpen] = useState(false);
  const [tab, setTab] = useUrlTab<TabId>(TAB_IDS, 'overview');
  const q = useQuery({
    queryKey: qk.users.detail(userId),
    queryFn: () => getUser(userId),
    enabled: Number.isFinite(userId),
  });
  const u = q.data;
  usePageTitle(u?.displayName ?? t('admin.users.detail.title'));
  useSearchReveal((anchor) => {
    const target = TAB_OF_ANCHOR[anchor];
    if (target) setTab(target);
  });

  const crumbs = [
    { label: t('admin.users.title'), to: from },
    { label: u?.displayName ?? t('admin.users.detail.title') },
  ];

  if (q.isError) {
    // 404: "tekrar dene" anlamsız; kullanıcıya listeye dönme yolu verilir (UDT-10)
    const notFound = isApiError(q.error) && q.error.status === 404;
    return (
      <div>
        <PageHeader title={t('admin.users.detail.title')} breadcrumbs={crumbs} />
        {notFound ? (
          <EmptyState
            icon="users"
            title={t('admin.v2p.ud.notFound')}
            description={t('admin.v2p.ud.notFoundHint')}
            action={<ButtonLink to={from}>{t('admin.users.detail.back')}</ButtonLink>}
          />
        ) : (
          <ErrorState description={errorMessage(i18n, q.error)} onRetry={() => void q.refetch()} />
        )}
      </div>
    );
  }

  if (!u) {
    return (
      <div aria-busy="true">
        <PageHeader title={t('admin.users.detail.title')} breadcrumbs={crumbs} />
        <Card>
          <Skeleton width="40%" height="1.6em" />
          <div style={{ height: 'var(--space-4)' }} />
          <Skeleton width="70%" />
          <div style={{ height: 'var(--space-2)' }} />
          <Skeleton width="55%" />
        </Card>
      </div>
    );
  }

  const suspended = u.status === 'SUSPENDED';
  const deleted = u.status === 'DELETED';
  const openReports = u.counts.reportsAgainst;
  const activeDays = u.recentActivity.filter((d) => d.opens > 0).length;
  const totalOpens = u.recentActivity.reduce((s, d) => s + d.opens, 0);

  // Durum bandı: renk + simge + metin (yalnız renge güvenilmez)
  const band = deleted
    ? { tone: 'neutral', icon: 'x' as const, title: t('admin.v2p.ud.band.deleted'), text: u.deletedAt ? t('admin.v2p.ud.band.deletedAt', { date: formatDateTime(u.deletedAt) }) : t('admin.v2p.ud.band.deletedHint') }
    : suspended
      ? { tone: 'danger', icon: 'alert' as const, title: t('admin.v2p.ud.band.suspended'), text: u.suspendedReason ? `${t('admin.users.detail.suspendedReason')}: ${u.suspendedReason}` : t('admin.v2p.ud.band.suspendedHint') }
      : !u.emailVerified
        ? { tone: 'warning', icon: 'alert' as const, title: t('admin.v2p.ud.band.unverified'), text: t('admin.v2p.ud.band.unverifiedHint') }
        : { tone: 'success', icon: 'check' as const, title: t('admin.v2p.ud.band.ok'), text: t('admin.v2p.ud.band.okHint') };

  const group = (title: string, keys: readonly (keyof typeof u.counts)[], alertKey?: keyof typeof u.counts) => (
    <>
      <h3 className={styles.groupTitle}>{title}</h3>
      <dl className={styles.counts}>
        {keys.map((k) => (
          <div key={k} className={styles.count} data-alert={k === alertKey && u.counts[k] > 0 ? 'true' : undefined}>
            <dt>{td(`admin.users.count.${k}`)}</dt>
            <dd>
              {formatNumber(u.counts[k])}
              {k === alertKey && u.counts[k] > 0 && <span className="sr-only"> {t('admin.v2p.ud.needsAttention')}</span>}
            </dd>
          </div>
        ))}
      </dl>
    </>
  );

  return (
    <div className={styles.pageStack}>
      <PageHeader title={<span dir="auto">{u.displayName}</span>} breadcrumbs={crumbs} />

      {/* 1) Kim bu, durumu ne, dikkat edilecek bir şey var mı */}
      <Card data-search-anchor="ud-profile">
        <div className={styles.hero}>
          <Avatar name={u.displayName} src={u.avatarUrl} size={64} />
          <div className={styles.heroText}>
            <span className={`${styles.muted} ltr ${styles.wrapAnywhere}`}>{u.email}</span>
            <div className={styles.badges}>
              <StatusPill tone={toneFor(u.status)}>{td(`admin.users.status.${u.status}`)}</StatusPill>
              <Badge tone={u.role === 'ADMIN' ? 'primary' : 'neutral'}>{td(`admin.users.role.${u.role}`)}</Badge>
              <Badge tone={u.emailVerified ? 'success' : 'warning'}>
                {u.emailVerified ? t('admin.users.verified.yes') : t('admin.users.verified.no')}
              </Badge>
            </div>
            <span className={styles.muted}>
              {u.lastSeenAt
                ? t('admin.v2p.ud.lastSeen', { when: kit.relative(u.lastSeenAt) })
                : t('admin.v2p.users.neverSeen')}
              {' · '}
              {t('admin.v2p.ud.joined', { when: kit.relative(u.createdAt) })}
            </span>
          </div>
        </div>

        <div className={styles.statusBand} data-tone={band.tone} role="status" style={{ marginBlockStart: 'var(--space-4)' }}>
          <Icon name={band.icon} size={22} aria-hidden="true" />
          <div className={styles.statusText}>
            <strong>{band.title}</strong>
            <span>{band.text}</span>
          </div>
        </div>
        {openReports > 0 && !deleted && (
          <div style={{ marginBlockStart: 'var(--space-3)' }}>
            <Insight
              tone="warn"
              parts={t('admin.v2p.ud.reportsSentence', { n: formatNumber(openReports) })}
            />
          </div>
        )}
      </Card>

      {/* 2) Kritik işlemler hep üstte: sekmeyi açmadan erişilir */}
      <div className={styles.quick}>
        <UserActions variant="quick" user={u} selfId={me?.id} onDeleted={() => navigate(from)}>
          {!deleted && (
            <PermissionButton
              permission="comms.single"
              variant="secondary"
              leftIcon={<Icon name="bell" size={18} />}
              onClick={() => setNotifyOpen(true)}
            >
              {t('admin.users.detail.notifySend')}
            </PermissionButton>
          )}
        </UserActions>
        <p className={styles.hint} style={{ marginBlockEnd: 0, marginBlockStart: 'var(--space-2)' }}>
          {deleted ? t('admin.users.actions.deletedNote') : t('admin.v2p.ud.quickHint')}
        </p>
      </div>
      {notifyOpen && (
        <QuickSendDialog open onClose={() => setNotifyOpen(false)} userId={u.id} userName={u.displayName || u.email} />
      )}

      {/* 3) Sade bölümler */}
      <Tabs
        label={t('admin.v2p.ud.tabs')}
        value={tab}
        onChange={(v) => setTab(v as TabId)}
        tabs={[
          { id: 'overview', label: t('admin.v2p.ud.tab.overview') },
          { id: 'activity', label: t('admin.v2p.ud.tab.activity') },
          { id: 'support', label: t('admin.v2p.ud.tab.support') },
          { id: 'security', label: t('admin.v2p.ud.tab.security') },
          { id: 'manage', label: t('admin.v2p.ud.tab.manage') },
        ]}
      >
        <div className={styles.pageStack}>
          {tab === 'overview' && (
            <>
              <Card title={t('admin.users.detail.profile')}>
                <dl className={styles.facts}>
                  <div>
                    <dt>{t('admin.users.col.faculty')}</dt>
                    <dd>{u.faculty ?? '—'}</dd>
                  </div>
                  <div>
                    <dt>{t('admin.users.col.department')}</dt>
                    <dd>{u.department ?? '—'}</dd>
                  </div>
                  <div>
                    <dt>{t('admin.users.col.classYear')}</dt>
                    <dd>{u.classYear ? formatNumber(u.classYear) : '—'}</dd>
                  </div>
                  <div>
                    <dt>{t('admin.v2p.users.col.language')}</dt>
                    <dd>{u.language ? td(`admin.users.lang.${u.language}`, u.language) : '—'}</dd>
                  </div>
                  <div>
                    <dt>{t('admin.users.col.createdAt')}</dt>
                    <dd>{formatDateTime(u.createdAt)}</dd>
                  </div>
                  <div>
                    <dt>{t('admin.users.col.lastSeenAt')}</dt>
                    <dd>{u.lastSeenAt ? formatDateTime(u.lastSeenAt) : t('admin.v2p.users.neverSeen')}</dd>
                  </div>
                </dl>
                <dl className={styles.facts}>
                  <div>
                    <dt>{t('admin.users.detail.bio')}</dt>
                    <dd>{u.bio || <span className={styles.muted}>{t('admin.users.detail.noBio')}</span>}</dd>
                  </div>
                </dl>
              </Card>

              <Card title={t('admin.users.detail.counts')} data-search-anchor="ud-counts">
                {group(t('admin.v2p.ud.group.social'), SOCIAL_KEYS)}
                {u.follow && (
                  <dl className={styles.counts} data-testid="follow-stats" style={{ marginBlockStart: 'var(--space-3)' }}>
                    <div className={styles.count}>
                      <dt>{t('admin.social.follow.followers')}</dt>
                      <dd>{formatNumber(u.follow.followerCount)}</dd>
                    </div>
                    <div className={styles.count}>
                      <dt>{t('admin.social.follow.following')}</dt>
                      <dd>{formatNumber(u.follow.followingCount)}</dd>
                    </div>
                  </dl>
                )}
                {group(t('admin.v2p.ud.group.support'), SUPPORT_KEYS)}
                {group(t('admin.v2p.ud.group.moderation'), MOD_KEYS, 'reportsAgainst')}
              </Card>

              <Card title={t('admin.users.detail.activity')} data-search-anchor="ud-activity">
                <Insight
                  tone={activeDays === 0 ? 'neutral' : 'info'}
                  parts={
                    u.recentActivity.length === 0
                      ? t('admin.users.detail.noActivity')
                      : t('admin.v2p.ud.activitySentence', {
                          days: formatNumber(activeDays),
                          total: formatNumber(u.recentActivity.length),
                          opens: formatNumber(totalOpens),
                        })
                  }
                />
                <div style={{ marginBlockStart: 'var(--space-3)' }}>
                  <ActivityBars data={u.recentActivity} />
                </div>
              </Card>

              <UserExtras u={u} sections={['account', 'prefs']} />

              <Card title={t('admin.users.detail.consents')} data-search-anchor="ud-consents">
                {u.consents.length === 0 ? (
                  <p className={styles.hint}>{t('admin.users.detail.noConsents')}</p>
                ) : (
                  <ul className={styles.list}>
                    {u.consents.map((c) => (
                      <li key={`${c.type}-${c.version}`}>
                        <span>
                          <Icon name="check" size={16} aria-hidden="true" />{' '}
                          {td(`admin.users.consentType.${c.type}`, c.type)}{' '}
                          <span className={styles.muted}>
                            {t('admin.users.detail.consentVersion', { version: formatNumber(c.version) })}
                          </span>
                        </span>
                        <span className={`${styles.muted} ${styles.nowrap}`}>{formatDate(c.acceptedAt)}</span>
                      </li>
                    ))}
                  </ul>
                )}
              </Card>
            </>
          )}
          <UserTwoFactor user={u} isSelf={me?.id === u.id} />

          {tab === 'activity' && (
            <>
              <p className={styles.hint}>{t('admin.v2p.ud.activityHint')}</p>
              <UserExtras u={u} sections={['community']} />
            </>
          )}

          {tab === 'support' && (
            <>
              <p className={styles.hint}>{t('admin.v2p.ud.supportHint')}</p>
              <UserExtras u={u} sections={['support']} />
            </>
          )}

          {tab === 'security' && (
            <>
              <p className={styles.hint}>{t('admin.v2p.ud.securityHint')}</p>
              <Card title={t('admin.users.detail.devices')} data-search-anchor="ud-devices">
                {u.deviceCount === 0 ? (
                  <p className={styles.hint}>{t('admin.users.detail.noDevices')}</p>
                ) : (
                  <>
                    <p>{t('admin.users.detail.deviceCount', { n: formatNumber(u.deviceCount) })}</p>
                    <div className={styles.devicePlat}>
                      {u.platforms.map((p) => (
                        <Badge key={p} tone="info">
                          {td(`admin.users.platform.${p}`, p)}
                        </Badge>
                      ))}
                    </div>
                  </>
                )}
              </Card>
              <div className={styles.wrapAnywhere}>
                <UserDevices userId={u.id} />
              </div>
              <UserExtras u={u} sections={['devicelog']} />
            </>
          )}

          {tab === 'manage' && (
            <>
              <UserActions user={u} selfId={me?.id} onDeleted={() => navigate(from)} />
              <div data-search-anchor="ud-deep">
                <UserDeepTabs user={u} />
              </div>
              <div className={styles.wrapAnywhere} data-search-anchor="ud-audit">
                <AuditTrail targetType="USER" targetId={u.id} />
              </div>
            </>
          )}
        </div>
      </Tabs>
    </div>
  );
}
