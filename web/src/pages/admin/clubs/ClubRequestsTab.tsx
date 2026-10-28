// Kulüp çekmecesi: Başvurular sekmesi — bekleyen katılma istekleri (zorla onay/ret) ve davet kodları (iptal).
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import {
  decideJoinRequest,
  listClubInvites,
  listJoinRequests,
  revokeClubInvite,
  type ClubInvite,
  type ClubMember,
} from '../../../api/adminCommunities';
import { GuardedDialog } from '../../../components/admin/GuardedDialog';
import { useGuardedMutation } from '../../../components/admin/guard/useGuardedMutation';
import {
  Avatar,
  Badge,
  Button,
  EmptyState,
  ErrorState,
  Pagination,
  Skeleton,
} from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminError } from '../../../lib/errors';
import styles from './clubs.module.css';

const KEYS = [['communities']];

export function ClubRequestsTab({ communityId, clubName }: { communityId: number; clubName: string }) {
  const i18n = useI18n();
  const { t, formatDateTime } = i18n;
  const [page, setPage] = useState(0);
  const [rejecting, setRejecting] = useState<ClubMember | null>(null);
  const [revoking, setRevoking] = useState<ClubInvite | null>(null);
  const [busy, setBusy] = useState<number | null>(null);

  const requests = useQuery({
    queryKey: ['communities', 'admin', 'requests', communityId, page],
    queryFn: () => listJoinRequests(communityId, page, 20),
    staleTime: 10_000,
  });
  const invites = useQuery({
    queryKey: ['communities', 'admin', 'invites', communityId],
    queryFn: () => listClubInvites(communityId),
    staleTime: 10_000,
  });

  const approve = useGuardedMutation({
    mutationFn: (userId: number, ctx) => decideJoinRequest(communityId, userId, true, { idempotencyKey: ctx.idempotencyKey }),
    successMessage: t('admin.p06.requests.approved'),
    invalidateKeys: KEYS,
  });

  const data = requests.data;
  return (
    <div className={styles.panel}>
      <section aria-label={t('admin.p06.requests.title')}>
        <h3 className={styles.zoneTitle}>{t('admin.p06.requests.title')}</h3>
        <p className={styles.zoneText}>{t('admin.p06.requests.hint')}</p>
        {requests.isError ? (
          <ErrorState description={adminError(i18n, requests.error)} onRetry={() => void requests.refetch()} />
        ) : requests.isPending ? (
          <Skeleton height="6rem" width="100%" />
        ) : data && data.items.length === 0 ? (
          <EmptyState icon="users" title={t('admin.p06.requests.empty')} description=" " compact />
        ) : (
          data && (
            <>
              <ul className={styles.list} data-testid="request-list">
                {data.items.map((r) => {
                  const name = r.displayName ?? `#${r.userId}`;
                  return (
                    <li key={r.userId} className={styles.row} data-testid="request-row">
                      <div className={styles.rowHead}>
                        <span className={styles.person}>
                          <Avatar name={name} src={r.avatarUrl} size={32} />
                          <span className={styles.personName} dir="auto">
                            {name}
                          </span>
                          <span className={`${styles.muted} ltr`}>{r.email}</span>
                        </span>
                        <span className={styles.spacer} />
                        <time className={styles.muted} dateTime={r.joinedAt}>
                          {formatDateTime(r.joinedAt)}
                        </time>
                      </div>
                      <div className={styles.actions}>
                        <span className={styles.spacer} />
                        <Button size="sm" variant="secondary" onClick={() => setRejecting(r)}>
                          {t('admin.p06.requests.reject')}
                        </Button>
                        <Button
                          size="sm"
                          loading={busy === r.userId}
                          onClick={() => {
                            setBusy(r.userId);
                            void approve.run(r.userId).finally(() => setBusy(null));
                          }}
                        >
                          {t('admin.p06.requests.approve')}
                        </Button>
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
      </section>

      <section aria-label={t('admin.p06.invites.title')}>
        <h3 className={styles.zoneTitle}>{t('admin.p06.invites.title')}</h3>
        {invites.isError ? (
          <ErrorState description={adminError(i18n, invites.error)} onRetry={() => void invites.refetch()} />
        ) : invites.isPending ? (
          <Skeleton height="4rem" width="100%" />
        ) : invites.data && invites.data.length === 0 ? (
          <p className={styles.muted}>{t('admin.p06.invites.empty')}</p>
        ) : (
          <ul className={styles.list} data-testid="invite-list">
            {(invites.data ?? []).map((i) => (
              <li key={i.id} className={styles.row}>
                <div className={styles.rowHead}>
                  <span className="ltr">{i.codeHint}</span>
                  <Badge tone={i.state === 'ACTIVE' ? 'success' : 'neutral'}>{i.revoked ? t('admin.p06.invites.revoked') : i.state}</Badge>
                  <span className={styles.muted}>
                    {t('admin.p06.invites.uses', { used: i.usedCount, max: i.maxUses ?? '∞' })}
                  </span>
                  <span className={styles.spacer} />
                  <span className={styles.muted}>{t('admin.p06.invites.expires', { at: formatDateTime(i.expiresAt) })}</span>
                  {!i.revoked && (
                    <Button size="sm" variant="danger" onClick={() => setRevoking(i)}>
                      {t('admin.p06.invites.revoke')}
                    </Button>
                  )}
                </div>
              </li>
            ))}
          </ul>
        )}
      </section>

      <GuardedDialog
        open={rejecting !== null}
        onClose={() => setRejecting(null)}
        title={t('admin.p06.requests.reject.title')}
        message={t('admin.p06.requests.reject.message', {
          name: rejecting?.displayName ?? `#${rejecting?.userId ?? ''}`,
          club: clubName,
        })}
        consequence={t('admin.p06.requests.reject.consequence')}
        irreversible={false}
        danger
        confirmLabel={t('admin.p06.requests.reject')}
        successMessage={t('admin.p06.requests.rejected')}
        invalidateKeys={KEYS}
        onConfirm={({ idempotencyKey }) => decideJoinRequest(communityId, rejecting!.userId, false, { idempotencyKey })}
      />
      <GuardedDialog
        open={revoking !== null}
        onClose={() => setRevoking(null)}
        title={t('admin.p06.invites.revoke.title')}
        message={t('admin.p06.invites.revoke.message', { hint: revoking?.codeHint ?? '' })}
        irreversible
        danger
        confirmLabel={t('admin.p06.invites.revoke')}
        requireReason
        successMessage={t('admin.p06.invites.revoked.done')}
        invalidateKeys={KEYS}
        onConfirm={({ reason, idempotencyKey }) => revokeClubInvite(communityId, revoking!.id, { reason, idempotencyKey })}
      />
    </div>
  );
}
