// Sohbet içeriği sebep kapısı (W-P02): sebep yazılana dek içerik (ve onu isteyen sorgular) hiç yüklenmez.
// Sebep bellekte hedef anahtarıyla hatırlanır (chatReason.ts); sunucu reddederse kapı yeniden sorar.
import { useEffect, useMemo, useState, type ReactNode } from 'react';
import { Button, ConfirmDialog, EmptyState } from '../../../components/ui';
import { ReasonField, type ReasonTemplateOption } from '../../../components/admin/guard/ReasonField';
import { isReasonValid } from '../../../components/admin/guard/match';
import { useI18n } from '../../../i18n/I18nProvider';
import { CHAT_REASON_MIN, useChatReason } from './chatReason';
import styles from './reasonGate.module.css';

export interface ReasonGateProps {
  /** Sebebin hatırlanacağı hedef (`chatReasonKey.*`). */
  storeKey: string;
  /** Sebep alanının ilk değeri (örn. `Rapor incelemesi #12`). */
  initialText?: string;
  /** İçerik: sebep hazır olunca çağrılır. */
  children: (reason: string) => ReactNode;
}

/** Hazır sebep şablonları: ilk ikisi numara bekler, kullanıcı tamamlar. */
export function useReasonTemplates(reportText?: string): ReasonTemplateOption[] {
  const { t } = useI18n();
  return useMemo(
    () => [
      { id: 'report', label: t('admin.wp02.reason.tpl.report'), text: reportText ?? t('admin.wp02.reason.tpl.reportText') },
      { id: 'ticket', label: t('admin.wp02.reason.tpl.ticket'), text: t('admin.wp02.reason.tpl.ticketText') },
      { id: 'legal', label: t('admin.wp02.reason.tpl.legal'), text: t('admin.wp02.reason.tpl.legalText') },
      { id: 'other', label: t('admin.wp02.reason.tpl.other'), text: t('admin.wp02.reason.tpl.otherText') },
    ],
    [t, reportText],
  );
}

export function ReasonGate({ storeKey, initialText, children }: ReasonGateProps) {
  const { t } = useI18n();
  const { reason, wasRejected, set, clear } = useChatReason(storeKey);
  const [open, setOpen] = useState(true);
  const [text, setText] = useState(initialText ?? '');
  const templates = useReasonTemplates(initialText);

  // Sebep silinince (sunucu reddi ya da "değiştir") diyalog yeniden açılır.
  useEffect(() => {
    if (!reason) {
      setOpen(true);
      setText((cur) => (wasRejected ? cur : (initialText ?? cur)));
    }
  }, [reason, wasRejected, initialText]);

  if (reason) {
    return (
      <>
        <div className={styles.bar} data-testid="reason-bar">
          <p className={styles.barText}>
            <span dir="auto">{t('admin.wp02.reason.current', { reason })}</span>{' '}
            <span className={styles.audited}>{t('admin.wp02.reason.audited')}</span>
          </p>
          <Button
            variant="ghost"
            size="sm"
            onClick={() => {
              setText(reason);
              clear();
            }}
          >
            {t('admin.wp02.reason.change')}
          </Button>
        </div>
        {children(reason)}
      </>
    );
  }

  const valid = isReasonValid(text, CHAT_REASON_MIN);
  const submit = () => {
    if (!valid) return;
    set(text);
    setOpen(false);
  };
  return (
    <>
      <EmptyState
        compact
        icon="shield"
        title={t('admin.wp02.reason.gateTitle')}
        description={t('admin.wp02.reason.gateText')}
        action={
          <Button variant="primary" onClick={() => setOpen(true)}>
            {t('admin.wp02.reason.gateOpen')}
          </Button>
        }
      />
      <ConfirmDialog
        open={open}
        onClose={() => setOpen(false)}
        onConfirm={submit}
        title={t('admin.wp02.reason.title')}
        message={t('admin.wp02.reason.message')}
        confirmLabel={t('admin.wp02.reason.confirm')}
        confirmDisabled={!valid}
        initialFocus="content"
      >
        {wasRejected && (
          <p className={styles.rejected} role="alert">
            {t('admin.wp02.reason.rejected')}
          </p>
        )}
        <ReasonField
          value={text}
          onChange={setText}
          minLength={CHAT_REASON_MIN}
          label={t('admin.wp02.reason.label')}
          templates={templates}
          focusOnMount
        />
      </ConfirmDialog>
    </>
  );
}
