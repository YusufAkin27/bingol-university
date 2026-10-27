// Kullanıcı ayrıntısı: "Cihazlar ve IP'ler" bölümü.
// API: GET /api/admin/users/{id}/devices, POST /api/admin/access-bans (DEVICE/IP), POST /api/admin/users/{id}/block-access.
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { Link } from 'react-router-dom';
import {
  accessBanKeys,
  BAN_REASONS,
  blockUserAccess,
  createBan,
  listUserDevices,
  type BanReason,
  type UserDevice,
} from '../../../api/accessBans';
import { isApiError } from '../../../api/client';
import {
  Badge,
  Button,
  Card,
  Checkbox,
  ConfirmDialog,
  ErrorState,
  FormField,
  Input,
  Modal,
  Select,
  Skeleton,
  useToast,
} from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { paths } from '../../../paths';
import { adminErrorMessage } from '../campaigns/shared';
import styles from './accessBans.module.css';

type Action = { type: 'device'; device: UserDevice } | { type: 'ip'; ip: string } | { type: 'all' };

function BlockDialog({ userId, action, onClose }: { userId: number; action: Action; onClose: () => void }) {
  const i18n = useI18n();
  const { t, td } = i18n;
  const toast = useToast();
  const qc = useQueryClient();
  const [reason, setReason] = useState<BanReason>('ABUSE');
  const [note, setNote] = useState('');
  const [devices, setDevices] = useState(true);
  const [ips, setIps] = useState(false);
  const [userBan, setUserBan] = useState(true);
  const [selfConfirm, setSelfConfirm] = useState(false);

  const run = useMutation({
    mutationFn: (force: boolean) => {
      const n = note.trim() || undefined;
      if (action.type === 'device') {
        return createBan({
          kind: 'DEVICE',
          value: action.device.deviceHash,
          reasonCode: reason,
          note: n,
          ...(force ? { force: true } : {}),
        });
      }
      if (action.type === 'ip') {
        return createBan({ kind: 'IP', value: action.ip, reasonCode: reason, note: n, ...(force ? { force: true } : {}) });
      }
      return blockUserAccess(userId, { devices, ips, userBan, reasonCode: reason, note: n, ...(force ? { force: true } : {}) });
    },
    onSuccess: () => {
      toast.success(t('admin.ab.dev.toast'));
      void qc.invalidateQueries({ queryKey: accessBanKeys.all });
      void qc.invalidateQueries({ queryKey: ['users'] });
      onClose();
    },
    onError: (e) => {
      if (isApiError(e) && e.code === 'BAN_SELF_LOCKOUT') {
        setSelfConfirm(true);
        return;
      }
      setSelfConfirm(false);
      toast.error(adminErrorMessage(i18n, e));
    },
  });

  const title =
    action.type === 'device'
      ? t('admin.ab.dev.blockDevice')
      : action.type === 'ip'
        ? t('admin.ab.dev.blockIp')
        : t('admin.ab.dev.dialog.title');

  return (
    <>
      <Modal
        open={!selfConfirm}
        onClose={onClose}
        title={title}
        footer={
          <>
            <Button variant="secondary" onClick={onClose}>
              {t('common.cancel')}
            </Button>
            <Button variant="danger" loading={run.isPending} onClick={() => run.mutate(false)}>
              {t('admin.ab.dev.dialog.submit')}
            </Button>
          </>
        }
      >
        <div className={styles.form}>
          {action.type === 'ip' && <code className={`${styles.mono} ltr`}>{action.ip}</code>}
          {action.type === 'device' && <code className={`${styles.mono} ltr`}>{action.device.deviceHashShort}</code>}
          {action.type === 'all' && (
            <>
              <Checkbox checked={userBan} onChange={(e) => setUserBan(e.target.checked)} label={t('admin.ab.dev.dialog.userBan')} />
              <Checkbox checked={devices} onChange={(e) => setDevices(e.target.checked)} label={t('admin.ab.dev.dialog.devices')} />
              <Checkbox checked={ips} onChange={(e) => setIps(e.target.checked)} label={t('admin.ab.dev.dialog.ips')} />
              {ips && <p className={styles.warn}>{t('admin.ab.add.ipsWarn')}</p>}
            </>
          )}
          <FormField label={t('admin.ab.reason.label')}>
            <Select value={reason} onChange={(e) => setReason(e.target.value as BanReason)}>
              {BAN_REASONS.map((r) => (
                <option key={r} value={r}>
                  {td(`admin.ab.reason.${r}`)}
                </option>
              ))}
            </Select>
          </FormField>
          <FormField label={t('admin.ab.add.note')}>
            <Input value={note} maxLength={300} dir="auto" onChange={(e) => setNote(e.target.value)} />
          </FormField>
        </div>
      </Modal>
      <ConfirmDialog
        open={selfConfirm}
        onClose={() => setSelfConfirm(false)}
        onConfirm={() => run.mutate(true)}
        loading={run.isPending}
        danger
        title={t('admin.ab.self.title')}
        message={t('admin.ab.self.body')}
        confirmLabel={t('admin.ab.self.confirm')}
      />
    </>
  );
}

