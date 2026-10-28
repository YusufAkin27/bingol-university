// Yasal talep için sohbet dışa aktarma (P08): İKİ AŞAMALI onay.
// 1) Gerekçe (>= 20 karakter) + biçim (JSON/CSV) + isteğe bağlı devam imleci.
// 2) Uyarı "Bu işlem denetim kaydına yazılır ve mesaj içeriğini çözer" + sohbet kimliğini yazdırma.
// Sebep ve onay `X-Admin-Reason` / `X-Admin-Confirm` başlıklarıyla gider; sohbet içeriği GÖRÜNTÜLEME sebebinden ayrı bir alandır.
import { useState } from 'react';
import { adminChatApi } from '../../../api';
import { Button, FormField, Input, Modal, ReasonField, TypeToConfirm, useToast } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { adminError } from '../../../lib/errors';
import { EXPORT_MAX_MESSAGES, EXPORT_REASON_MIN, exportFileName, exportGate } from './chatAction';
import styles from './chatAction.module.css';

function download(blob: Blob, name: string) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = name;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

export function ConversationExportButton({ conversationId }: { conversationId: number }) {
  const i18n = useI18n();
  const { t } = i18n;
  const toast = useToast();
  const [open, setOpen] = useState(false);
  const [step, setStep] = useState<1 | 2>(1);
  const [reason, setReason] = useState('');
  const [typed, setTyped] = useState('');
  const [format, setFormat] = useState<'json' | 'csv'>('json');
  const [afterText, setAfterText] = useState('');
  const [busy, setBusy] = useState(false);

  const gate = exportGate(reason, typed, conversationId);
  const afterId = /^\d+$/.test(afterText.trim()) ? Number(afterText.trim()) : null;

  const reset = () => {
    setStep(1);
    setReason('');
    setTyped('');
    setAfterText('');
    setFormat('json');
  };
  const close = () => {
    if (busy) return;
    setOpen(false);
    reset();
  };

  const run = async () => {
    if (!gate.ready || busy) return;
    setBusy(true);
    try {
      const name = exportFileName(conversationId, format, afterId);
      if (format === 'json') {
        const data = await adminChatApi.exportConversationJson(conversationId, reason.trim(), afterId);
        download(new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' }), name);
        toast.success(t('admin.p08.export.done', { n: data.messageCount }));
        if (data.truncated && data.nextAfterId) {
          toast.info(t('admin.p08.export.truncated', { id: data.nextAfterId }));
        }
      } else {
        const blob = await adminChatApi.exportConversationCsv(conversationId, reason.trim(), afterId);
        download(blob, name);
        toast.success(t('admin.p08.export.doneCsv', { max: EXPORT_MAX_MESSAGES }));
      }
      setOpen(false);
      reset();
    } catch (e) {
      toast.error(adminError(i18n, e) || t('admin.p08.export.failed'));
    } finally {
      setBusy(false);
    }
  };

  return (
    <>
      <Button variant="secondary" size="sm" onClick={() => setOpen(true)}>
        {t('admin.p08.export.btn')}
      </Button>
      <Modal
        open={open}
        onClose={close}
        title={t('admin.p08.export.title')}
        role="alertdialog"
        footer={
          step === 1 ? (
            <>
              <Button variant="ghost" onClick={close}>
                {t('admin.p08.export.cancel')}
              </Button>
              <Button variant="primary" disabled={!gate.reasonOk} onClick={() => setStep(2)}>
                {t('admin.p08.export.next')}
              </Button>
            </>
          ) : (
            <>
              <Button variant="ghost" disabled={busy} onClick={() => setStep(1)}>
                {t('admin.p08.export.back')}
              </Button>
              <Button variant="danger" disabled={!gate.ready} loading={busy} onClick={() => void run()}>
                {t('admin.p08.export.go')}
              </Button>
            </>
          )
        }
      >
        <div className={styles.exportBody} data-testid={`export-step-${step}`}>
          <strong>{step === 1 ? t('admin.p08.export.step1') : t('admin.p08.export.step2')}</strong>
          {step === 1 ? (
            <>
              <p className={styles.summary}>{t('admin.p08.export.intro', { max: EXPORT_MAX_MESSAGES })}</p>
              <ReasonField
                value={reason}
                onChange={setReason}
                minLength={EXPORT_REASON_MIN}
                label={t('admin.p08.export.reasonLabel')}
                focusOnMount
              />
              <fieldset className={styles.formats}>
                <legend>{t('admin.p08.export.format')}</legend>
                {(['json', 'csv'] as const).map((f) => (
                  <label key={f}>
                    <input type="radio" name="export-format" checked={format === f} onChange={() => setFormat(f)} />{' '}
                    {t(`admin.p08.export.format.${f}`)}
                  </label>
                ))}
              </fieldset>
              <FormField label={t('admin.p08.export.afterId')}>
                <Input inputMode="numeric" value={afterText} onChange={(e) => setAfterText(e.target.value)} />
              </FormField>
            </>
          ) : (
            <>
              <p className={styles.warn} role="alert">
                {t('admin.p08.export.warn')}
              </p>
              <p className={styles.summary} dir="auto">
                {t('admin.p08.export.summaryReason', { reason: reason.trim() })}
              </p>
              <TypeToConfirm
                target={String(conversationId)}
                value={typed}
                onChange={setTyped}
                label={t('admin.p08.export.confirmLabel', { id: conversationId })}
                focusOnMount
                disabled={busy}
                onEnter={() => void run()}
              />
            </>
          )}
        </div>
      </Modal>
    </>
  );
}
