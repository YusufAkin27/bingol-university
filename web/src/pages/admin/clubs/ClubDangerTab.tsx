// Kulüp çekmecesi: Tehlikeli bölge — kapat / yeniden aç / sahipliği devret / sil (+ onay bekleyen kulüp için onay/ret).
// Hepsi GuardedDialog: sebep zorunlu; devir ve silme GERİ ALINAMAZ: kulüp adını yazarak onay + irreversible uyarısı.
import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import {
  closeClub,
  deleteClub,
  listClubMembers,
  reopenClub,
  transferClub,
  type ClubDetail,
} from '../../../api/adminCommunities';
import { approveCommunity, rejectCommunity } from '../../../api/approvals';
import { GuardedDialog } from '../../../components/admin/GuardedDialog';
import { Button, Checkbox, FormField, Select, PermissionButton } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import styles from './clubs.module.css';

const KEYS = [['communities']];
type Dialog = null | 'close' | 'reopen' | 'transfer' | 'delete' | 'approve' | 'reject';

export function ClubDangerTab({ detail, onDeleted }: { detail: ClubDetail; onDeleted?: () => void }) {
  const { t } = useI18n();
  const { club, capabilities: caps } = detail;
  const [dialog, setDialog] = useState<Dialog>(null);
  const [target, setTarget] = useState('');
  const [keepAdmin, setKeepAdmin] = useState(true);
  const close = () => setDialog(null);

  const candidates = useQuery({
    queryKey: ['communities', 'admin', 'transfer-candidates', club.id],
    queryFn: () => listClubMembers(club.id, { status: 'ACTIVE' }, 0, 100),
    enabled: caps.canTransfer,
    staleTime: 15_000,
  });
  const options = (candidates.data?.items ?? []).filter((m) => m.role !== 'OWNER' && m.accountStatus === 'ACTIVE');
  const targetId = Number(target);
  const targetMember = options.find((m) => m.userId === targetId);

  return (
    <div className={styles.panel}>
      {caps.canApprove && (
        <section className={styles.zone} aria-label={t('admin.p06.danger.review.title')}>
          <h3 className={styles.zoneTitle}>{t('admin.p06.danger.review.title')}</h3>
          <p className={styles.zoneText}>{t('admin.p06.danger.review.text')}</p>
          <div className={styles.actions}>
            <Button variant="secondary" onClick={() => setDialog('reject')}>
              {t('admin.review.reject')}
            </Button>
            <Button onClick={() => setDialog('approve')}>{t('admin.review.approve')}</Button>
          </div>
        </section>
      )}

      {caps.canClose && (
        <section className={styles.zone} aria-label={t('admin.p06.danger.close.title')}>
          <h3 className={styles.zoneTitle}>{t('admin.p06.danger.close.title')}</h3>
          <p className={styles.zoneText}>{t('admin.p06.danger.close.text')}</p>
          <div className={styles.actions}>
            <PermissionButton permission="content.write" variant="danger" onClick={() => setDialog('close')}>
              {t('admin.p06.danger.close.button')}
            </PermissionButton>
          </div>
        </section>
      )}

      {caps.canReopen && (
        <section className={styles.zone} aria-label={t('admin.p06.danger.reopen.title')}>
          <h3 className={styles.zoneTitle}>{t('admin.p06.danger.reopen.title')}</h3>
          <p className={styles.zoneText}>{t('admin.p06.danger.reopen.text')}</p>
          <div className={styles.actions}>
            <Button onClick={() => setDialog('reopen')}>{t('admin.p06.danger.reopen.button')}</Button>
          </div>
        </section>
      )}

      {caps.canTransfer && (
        <section className={`${styles.zone} ${styles.zoneDanger}`} aria-label={t('admin.p06.danger.transfer.title')}>
          <h3 className={styles.zoneTitle}>{t('admin.p06.danger.transfer.title')}</h3>
          <p className={styles.zoneText}>{t('admin.p06.danger.transfer.text')}</p>
          <FormField label={t('admin.p06.danger.transfer.target')} hint={t('admin.p06.danger.transfer.targetHint')}>
            <Select value={target} onChange={(e) => setTarget(e.target.value)}>
              <option value="">{t('admin.p06.danger.transfer.choose')}</option>
              {options.map((m) => (
                <option key={m.userId} value={m.userId}>
                  {(m.displayName ?? `#${m.userId}`) + (m.email ? ` (${m.email})` : '')}
                </option>
              ))}
            </Select>
          </FormField>
          <Checkbox label={t('admin.p06.danger.transfer.keep')} checked={keepAdmin} onChange={(e) => setKeepAdmin(e.target.checked)} />
          <div className={styles.actions}>
            <Button variant="danger" disabled={!targetMember} onClick={() => setDialog('transfer')}>
              {t('admin.p06.danger.transfer.button')}
            </Button>
          </div>
        </section>
      )}

      {caps.canDelete && (
        <section className={`${styles.zone} ${styles.zoneDanger}`} aria-label={t('admin.p06.danger.delete.title')}>
          <h3 className={styles.zoneTitle}>{t('admin.p06.danger.delete.title')}</h3>
          <p className={styles.zoneText}>{t('admin.p06.danger.delete.text')}</p>
          <div className={styles.actions}>
            <PermissionButton permission="content.write" variant="danger" onClick={() => setDialog('delete')}>
              {t('admin.p06.danger.delete.button')}
            </PermissionButton>
          </div>
        </section>
      )}

      {!caps.canClose && !caps.canReopen && !caps.canTransfer && !caps.canDelete && !caps.canApprove && (
        <p className={styles.muted}>{t('admin.p06.danger.none')}</p>
      )}

      <GuardedDialog
        open={dialog === 'close'}
        onClose={close}
        title={t('admin.p06.danger.close.dialog', { name: club.name })}
        message={t('admin.p06.danger.close.message')}
        consequence={t('admin.p06.danger.close.consequence', { n: club.memberCount })}
        irreversible={false}
        danger
        confirmLabel={t('admin.p06.danger.close.button')}
        requireReason
        successMessage={t('admin.p06.danger.close.done')}
        invalidateKeys={KEYS}
        onConfirm={({ reason, idempotencyKey }) => closeClub(club.id, { reason, idempotencyKey })}
      />
      <GuardedDialog
        open={dialog === 'reopen'}
        onClose={close}
        title={t('admin.p06.danger.reopen.dialog', { name: club.name })}
        message={t('admin.p06.danger.reopen.message')}
        irreversible={false}
        confirmLabel={t('admin.p06.danger.reopen.button')}
        requireReason
        successMessage={t('admin.p06.danger.reopen.done')}
        invalidateKeys={KEYS}
        onConfirm={({ reason, idempotencyKey }) => reopenClub(club.id, { reason, idempotencyKey })}
      />
      <GuardedDialog
        open={dialog === 'transfer'}
        onClose={close}
        title={t('admin.p06.danger.transfer.dialog', { name: club.name })}
        message={t('admin.p06.danger.transfer.message', {
          from: club.ownerName ?? `#${club.ownerId}`,
          to: targetMember?.displayName ?? `#${target}`,
        })}
        consequence={t(keepAdmin ? 'admin.p06.danger.transfer.consequenceKeep' : 'admin.p06.danger.transfer.consequenceDrop')}
        irreversible
        danger
        confirmLabel={t('admin.p06.danger.transfer.button')}
        requireReason
        typeToConfirm={club.name}
        successMessage={t('admin.p06.danger.transfer.done')}
        invalidateKeys={KEYS}
        onConfirm={({ reason, idempotencyKey }) => transferClub(club.id, targetId, keepAdmin, { reason, idempotencyKey })}
        onSuccess={() => setTarget('')}
      />
      <GuardedDialog
        open={dialog === 'delete'}
        onClose={close}
        title={t('admin.p06.danger.delete.dialog', { name: club.name })}
        message={t('admin.p06.danger.delete.message')}
        consequence={t('admin.p06.danger.delete.consequence', { n: club.memberCount, events: club.eventCount })}
        irreversible
        danger
        confirmLabel={t('admin.p06.danger.delete.button')}
        requireReason
        typeToConfirm={club.name}
        successMessage={t('admin.p06.danger.delete.done')}
        invalidateKeys={KEYS}
        onConfirm={({ reason, idempotencyKey }) => deleteClub(club.id, { reason, idempotencyKey })}
        onSuccess={onDeleted}
      />
      <GuardedDialog
        open={dialog === 'approve'}
        onClose={close}
        title={t('admin.p06.danger.review.approveTitle', { name: club.name })}
        irreversible={false}
        confirmLabel={t('admin.review.approve')}
        successMessage={t('admin.review.toast.approved', { name: club.name })}
        invalidateKeys={KEYS}
        onConfirm={() => approveCommunity(club.id)}
      />
      <GuardedDialog
        open={dialog === 'reject'}
        onClose={close}
        title={t('admin.review.reject.title', { name: club.name })}
        message={t('admin.review.reject.intro')}
        danger
        confirmLabel={t('admin.review.reject')}
        optionalReason
        reasonLabel={t('admin.review.reject.reason')}
        successMessage={t('admin.review.toast.rejected', { name: club.name })}
        invalidateKeys={KEYS}
        onConfirm={({ reason }) => rejectCommunity(club.id, reason || undefined)}
      />
    </div>
  );
}
