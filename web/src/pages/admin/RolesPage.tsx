// SAYFA: Roller ve izinler (/admin/roles)  [P16]
// API: GET /api/admin/rbac/me|matrix|admins|changes, PUT /api/admin/rbac/users/{id}/profile, POST /api/admin/rbac/changes[/{id}/approve|reject]
// (api/rbac.ts). Matris salt okunurdur ve backend PermissionMatrix'te kod olarak tanımlıdır. Profil atama yalnız `rbac.manage`
// (FULL) içindir; FULL'i düşürme / birini FULL yapma İKİ KİŞİ ONAYI ister (öneri → ikinci FULL yönetici onaylar, 24 saat).
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import {
  ADMIN_PROFILES,
  approveProfileChange,
  getRbacAdmins,
  getRbacChanges,
  getRbacMatrix,
  needsTwoPerson,
  proposeProfileChange,
  rbacKeys,
  rejectProfileChange,
  setAdminProfile,
  type AdminProfile,
  type ChangeStatus,
  type ProfileChange,
  type RbacAdminRow,
} from '../../api/rbac';
import { usePermissions } from '../../auth/permissions';
import {
  Badge,
  Card,
  EmptyState,
  ErrorState,
  GuardedAction,
  PageHeader,
  Select,
  Skeleton,
  StatusPill,
  Table,
  type Column,
  type Tone,
} from '../../components/ui';
import { useI18n } from '../../i18n/I18nProvider';
import { adminError } from '../../lib/errors';
import { usePageTitle } from '../../lib/hooks';
import styles from './roles.module.css';

const STATUS_TONE: Record<ChangeStatus, Tone> = {
  PENDING: 'warning',
  APPROVED: 'success',
  REJECTED: 'danger',
  EXPIRED: 'neutral',
};

