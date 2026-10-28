import { useMutation } from '@tanstack/react-query';
import { useState } from 'react';
import { sendToUser } from '../../../api/campaigns';
import type { Lang } from '../../../api/types';
import { Button, FormField, Input, Modal, Select, useToast } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { ContentEditor } from './ContentEditor';
import {
  NOTIF_TYPES,
  TARGET_TYPES,
  buildQuickBody,
  emptyState,
  type ComposeNotifType,
  type ComposeTargetType,
} from './lib';
import { adminErrorMessage, Callout } from './shared';
import styles from './campaigns.module.css';

/** Kullanıcı ayrıntısından tek kullanıcıya bildirim (POST /api/admin/push/users/{id}/send). */
export function QuickSendDialog({
  open,
  onClose,
  userId,
  userName,
}: {
  open: boolean;
  onClose: () => void;
  userId: number;
  userName: string;
}) {
  const i18n = useI18n();
  const { t } = i18n;
  const toast = useToast();
  const [state, setState] = useState(emptyState);
  const [lang, setLang] = useState<Lang>('tr');
  const [touched, setTouched] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const built = buildQuickBody(state);

  const send = useMutation({
    mutationFn: () => sendToUser(userId, built.body!),
    onSuccess: () => {
      toast.success(t('admin.campaigns.quick.sent', { name: userName }));
      onClose();
    },
    onError: (e) => {
      const msg = adminErrorMessage(i18n, e);
      setError(msg);
      toast.error(msg);
    },
  });

  return (
    <Modal
      open={open}
      onClose={send.isPending ? () => undefined : onClose}
      size="lg"
      title={t('admin.campaigns.quick.title', { name: userName })}
      footer={
        <>
          <Button variant="secondary" onClick={onClose} disabled={send.isPending}>
            {t('common.cancel')}
          </Button>
          <Button
            loading={send.isPending}
            data-testid="quick-send"
            onClick={() => {
              setTouched(true);
              if (built.valid) {
                setError(null);
                send.mutate();
              }
            }}
          >
            {t('admin.campaigns.quick.send')}
          </Button>
        </>
      }
    >
      <div className={styles.stack}>
        <p className={styles.muted}>{t('admin.campaigns.quick.hint')}</p>
        <ContentEditor
          lang={lang}
          onLangChange={setLang}
          contents={state.contents}
          onChange={(l, c) => setState((s) => ({ ...s, contents: { ...s.contents, [l]: c } }))}
          showErrors={touched}
        />
        <div className={styles.targetRow}>
          <FormField label={t('admin.campaigns.send.type')}>
            <Select
              value={state.notifType}
              onChange={(e) => setState((s) => ({ ...s, notifType: e.target.value as ComposeNotifType }))}
            >
              {NOTIF_TYPES.map((v) => (
                <option key={v} value={v}>
                  {t(`admin.campaigns.type.${v}`)}
                </option>
              ))}
            </Select>
          </FormField>
          <FormField label={t('admin.campaigns.target.type')}>
            <Select
              value={state.targetType}
              onChange={(e) => setState((s) => ({ ...s, targetType: e.target.value as ComposeTargetType, targetValue: '' }))}
            >
              {TARGET_TYPES.map((v) => (
                <option key={v} value={v}>
                  {t(`admin.campaigns.target.${v}`)}
                </option>
              ))}
            </Select>
          </FormField>
          {state.targetType !== 'NONE' && (
            <FormField
              label={t(state.targetType === 'URL' ? 'admin.campaigns.target.urlLabel' : 'admin.campaigns.target.idLabel')}
              error={
                touched && built.targetError
                  ? t(built.targetError === 'URL_HTTPS' ? 'admin.campaigns.target.err.URL_HTTPS' : 'admin.campaigns.target.err.ID_REQUIRED')
                  : null
              }
            >
              <Input
                className="ltr"
                value={state.targetValue}
                maxLength={500}
                onChange={(e) => setState((s) => ({ ...s, targetValue: e.target.value }))}
              />
            </FormField>
          )}
        </div>
        {state.notifType === 'SYSTEM' && <Callout tone="danger">{t('admin.campaigns.type.SYSTEM.warn')}</Callout>}
        {error && (
          <Callout tone="danger" role="alert" title={t('admin.campaigns.send.failed')}>
            {error}
          </Callout>
        )}
      </div>
    </Modal>
  );
}
