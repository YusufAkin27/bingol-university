import { useState } from 'react';
import type { CreateCampaignRequest } from '../../../api/types';
import { Button, Checkbox, Modal } from '../../../components/ui';
import { useI18n } from '../../../i18n/I18nProvider';
import { DetailList } from '../community/ReviewParts';
import { useAudienceSummary, useTargetSummary } from './format';
import { filledLangs, needsExtraConfirm, type ComposeState } from './lib';
import { Callout } from './shared';
import styles from './campaigns.module.css';

/** Gönderim özeti + geri alınamaz uyarısı; ALL ve SYSTEM için ek onay kutuları. */
export function SendDialog({
  open,
  onClose,
  onSend,
  sending,
  error,
  state,
  request,
  count,
}: {
  open: boolean;
  onClose: () => void;
  onSend: () => void;
  sending: boolean;
  error: string | null;
  state: ComposeState;
  request: CreateCampaignRequest;
  count: number;
}) {
  const { t, formatNumber, formatDateTime } = useI18n();
  const audienceSummary = useAudienceSummary();
  const targetSummary = useTargetSummary();
  const extra = needsExtraConfirm(state);
  const [okAll, setOkAll] = useState(false);
  const [okSystem, setOkSystem] = useState(false);
  const ready = (!extra.all || okAll) && (!extra.system || okSystem);
  const scheduled = state.scheduleMode === 'later' && request.scheduledAt;
  const langs = filledLangs(state.contents);

  return (
    <Modal
      open={open}
      onClose={sending ? () => undefined : onClose}
      size="md"
      title={t('admin.campaigns.send.title')}
      footer={
        <>
          <Button variant="secondary" onClick={onClose} disabled={sending}>
            {t('common.cancel')}
          </Button>
          <Button
            variant={extra.all || extra.system ? 'danger' : 'primary'}
            disabled={!ready}
            loading={sending}
            onClick={onSend}
            data-testid="confirm-send"
          >
            {t(scheduled ? 'admin.campaigns.send.confirmSchedule' : 'admin.campaigns.send.confirmNow')}
          </Button>
        </>
      }
    >
      <div className={styles.sendBody}>
        <p className={styles.sendLead}>
          {t(scheduled ? 'admin.campaigns.send.leadScheduled' : 'admin.campaigns.send.lead', {
            n: formatNumber(count),
          })}
        </p>
        <blockquote className={styles.sendQuote} lang="tr">
          <strong>{request.tr.title}</strong>
          <span>{request.tr.body}</span>
        </blockquote>
        <DetailList
          items={[
            { label: t('admin.campaigns.col.audience'), value: audienceSummary(request.audience) },
            { label: t('admin.campaigns.send.type'), value: t(`admin.campaigns.type.${state.notifType}`) },
            { label: t('admin.campaigns.detail.target'), value: <span className="ltr">{targetSummary(request.target ?? null)}</span> },
            {
              label: t('admin.campaigns.compose.languages'),
              value: langs.map((l) => t(`admin.campaigns.lang.${l}`)).join(', '),
            },
            {
              label: t('admin.campaigns.send.when'),
              value: scheduled ? formatDateTime(request.scheduledAt ?? null) : t('admin.campaigns.schedule.now'),
            },
          ]}
        />
        <Callout tone="warning" title={t('admin.campaigns.send.irreversible')}>
          {t(scheduled ? 'admin.campaigns.send.irreversibleScheduled' : 'admin.campaigns.send.irreversibleNow')}
        </Callout>
        {extra.all && (
          <Checkbox
            checked={okAll}
            onChange={(e) => setOkAll(e.target.checked)}
            label={t('admin.campaigns.send.confirmAll', { n: formatNumber(count) })}
          />
        )}
        {extra.system && (
          <Checkbox
            checked={okSystem}
            onChange={(e) => setOkSystem(e.target.checked)}
            label={t('admin.campaigns.send.confirmSystem')}
          />
        )}
        {error && (
          <Callout tone="danger" role="alert" title={t('admin.campaigns.send.failed')}>
            {error}
          </Callout>
        )}
      </div>
    </Modal>
  );
}