export default function RolesPage() {
  const i18n = useI18n();
  const { t, formatDateTime } = i18n;
  usePageTitle(t('admin.p16.roles.title'));
  const perms = usePermissions();
  const canManage = perms.can('rbac.manage');
  const profileName = (p: AdminProfile) => t(`admin.p16.profile.${p}`);

  const matrix = useQuery({ queryKey: rbacKeys.matrix, queryFn: getRbacMatrix, staleTime: Infinity });
  // Yönetici listesi ve değişiklikler yalnız rbac.manage sahibine sorulur (diğerleri 403 alırdı)
  const admins = useQuery({
    queryKey: rbacKeys.admins,
    queryFn: getRbacAdmins,
    enabled: canManage && perms.status === 'ready',
  });
  const changes = useQuery({
    queryKey: rbacKeys.changes(),
    queryFn: () => getRbacChanges(),
    enabled: canManage && perms.status === 'ready',
  });
  const me = perms.me;
  const myId = me?.userId ?? null;
  const err = (e: unknown) => adminError(i18n, e, 'admin.p16.err');

  // --- Ben kartı ---
  const meCard = (
    <Card title={t('admin.p16.me.title')} data-testid="roles-me">
      {!me ? (
        perms.status === 'loading' ? (
          <Skeleton height="4rem" width="100%" />
        ) : (
          <p className={styles.muted}>{t('admin.p16.me.loadError')}</p>
        )
      ) : (
        <div className={styles.me}>
          <div className={styles.head}>
            <strong>{me.displayName ?? me.email ?? '—'}</strong>
            <StatusPill tone={me.profile === 'FULL' ? 'primary' : 'info'}>{profileName(me.profile)}</StatusPill>
            <span className={styles.muted}>{t('admin.p16.me.perms', { n: me.permissions.length })}</span>
          </div>
          <p className={styles.muted}>{t(`admin.p16.profileDesc.${me.profile}`)}</p>
          {me.pinned && <p className={styles.muted}>{t('admin.p16.me.pinned')}</p>}
          {me.userId === null && <p className={styles.muted}>{t('admin.p16.me.basic')}</p>}
        </div>
      )}
    </Card>
  );

  // --- Matris ---
  const matrixCard = (
    <Card title={t('admin.p16.matrix.title')} padded={false}>
      {matrix.isError ? (
        <ErrorState description={err(matrix.error)} onRetry={() => void matrix.refetch()} />
      ) : !matrix.data ? (
        <Skeleton height="12rem" width="100%" />
      ) : (
        <div className={styles.scroll}>
          <table className={styles.matrix} aria-label={t('admin.p16.matrix.caption')} data-testid="roles-matrix">
            <thead>
              <tr>
                <th scope="col">{t('admin.p16.matrix.permission')}</th>
                {matrix.data.profiles.map((p) => (
                  <th key={p} scope="col" title={t(`admin.p16.profileDesc.${p}`)} data-profile={p}>
                    {profileName(p)}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {matrix.data.entries.map((e) => (
                <tr key={e.permission} data-perm={e.permission}>
                  <th scope="row">
                    <code>{e.permission}</code>
                    <span className={styles.muted}>{i18n.td(`admin.p16.perm.${e.permission}`, '')}</span>
                  </th>
                  {matrix.data.profiles.map((p) => {
                    const yes = e.profiles.includes(p);
                    return (
                      <td key={p} data-yes={yes} className={yes ? styles.yes : styles.no}>
                        <span aria-hidden="true">{yes ? '✓' : '–'}</span>
                        <span className={styles.srOnly}>{t(yes ? 'admin.p16.matrix.yes' : 'admin.p16.matrix.no')}</span>
                      </td>
                    );
                  })}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </Card>
  );

  // --- Yöneticiler ---
  const adminColumns: Column<RbacAdminRow>[] = [
    {
      key: 'name',
      header: t('admin.p16.admins.name'),
      render: (a) => (
        <div>
          <strong>{a.displayName}</strong>
          {a.id === myId && <Badge tone="info">{t('admin.p16.admins.self')}</Badge>}
          {a.pinned && <Badge tone="neutral">{t('admin.p16.admins.pinned')}</Badge>}
          {a.status === 'SUSPENDED' && <Badge tone="danger">{t('admin.p16.admins.suspended')}</Badge>}
          <div className={styles.muted} dir="ltr">
            {a.email}
          </div>
        </div>
      ),
    },
    {
      key: 'profile',
      header: t('admin.p16.admins.profile'),
      render: (a) => <StatusPill tone={a.profile === 'FULL' ? 'primary' : 'info'}>{profileName(a.profile)}</StatusPill>,
    },
    {
      key: 'lastSeen',
      header: t('admin.p16.admins.lastSeen'),
      render: (a) => (a.lastSeenAt ? formatDateTime(a.lastSeenAt) : t('admin.p16.admins.never')),
    },
    {
      key: 'actions',
      header: '',
      render: (a) => <ProfileAssign row={a} locked={a.id === myId || a.pinned} />,
    },
  ];

  const adminsCard = (
    <Card title={t('admin.p16.admins.title')} padded={false} data-testid="roles-admins">
      {!canManage ? (
        <p className={styles.pad}>{t('admin.p16.admins.noManage')}</p>
      ) : admins.isError ? (
        <ErrorState description={err(admins.error)} onRetry={() => void admins.refetch()} />
      ) : (
        <Table
          columns={adminColumns}
          rows={admins.data}
          rowKey={(a) => a.id}
          loading={admins.isLoading}
          empty={<EmptyState title={t('admin.p16.admins.empty')} compact />}
          caption={t('admin.p16.admins.title')}
        />
      )}
    </Card>
  );

  // --- Değişiklik önerileri ---
  const changeColumns: Column<ProfileChange>[] = [
    {
      key: 'target',
      header: t('admin.p16.changes.target'),
      render: (c) => (
        <div>
          <strong>{c.targetName ?? `#${c.targetUserId}`}</strong>
          <div className={styles.muted} dir="ltr">
            {c.targetEmail}
          </div>
        </div>
      ),
    },
    {
      key: 'change',
      header: t('admin.p16.changes.change'),
      render: (c) => `${c.fromProfile ? profileName(c.fromProfile) : '—'} → ${profileName(c.toProfile)}`,
    },
    {
      key: 'proposer',
      header: t('admin.p16.changes.proposer'),
      render: (c) => (c.proposedBy === myId ? t('admin.p16.changes.you') : (c.proposedByEmail ?? `#${c.proposedBy}`)),
    },
    { key: 'reason', header: t('admin.p16.changes.reason'), render: (c) => <span dir="auto">{c.reason}</span> },
    { key: 'expires', header: t('admin.p16.changes.expires'), render: (c) => formatDateTime(c.expiresAt) },
    {
      key: 'status',
      header: t('admin.p16.changes.status'),
      render: (c) => <StatusPill tone={STATUS_TONE[c.status]}>{t(`admin.p16.changes.status.${c.status}`)}</StatusPill>,
    },
    {
      key: 'actions',
      header: '',
      render: (c) => (c.status === 'PENDING' ? <ChangeActions change={c} mine={c.proposedBy === myId} /> : null),
    },
  ];

  const changesCard = (
    <Card title={t('admin.p16.changes.title')} padded={false} data-testid="roles-changes">
      {changes.isError ? (
        <ErrorState description={err(changes.error)} onRetry={() => void changes.refetch()} />
      ) : (
        <Table
          columns={changeColumns}
          rows={changes.data}
          rowKey={(c) => c.id}
          loading={changes.isLoading}
          empty={<EmptyState title={t('admin.p16.changes.empty')} compact />}
          caption={t('admin.p16.changes.title')}
        />
      )}
    </Card>
  );

  return (
    <>
      <PageHeader title={t('admin.p16.roles.title')} description={t('admin.p16.roles.intro')} />
      <div className={styles.stack}>
        {meCard}
        {canManage && adminsCard}
        {canManage && changesCard}
        {matrixCard}
        {!canManage && adminsCard}
      </div>
    </>
  );
}

/** Satır içi profil seçimi + onaylı atama (FULL'i ilgilendiriyorsa iki kişi onayı önerisi). */
function ProfileAssign({ row, locked }: { row: RbacAdminRow; locked: boolean }) {
  const i18n = useI18n();
  const { t } = i18n;
  const [next, setNext] = useState<AdminProfile>(row.profile);
  const two = needsTwoPerson(row.profile, next);
  const name = row.displayName;
  const label = `${t('admin.p16.admins.profile')}: ${name}`;
  const unchanged = next === row.profile;
  return (
    <div className={styles.assign}>
      <Select
        aria-label={label}
        value={next}
        disabled={locked}
        onChange={(e) => setNext(e.target.value as AdminProfile)}
      >
        {ADMIN_PROFILES.map((p) => (
          <option key={p} value={p}>
            {t(`admin.p16.profile.${p}`)}
          </option>
        ))}
      </Select>
      <GuardedAction
        size="sm"
        variant="secondary"
        permission="rbac.manage"
        disabled={locked || unchanged}
        title={t(two ? 'admin.p16.admins.proposeTitle' : 'admin.p16.admins.changeTitle', { name })}
        message={t('admin.p16.admins.changeMessage', {
          from: t(`admin.p16.profile.${row.profile}`),
          to: t(`admin.p16.profile.${next}`),
        })}
        consequence={t(two ? 'admin.p16.admins.proposeConsequence' : 'admin.p16.admins.changeConsequence')}
        irreversible={false}
        danger={two}
        requireReason
        reasonLabel={t('admin.p16.changes.reasonLabel')}
        typeToConfirm={two ? row.email : undefined}
        confirmLabel={t(two ? 'admin.p16.admins.propose' : 'admin.p16.admins.change')}
        errorMessage={(e) => adminError(i18n, e, 'admin.p16.err')}
        successMessage={t(two ? 'admin.p16.admins.proposed' : 'admin.p16.admins.done')}
        invalidateKeys={[[...rbacKeys.admins], [...rbacKeys.changesAll]]}
        onConfirm={({ reason, idempotencyKey }) =>
          two
            ? proposeProfileChange(row.id, next, reason, { idempotencyKey })
            : setAdminProfile(row.id, next, reason, { idempotencyKey })
        }
      >
        {t(two ? 'admin.p16.admins.propose' : 'admin.p16.admins.change')}
      </GuardedAction>
    </div>
  );
}

/** Bekleyen öneri için onayla / reddet (öneren onaylayamaz; reddederek geri çekebilir). */
function ChangeActions({ change, mine }: { change: ProfileChange; mine: boolean }) {
  const i18n = useI18n();
  const { t } = i18n;
  const name = change.targetName ?? `#${change.targetUserId}`;
  const keys = [[...rbacKeys.admins], [...rbacKeys.changesAll]];
  return (
    <div className={styles.assign}>
      <GuardedAction
        size="sm"
        permission="rbac.manage"
        disabled={mine}
        title={t('admin.p16.changes.approveTitle', { name })}
        message={`${change.fromProfile ? t(`admin.p16.profile.${change.fromProfile}`) : '—'} → ${t(`admin.p16.profile.${change.toProfile}`)}`}
        consequence={mine ? t('admin.p16.changes.ownProposal') : t('admin.p16.changes.approveConsequence')}
        irreversible={false}
        danger
        typeToConfirm={change.targetEmail ?? undefined}
        confirmLabel={t('admin.p16.changes.approve')}
        errorMessage={(e) => adminError(i18n, e, 'admin.p16.err')}
        successMessage={t('admin.p16.changes.approved')}
        invalidateKeys={keys}
        onConfirm={({ idempotencyKey }) => approveProfileChange(change.id, undefined, { idempotencyKey })}
      >
        {t('admin.p16.changes.approve')}
      </GuardedAction>
      <GuardedAction
        size="sm"
        variant="ghost"
        permission="rbac.manage"
        title={t('admin.p16.changes.rejectTitle', { name })}
        consequence={t('admin.p16.changes.rejectConsequence')}
        irreversible={false}
        confirmLabel={t('admin.p16.changes.reject')}
        errorMessage={(e) => adminError(i18n, e, 'admin.p16.err')}
        successMessage={t('admin.p16.changes.rejected')}
        invalidateKeys={keys}
        onConfirm={({ idempotencyKey }) => rejectProfileChange(change.id, undefined, { idempotencyKey })}
      >
        {t('admin.p16.changes.reject')}
      </GuardedAction>
    </div>
  );
}
