// Kulüp çekmecesi: Üyeler sekmesi. Rol değiştirme ve çıkarma GuardedDialog'dan geçer (sebep zorunlu, çift tıklama kilidi,
// Idempotency-Key). Sahibin rolü/üyeliği burada değişmez: önce "Tehlikeli bölge"den devredilir (sunucu da reddeder).
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import {
  listClubMembers,
  removeClubMember,
  setClubMemberRole,
  type ClubMember,
  type ClubRole,
  type MemberFilters,
} from '../../../api/adminCommunities';
import { GuardedDialog } from '../../../components/admin/GuardedDialog';
import {
  Avatar,
  Badge,
  Button,
  Checkbox,
  EmptyState,
  ErrorState,
  FormField,
  Input,
  Pagination,
  Select,
  Skeleton,
} from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { useDebouncedValue } from '../../../lib/hooks';
import { adminError } from '../../../lib/errors';
import { ASSIGNABLE_ROLES, canChangeRole, canRemoveMember } from './clubsLogic';
import styles from './clubs.module.css';

type Dialog = null | { kind: 'role'; member: ClubMember; role: Exclude<ClubRole, 'OWNER'> } | { kind: 'remove'; member: ClubMember };

const KEYS = [['communities']];

export function ClubMembersTab({ communityId, clubName }: { communityId: number; clubName: string }) {
  const i18n = useI18n();
  const { t, formatDateTime } = i18n;
  const [filters, setFilters] = useState<MemberFilters>({ status: '', role: '', q: '' });
  const [page, setPage] = useState(0);
  const q = useDebouncedValue(filters.q ?? '', 400);
  const f = { ...filters, q };
  const [dialog, setDialog] = useState<Dialog>(null);
  const [ban, setBan] = useState(false);
  /** Satır başına seçili yeni rol (düğmeye basılana dek yalnız seçimdir). */
  const [picked, setPicked] = useState<Record<number, Exclude<ClubRole, 'OWNER'>>>({});

  const list = useQuery({
    queryKey: ['communities', 'admin', 'members', communityId, f, page],
    queryFn: () => listClubMembers(communityId, f, page, 20),
    staleTime: 10_000,
  });
  const data = list.data;
  const set = (p: Partial<MemberFilters>) => {
    setFilters((x) => ({ ...x, ...p }));
    setPage(0);
  };
  const close = () => setDialog(null);
  const m = dialog?.member;
  const name = m?.displayName ?? (m ? `#${m.userId}` : '');

  return (
    <div className={styles.panel}>
      <div className={styles.filters} role="search" aria-label={t('admin.p06.members.filters')}>
        <FormField label={t('admin.p06.members.filter.status')}>
          <Select value={filters.status ?? ''} onChange={(e) => set({ status: e.target.value as MemberFilters['status'] })}>
            <option value="">{t('admin.p06.members.all')}</option>
            {(['ACTIVE', 'PENDING', 'BANNED'] as const).map((s) => (
              <option key={s} value={s}>
                {t(`admin.p06.members.status.${s}`)}
              </option>
            ))}
          </Select>
        </FormField>
        <FormField label={t('admin.p06.members.filter.role')}>
          <Select value={filters.role ?? ''} onChange={(e) => set({ role: e.target.value as MemberFilters['role'] })}>
            <option value="">{t('admin.p06.members.all')}</option>
            {(['OWNER', 'ADMIN', 'MODERATOR', 'MEMBER'] as const).map((r) => (
              <option key={r} value={r}>
                {t(`admin.p06.members.role.${r}`)}
              </option>
            ))}
          </Select>
        </FormField>
        <FormField label={t('admin.p06.members.filter.q')}>
          <Input type="search" value={filters.q ?? ''} onChange={(e) => set({ q: e.target.value })} />
        </FormField>
      </div>

      {list.isError ? (
        <ErrorState description={adminError(i18n, list.error)} onRetry={() => void list.refetch()} />
      ) : list.isPending ? (
        <Skeleton height="10rem" width="100%" />
      ) : data && data.items.length === 0 ? (
        <EmptyState icon="users" title={t('admin.p06.members.empty')} description=" " compact />
      ) : (
        data && (
          <>
            <p className={styles.meta} aria-live="polite">
              {t('admin.p06.members.count', { n: data.total })}
            </p>
            <ul className={styles.list} data-testid="member-list">
              {data.items.map((mm) => {
                const displayName = mm.displayName ?? `#${mm.userId}`;
                const role = picked[mm.userId] ?? (mm.role === 'OWNER' ? 'MEMBER' : mm.role);
                return (
                  <li key={mm.userId} className={styles.row} data-testid="member-row">
                    <div className={styles.rowHead}>
                      <span className={styles.person}>
                        <Avatar name={displayName} src={mm.avatarUrl} size={32} />
                        <span className={styles.personName} dir="auto">
                          {displayName}
                        </span>
                        <span className={`${styles.muted} ltr`}>{mm.email}</span>
                      </span>
                      <span className={styles.badges}>
                        <Badge tone={mm.role === 'OWNER' ? 'primary' : mm.role === 'MEMBER' ? 'neutral' : 'info'}>
                          {t(`admin.p06.members.role.${mm.role}`)}
                        </Badge>
                        {mm.status !== 'ACTIVE' && (
                          <Badge tone={mm.status === 'BANNED' ? 'danger' : 'warning'}>
                            {t(`admin.p06.members.status.${mm.status}`)}
                          </Badge>
                        )}
                        {mm.customPermissions && <Badge>{t('admin.p06.members.custom')}</Badge>}
                      </span>
                      <span className={styles.spacer} />
                      <time className={styles.muted} dateTime={mm.joinedAt}>
                        {formatDateTime(mm.joinedAt)}
                      </time>
                    </div>
                    <div className={styles.actions}>
                      {canChangeRole(mm) && (
                        <>
                          <Select
                            className={styles.roleSelect}
                            aria-label={t('admin.p06.members.newRole', { name: displayName })}
                            value={role}
                            onChange={(e) =>
                              setPicked((p) => ({ ...p, [mm.userId]: e.target.value as Exclude<ClubRole, 'OWNER'> }))
                            }
                          >
                            {ASSIGNABLE_ROLES.map((r) => (
                              <option key={r} value={r}>
                                {t(`admin.p06.members.role.${r}`)}
                              </option>
                            ))}
                          </Select>
                          <Button
                            size="sm"
                            variant="secondary"
                            disabled={role === mm.role}
                            onClick={() => setDialog({ kind: 'role', member: mm, role })}
                          >
                            {t('admin.p06.members.changeRole')}
                          </Button>
                        </>
                      )}
                      {canRemoveMember(mm) ? (
                        <Button
                          size="sm"
                          variant="danger"
                          onClick={() => {
                            setBan(false);
                            setDialog({ kind: 'remove', member: mm });
                          }}
                        >
                          {t(mm.status === 'BANNED' ? 'admin.p06.members.unban' : 'admin.p06.members.remove')}
                        </Button>
                      ) : (
                        <span className={styles.muted}>{t('admin.p06.members.ownerNote')}</span>
                      )}
                    </div>
                  </li>
                );
              })}
            </ul>
            {data.totalPages > 1 && (
              <div className={styles.pager}>
                <Pagination page={data.page} totalPages={data.totalPages} totalItems={data.total} onPageChange={setPage} />
              </div>
            )}
          </>
        )
      )}

      <GuardedDialog
        open={dialog?.kind === 'role'}
        onClose={close}
        title={t('admin.p06.members.role.title')}
        message={
          dialog?.kind === 'role'
            ? t('admin.p06.members.role.message', {
                name,
                from: t(`admin.p06.members.role.${dialog.member.role}`),
                to: t(`admin.p06.members.role.${dialog.role}`),
                club: clubName,
              })
            : undefined
        }
        consequence={t('admin.p06.members.role.consequence')}
        irreversible={false}
        confirmLabel={t('admin.p06.members.changeRole')}
        requireReason
        successMessage={t('admin.p06.members.role.done')}
        invalidateKeys={KEYS}
        onConfirm={({ reason, idempotencyKey }) =>
          dialog?.kind === 'role'
            ? setClubMemberRole(communityId, dialog.member.userId, dialog.role, { reason, idempotencyKey })
            : Promise.resolve()
        }
        onSuccess={() => setPicked({})}
      />
      <GuardedDialog
        open={dialog?.kind === 'remove'}
        onClose={close}
        title={t(m?.status === 'BANNED' ? 'admin.p06.members.unban.title' : 'admin.p06.members.remove.title')}
        message={t(m?.status === 'BANNED' ? 'admin.p06.members.unban.message' : 'admin.p06.members.remove.message', {
          name,
          club: clubName,
        })}
        consequence={t('admin.p06.members.remove.consequence')}
        irreversible={false}
        danger
        confirmLabel={t(m?.status === 'BANNED' ? 'admin.p06.members.unban' : 'admin.p06.members.remove')}
        requireReason
        successMessage={t('admin.p06.members.remove.done')}
        invalidateKeys={KEYS}
        extra={
          m?.status === 'BANNED' ? undefined : (
            <Checkbox label={t('admin.p06.members.remove.ban')} checked={ban} onChange={(e) => setBan(e.target.checked)} />
          )
        }
        onConfirm={({ reason, idempotencyKey }) =>
          dialog?.kind === 'remove'
            ? removeClubMember(communityId, dialog.member.userId, dialog.member.status === 'BANNED' ? false : ban, {
                reason,
                idempotencyKey,
              })
            : Promise.resolve()
        }
      />
    </div>
  );
}