export function UserDevices({ userId }: { userId: number }) {
  const i18n = useI18n();
  const { t, td, formatDateTime, formatNumber } = i18n;
  const [action, setAction] = useState<Action | null>(null);
  const q = useQuery({ queryKey: accessBanKeys.devices(userId), queryFn: () => listUserDevices(userId) });

  return (
    <Card title={t('admin.ab.dev.title')}>
      {q.isError ? (
        <ErrorState compact description={adminErrorMessage(i18n, q.error)} onRetry={() => void q.refetch()} />
      ) : q.isLoading ? (
        <Skeleton height="5rem" width="100%" />
      ) : (
        <div className={styles.form}>
          {q.data && q.data.devices.length === 0 && q.data.unidentifiedIps.length === 0 && (
            <p className={styles.muted}>{t('admin.ab.dev.empty')}</p>
          )}
          {q.data?.devices.map((d) => (
            <div key={d.deviceHashShort} className={styles.device} data-testid="user-device">
              <div className={styles.deviceHead}>
                <strong>{d.platform ? td(`admin.users.platform.${d.platform}`, d.platform) : '—'}</strong>
                {d.appVersion && <span className={`${styles.muted} ltr`}>v{d.appVersion}</span>}
                <code className={`${styles.mono} ltr`}>{d.deviceHashShort}</code>
                {d.blocked && <Badge tone="danger">{t('admin.ab.dev.blocked')}</Badge>}
              </div>
              <p className={styles.muted}>
                {t('admin.ab.dev.firstSeen')}: {formatDateTime(d.firstSeenAt)} · {t('admin.ab.dev.lastSeen')}:{' '}
                {formatDateTime(d.lastSeenAt)}
              </p>
              {d.ips.length > 0 && (
                <div>
                  <p className={styles.muted}>{t('admin.ab.dev.ips')}</p>
                  <ul className={styles.ipList}>
                    {d.ips.map((p) => (
                      <li key={p.ip}>
                        <code className={`${styles.mono} ltr`}>{p.ip}</code>{' '}
                        <span className={styles.muted}>{formatDateTime(p.lastSeenAt)}</span>{' '}
                        {p.blocked ? (
                          <Badge tone="danger">{t('admin.ab.dev.blocked')}</Badge>
                        ) : (
                          <Button size="sm" variant="ghost" onClick={() => setAction({ type: 'ip', ip: p.ip })}>
                            {t('admin.ab.dev.blockIp')}
                          </Button>
                        )}
                      </li>
                    ))}
                  </ul>
                </div>
              )}
              {d.sharedWithUsers.length > 0 && (
                <p className={styles.warn} role="note">
                  {t('admin.ab.dev.shared', { n: formatNumber(d.sharedWithUsers.length) })}:{' '}
                  {d.sharedWithUsers.map((u, i) => (
                    <span key={u.id}>
                      {i > 0 && ', '}
                      <Link to={paths.admin.user(u.id)}>{u.displayName}</Link>
                    </span>
                  ))}
                </p>
              )}
              {!d.blocked && (
                <div className={styles.actions}>
                  <Button size="sm" variant="danger" onClick={() => setAction({ type: 'device', device: d })}>
                    {t('admin.ab.dev.blockDevice')}
                  </Button>
                </div>
              )}
            </div>
          ))}
          {q.data && q.data.unidentifiedIps.length > 0 && (
            <div className={styles.device}>
              <p className={styles.muted}>{t('admin.ab.dev.noDeviceIps')}</p>
              <ul className={styles.ipList}>
                {q.data.unidentifiedIps.map((p) => (
                  <li key={p.ip}>
                    <code className={`${styles.mono} ltr`}>{p.ip}</code>{' '}
                    <span className={styles.muted}>{formatDateTime(p.lastSeenAt)}</span>{' '}
                    {p.blocked ? (
                      <Badge tone="danger">{t('admin.ab.dev.blocked')}</Badge>
                    ) : (
                      <Button size="sm" variant="ghost" onClick={() => setAction({ type: 'ip', ip: p.ip })}>
                        {t('admin.ab.dev.blockIp')}
                      </Button>
                    )}
                  </li>
                ))}
              </ul>
            </div>
          )}
          <div>
            <Button variant="danger" onClick={() => setAction({ type: 'all' })}>
              {t('admin.ab.dev.blockAll')}
            </Button>
          </div>
        </div>
      )}
      {action && <BlockDialog userId={userId} action={action} onClose={() => setAction(null)} />}
    </Card>
  );
}
