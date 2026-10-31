// "Engel ekle" diyaloğu: POST /api/admin/access-bans. BAN_SELF_LOCKOUT gelirse onaydan sonra force=true ile yeniden dener.
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { accessBanKeys, BAN_KINDS, BAN_REASONS, createBan, type BanKind, type BanReason } from '../../../api/accessBans';
import { isApiError } from '../../../api/client';
import { qk } from '../../../api/queryKeys';
import { listUsers } from '../../../api/users';
import {
  Button,
  Checkbox,
  ConfirmDialog,
  FormField,
  Input,
  Modal,
  Select,
  useToast,
} from '../../../components/ui';
import { ReasonField } from '../../../components/admin/guard/ReasonField';
import { ADMIN_REASON_MIN, isReasonValid } from '../../../components/admin/guard/match';
import { useI18n } from '../../../i18n/I18nProvider';
import { useDebouncedValue } from '../../../lib/hooks';
import { adminErrorMessage } from '../campaigns/shared';
import styles from './accessBans.module.css';
import { endOfDayIso, isValidBanValue } from './logic';

interface Props {
  open: boolean;
  onClose: () => void;
  /** Önceden doldurma (örn. kullanıcı sayfasından). */
  initial?: { kind: BanKind; value: string; label?: string };
}

