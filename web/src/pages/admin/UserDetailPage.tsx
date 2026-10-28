// SAYFA: Kullanıcı ayrıntısı (/admin/users/:id)
// API: GET /api/admin/users/{id} (düz AdminUserDetail), PATCH .../role, DELETE .../{id}, POST .../suspend|unsuspend (api/users.ts).
// KVKK: yalnızca günlük açılış sayıları gösterilir; başka kullanım ayrıntısı yoktur.
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { useLocation, useNavigate, useParams } from 'react-router-dom';
import { qk } from '../../api/queryKeys';
import { getUser } from '../../api/users';
import { useAuth } from '../../auth/AuthProvider';
import {
  Avatar,
  Badge,
  Button,
  Card,
  ErrorState,
  PageHeader,
  Skeleton,
  StatusPill,
  toneFor,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { errorMessage } from '../../lib/errors';
import { usePageTitle } from '../../lib/hooks';
import { paths } from '../../paths';
import { QuickSendDialog } from './campaigns/QuickSendDialog';
import { ActivityBars } from './users/ActivityBars';
import { AuditTrail } from '../../components/admin/guard';
import { UserDevices } from './accessbans/UserDevices';
import { UserActions } from './users/UserActions';
import { UserDeepTabs } from './users/UserDeepTabs';
import { UserExtras } from './users/UserExtras';
import styles from './users/users.module.css';

const COUNT_KEYS = [
  'feedback',
  'tickets',
  'reportsAgainst',
  'reportsFiled',
  'conversations',
  'communities',
  'eventsCreated',
  'bookmarks',
] as const;

export default function UserDetailPage() {
  const i18n = useI18n();
  const { t, td, formatDate, formatDateTime, formatNumber } = i18n;
  const { id } = useParams();
  const userId = Number(id);
  const navigate = useNavigate();
  const location = useLocation();
  const { user: me } = useAuth();
  const from = (location.state as { from?: string } | null)?.from ?? paths.admin.users;

  const [notifyOpen, setNotifyOpen] = useState(false);
  const q = useQuery({
    queryKey: qk.users.detail(userId),
    queryFn: () => getUser(userId),
    enabled: Number.isFinite(userId),
  });
  const u = q.data;
  usePageTitle(u?.displayName ?? t('admin.users.detail.title'));

  const crumbs = [
    { label: t('admin.users.title'), to: from },
    { label: u?.displayName ?? t('admin.users.detail.title') },
  ];

  if (q.isError) {
    return (
      <div>
        <PageHeader title={t('admin.users.detail.title')} breadcrumbs={crumbs} />
        <ErrorState description={errorMessage(i18n, q.error)} onRetry={() => void q.refetch()} />
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

  return (
    <div>
      <PageHeader title={u.displayName} breadcrumbs={crumbs} />
      <div className={styles.detail}>
        <div className={styles.stack}>
          <Card title={t('admin.users.detail.profile')}>
            <div className={styles.hero}>
              <Avatar name={u.displayName} src={u.avatarUrl} size={64} />
              <div className={styles.heroText}>
                <span className={`${styles.muted} ltr`}>{u.email}</span>
                <div className={styles.badges}>
                  <StatusPill tone={toneFor(u.status)}>{td(`admin.users.status.${u.status}`)}</StatusPill>
                  <Badge tone={u.role === 'ADMIN' ? 'primary' : 'neutral'}>
                    {td(`admin.users.role.${u.role}`)}
                  </Badge>
                  <Badge tone={u.emailVerified ? 'success' : 'warning'}>
                    {u.emailVerified ? t('admin.users.verified.yes') : t('admin.users.verified.no')}
                  </Badge>
                </div>
              </div>
            </div>
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
                <dt>{t('admin.users.filter.language')}</dt>
                <dd>{u.language ? td(`admin.users.lang.${u.language}`, u.language) : '—'}</dd>
              </div>
              <div>
                <dt>{t('admin.users.col.createdAt')}</dt>
                <dd>{formatDateTime(u.createdAt)}</dd>
              </div>
              <div>
                <dt>{t('admin.users.col.lastSeenAt')}</dt>
                <dd>{u.lastSeenAt ? formatDateTime(u.lastSeenAt) : t('admin.users.never')}</dd>
              </div>
              {u.deletedAt && (
                <div>
                  <dt>{t('admin.users.detail.deletedAt')}</dt>
                  <dd>{formatDateTime(u.deletedAt)}</dd>
                </div>
              )}
            </dl>
            <dl className={styles.facts}>
              <div>
                <dt>{t('admin.users.detail.bio')}</dt>
                <dd>{u.bio || <span className={styles.muted}>{t('admin.users.detail.noBio')}</span>}</dd>
              </div>
            </dl>
            {u.status === 'SUSPENDED' && u.suspendedReason && (
              <p className={styles.notice} role="status">
                <strong>{t('admin.users.detail.suspendedReason')}:</strong> {u.suspendedReason}
              </p>
            )}
          </Card>

          <Card title={t('admin.users.detail.counts')}>
            <dl className={styles.counts}>
              {COUNT_KEYS.map((k) => (
                <div key={k} className={styles.count}>
                  <dt>{td(`admin.users.count.${k}`)}</dt>
                  <dd>{formatNumber(u.counts[k])}</dd>
                </div>
              ))}
            </dl>
            {u.follow && (
              <dl className={styles.counts} data-testid="follow-stats">
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
          </Card>

          <UserExtras u={u} />

          <UserDeepTabs user={u} />

          <Card title={t('admin.users.detail.activity')}>
            <ActivityBars data={u.recentActivity} />
          </Card>
        </div>

        <div className={styles.stack}>
          <UserActions user={u} selfId={me?.id} onDeleted={() => navigate(from)} />

          <Card title={t('admin.users.detail.notify')}>
            <p className={styles.hint}>{t('admin.users.detail.notifyHint')}</p>
            <div style={{ marginBlockStart: 'var(--space-3)' }}>
              <Button variant="secondary" disabled={u.status === 'DELETED'} onClick={() => setNotifyOpen(true)}>
                {t('admin.users.detail.notifySend')}
              </Button>
            </div>
          </Card>
          {notifyOpen && (
            <QuickSendDialog open onClose={() => setNotifyOpen(false)} userId={u.id} userName={u.displayName || u.email} />
          )}

          <Card title={t('admin.users.detail.devices')}>
            {u.deviceCount === 0 ? (
              <p className={styles.hint}>{t('admin.users.detail.noDevices')}</p>
            ) : (
              <>
                <p>{t('admin.users.detail.deviceCount', { n: formatNumber(u.deviceCount) })}</p>
                <div className={styles.badges} style={{ marginBlockStart: 'var(--space-2)' }}>
                  {u.platforms.map((p) => (
                    <Badge key={p} tone="info">
                      {td(`admin.users.platform.${p}`, p)}
                    </Badge>
                  ))}
                </div>
              </>
            )}
          </Card>

          <UserDevices userId={u.id} />

          <AuditTrail targetType="USER" targetId={u.id} />

          <Card title={t('admin.users.detail.consents')}>
            {u.consents.length === 0 ? (
              <p className={styles.hint}>{t('admin.users.detail.noConsents')}</p>
            ) : (
              <ul className={styles.list}>
                {u.consents.map((c) => (
                  <li key={`${c.type}-${c.version}`}>
                    <span>
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
        </div>
      </div>
    </div>
  );
}