export function AddBanDialog({ open, onClose, initial }: Props) {
  const i18n = useI18n();
  const { t, td } = i18n;
  const toast = useToast();
  const qc = useQueryClient();

  const [kind, setKind] = useState<BanKind>(initial?.kind ?? 'IP');
  const [value, setValue] = useState(initial?.value ?? '');
  const [pickedName, setPickedName] = useState(initial?.label ?? '');
  const [userQ, setUserQ] = useState('');
  const [reason, setReason] = useState<BanReason>('ABUSE');
  const [note, setNote] = useState('');
  const [forever, setForever] = useState(true);
  const [date, setDate] = useState('');
  const [alsoDevices, setAlsoDevices] = useState(false);
  const [alsoIps, setAlsoIps] = useState(false);
  const [touched, setTouched] = useState(false);
  const [selfConfirm, setSelfConfirm] = useState(false);
  // W1-B (T-013): engel ekleme islem gerekcesi ister (X-Admin-Reason).
  const [why, setWhy] = useState('');
  const whyOk = isReasonValid(why, ADMIN_REASON_MIN);

  const term = useDebouncedValue(userQ.trim(), 300);
  const found = useQuery({
    queryKey: qk.users.list({ q: term, size: 6 }),
    queryFn: () => listUsers({ q: term, size: 6 }),
    enabled: open && kind === 'USER' && term.length >= 2,
  });

  const valueOk = isValidBanValue(kind, value);
  const expiresAt = forever ? null : endOfDayIso(date);
  const dateOk = forever || expiresAt !== null;

  function body(force: boolean) {
    return {
      kind,
      value: value.trim(),
      reasonCode: reason,
      note: note.trim() || undefined,
      expiresAt,
      ...(kind === 'USER' ? { alsoBlockUserDevices: alsoDevices, alsoBlockUserIps: alsoIps } : {}),
      ...(force ? { force: true } : {}),
    };
  }

  const create = useMutation({
    mutationFn: (force: boolean) => createBan(body(force), { reason: why }),
    onSuccess: () => {
      toast.success(t('admin.ab.toast.added'));
      setSelfConfirm(false);
      void qc.invalidateQueries({ queryKey: accessBanKeys.all });
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

  function submit() {
    setTouched(true);
    if (valueOk && dateOk && whyOk) create.mutate(false);
  }

  function changeKind(k: BanKind) {
    setKind(k);
    setValue('');
    setPickedName('');
    setTouched(false);
  }

  return (
    <>
      <Modal
        open={open && !selfConfirm}
        onClose={onClose}
        title={t('admin.ab.add.title')}
        footer={
          <>
            <Button variant="secondary" onClick={onClose}>
              {t('common.cancel')}
            </Button>
            <Button variant="danger" loading={create.isPending} disabled={!whyOk} onClick={submit}>
              {t('admin.ab.add.submit')}
            </Button>
          </>
        }
      >
        <form
          noValidate
          className={styles.form}
          onSubmit={(e) => {
            e.preventDefault();
            submit();
          }}
        >
          <FormField label={t('admin.ab.add.kind')}>
            <Select value={kind} onChange={(e) => changeKind(e.target.value as BanKind)}>
              {BAN_KINDS.map((k) => (
                <option key={k} value={k}>
                  {td(`admin.ab.kind.${k}`)}
                </option>
              ))}
            </Select>
          </FormField>

          {kind === 'USER' ? (
            <>
              <FormField
                label={t('admin.ab.add.userSearch')}
                hint={t('admin.ab.add.hint.USER')}
                error={touched && !valueOk ? t('admin.ab.add.err.USER') : null}
              >
                <Input value={userQ} autoComplete="off" dir="auto" onChange={(e) => setUserQ(e.target.value)} />
              </FormField>
              {term.length >= 2 && found.data && (
                <ul className={styles.picker}>
                  {found.data.items.length === 0 ? (
                    <li className={styles.muted}>{t('admin.ab.add.userNone')}</li>
                  ) : (
                    found.data.items.map((u) => (
                      <li key={u.id}>
                        <Button
                          type="button"
                          variant="secondary"
                          size="sm"
                          onClick={() => {
                            setValue(String(u.id));
                            setPickedName(u.displayName);
                            setUserQ('');
                          }}
                        >
                          {u.displayName} · {u.email}
                        </Button>
                      </li>
                    ))
                  )}
                </ul>
              )}
              {valueOk && <p className={styles.muted}>{t('admin.ab.add.userPicked', { name: pickedName || `#${value}` })}</p>}
            </>
          ) : (
            <FormField
              label={t('admin.ab.add.value')}
              hint={t(`admin.ab.add.hint.${kind}` as const)}
              error={touched && !valueOk ? t(`admin.ab.add.err.${kind}` as const) : null}
              required
            >
              <Input
                className="ltr"
                value={value}
                maxLength={kind === 'DEVICE' ? 160 : 64}
                autoComplete="off"
                onChange={(e) => setValue(e.target.value)}
              />
            </FormField>
          )}

          <div className={styles.row2}>
            <FormField label={t('admin.ab.reason.label')}>
              <Select value={reason} onChange={(e) => setReason(e.target.value as BanReason)}>
                {BAN_REASONS.map((r) => (
                  <option key={r} value={r}>
                    {td(`admin.ab.reason.${r}`)}
                  </option>
                ))}
              </Select>
            </FormField>
            <FormField label={t('admin.ab.add.expiry')}>
              <Select value={forever ? 'never' : 'date'} onChange={(e) => setForever(e.target.value === 'never')}>
                <option value="never">{t('admin.ab.add.expiry.never')}</option>
                <option value="date">{t('admin.ab.add.expiry.date')}</option>
              </Select>
            </FormField>
          </div>
          {!forever && (
            <FormField
              label={t('admin.ab.add.expiry.date')}
              error={touched && !dateOk ? t('admin.ab.add.expiry.err') : null}
            >
              <Input type="date" value={date} onChange={(e) => setDate(e.target.value)} />
            </FormField>
          )}
          <FormField label={t('admin.ab.add.note')}>
            <Input value={note} maxLength={300} dir="auto" onChange={(e) => setNote(e.target.value)} />
          </FormField>

          <ReasonField
            value={why}
            onChange={setWhy}
            minLength={ADMIN_REASON_MIN}
            label={t('admin.wp02.actionReason.label')}
            disabled={create.isPending}
          />

          {kind === 'USER' && (
            <>
              <Checkbox
                checked={alsoDevices}
                onChange={(e) => setAlsoDevices(e.target.checked)}
                label={t('admin.ab.add.alsoDevices')}
              />
              <Checkbox
                checked={alsoIps}
                onChange={(e) => setAlsoIps(e.target.checked)}
                label={t('admin.ab.add.alsoIps')}
              />
              {alsoIps && (
                <p className={styles.warn} role="note">
                  {t('admin.ab.add.ipsWarn')}
                </p>
              )}
            </>
          )}
        </form>
      </Modal>
      <ConfirmDialog
        open={open && selfConfirm}
        onClose={() => setSelfConfirm(false)}
        onConfirm={() => create.mutate(true)}
        loading={create.isPending}
        danger
        title={t('admin.ab.self.title')}
        message={t('admin.ab.self.body')}
        confirmLabel={t('admin.ab.self.confirm')}
      />
    </>
  );
}
